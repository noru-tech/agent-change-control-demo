// Builds a synthetic, already-collected copy of every scenario as acc events, so the expected
// rule outcomes in scenarios.yml can be checked offline against the pinned acc release.
//
// This checks acc's evaluation, not its collection: the events say what the collector would
// record for each scenario (who opened it, what evidence names the agent and operator, who
// reviewed which commit). scripts/verify.sh checks the live pull requests.
//
// Usage: yq -o=json scenarios.yml | node scripts/preview.mjs OUT_DIR

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const config = JSON.parse(readFileSync(0, "utf8"));
const out = process.argv[2];
mkdirSync(out, { recursive: true });

const repo = config.repository;
const ids = config.identities;
const operator = `github:${(ids.operator || "operator").toLowerCase()}`;
const reviewer = `github:${(ids.reviewer || "reviewer").toLowerCase()}`;
const reviewerAgentOperator = ids.reviewer_agent_operator
  ? `github:${ids.reviewer_agent_operator.toLowerCase()}`
  : reviewer;
const writer = `github:${ids.writer_app}[bot]`;
const reviewerApp = `github:${ids.reviewer_app}[bot]`;
const sameApp = `github:${ids.reviewer_same_app}[bot]`;
const signer = (workflow) => ({
  identity: `https://github.com/${repo}/${workflow}@refs/heads/main`,
  issuer: "https://token.actions.githubusercontent.com",
});

const at = (day, hour) => `2026-10-${String(day).padStart(2, "0")}T${String(hour).padStart(2, "0")}:00:00Z`;
const ev = (source, ref, kind) => ({ source, ref, kind });

function build(s, number) {
  const api = `https://api.github.com/repos/${repo}/pulls/${number}`;
  const html = `https://github.com/${repo}/pull/${number}`;
  const observed = ev("github_api", api, "observed");
  const declared = ev("pr_metadata", html, "declared");
  const opener = s.opened_by === "operator" ? operator : writer;
  const mapping = ev("known_agent_account", `${writer}=claude-code`, "declared");
  const attestations = {};
  const actors = {
    [operator]: { kind: "human", display_name: operator.slice(7), vendor: null },
    [reviewer]: { kind: "human", display_name: reviewer.slice(7), vendor: null },
    [reviewerAgentOperator]: { kind: "human", display_name: reviewerAgentOperator.slice(7), vendor: null },
    [writer]: { kind: "agent", display_name: writer.slice(7), vendor: "anthropic" },
    "agent:claude-code": { kind: "agent", display_name: "claude-code", vendor: "anthropic" },
  };

  // Authorship evidence, strongest tier first, as acc's collector records it. An attestation id
  // is the first 16 hex digits of its payload digest (acc spec §8).
  let authorEvidence = [observed];
  let operatorRecord = null;
  if (s.opened_by === "writer_app") authorEvidence.push(mapping);
  if (s.sign_provenance) {
    const id = "attestation:1111111111111111";
    attestations[id] = {
      file: "provenance.json#1",
      predicate_type: "https://noru.tech/spec/ai-change-provenance/provenance/v0.1",
      payload_digest: `sha256:${"1".repeat(64)}`,
      signed: true,
      verified_by: "preview",
      signer: signer(config.evidence.signer_workflows.provenance),
      matched: true,
    };
    authorEvidence.push(ev("attestation", id, "signed"));
    operatorRecord = { actor_id: operator, confidence: "explicit", provenance: [ev("attestation", id, "signed")] };
  } else if (s.declaration) {
    operatorRecord = { actor_id: operator, confidence: "explicit", provenance: [declared] };
  } else if (s.trailers || s.agent_trace) {
    const source = s.trailers ? "commit_trailer" : "agent_trace";
    const d = ev(source, `${api}/commits/head`, "derived");
    authorEvidence = [d];
    operatorRecord = { actor_id: operator, confidence: "derived", provenance: [d] };
  }

  const reviews = [];
  const review = (actor, commit, agent = null, extra = []) =>
    reviews.push({
      id: String(reviews.length + 1),
      actor_id: actor,
      state: "approved",
      at: at(2, 12),
      commit_sha: commit,
      provenance: [ev("github_api", `${api}/reviews/${reviews.length + 1}`, "observed"), ...extra],
      agent,
    });
  const head = "head";
  switch (s.review) {
    case "reviewer":
      review(reviewer, s.followup ? "old-head" : head);
      break;
    case "operator":
      review(operator, head);
      break;
    case "reviewer_same_app":
      actors[sameApp] = { kind: "agent", display_name: sameApp.slice(7), vendor: "anthropic" };
      review(sameApp, head);
      break;
    case "reviewer_app": {
      actors[reviewerApp] = { kind: "agent", display_name: reviewerApp.slice(7), vendor: "openai" };
      if (!s.sign_review) {
        review(reviewerApp, head);
        break;
      }
      const id = "attestation:2222222222222222";
      const identity = signer(config.evidence.signer_workflows.review);
      attestations[id] = {
        file: "review.json#1",
        predicate_type: "https://noru.tech/spec/ai-change-provenance/review/v0.1",
        payload_digest: `sha256:${"2".repeat(64)}`,
        signed: true,
        verified_by: "preview",
        signer: identity,
        matched: true,
      };
      review(
        reviewerApp,
        head,
        { operator: reviewerAgentOperator, identity: identity.identity, instructions_owner: reviewerAgentOperator, model: "preview" },
        [ev("attestation", id, "signed")],
      );
      break;
    }
  }

  const author = s.opened_by === "operator" && !s.trailers && !s.agent_trace ? operator : "agent:claude-code";
  return {
    version: "0.2",
    repository: repo,
    window: { from: at(1, 0), to: at(31, 23), complete: true, reason: null },
    actors,
    ...(Object.keys(attestations).length ? { attestations } : {}),
    changes: [
      {
        id: `github:${repo}:pr:${number}`,
        repository: repo,
        forge: "github",
        title: s.title,
        url: html,
        opened_at: at(1, 12),
        merged_at: null,
        head_sha: head,
        merge_commit_sha: null,
        commits: [{ sha: head, author: { actor_id: opener, provenance: [observed] } }],
        forge_author: { actor_id: opener, provenance: [observed] },
        author: { actor_id: author, provenance: authorEvidence },
        agent_operator: author === "agent:claude-code" ? operatorRecord : null,
        reviews,
        reviews_complete: true,
        merger: null,
        provenance: [observed],
        labels: s.labels,
      },
    ],
  };
}

for (const s of config.scenarios) {
  const events = build(s, Number(s.id));
  writeFileSync(join(out, `${s.id}.events.json`), JSON.stringify(events, null, 2) + "\n");
}
