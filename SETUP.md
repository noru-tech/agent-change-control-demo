# Setting up the demo

How to build `noru-tech/agent-change-control-demo` from this directory. Steps marked **(human)**
must be done by the named person, by hand. Nothing in this repository scripts a human's approval.

## Prerequisites

On the operator's machine: `gh` (logged in as the operator), `git`, `jq`, `yq` (mikefarah, v4),
Node.js 24 and `acc` 0.6.0 (`brew install noru-tech/tap/acc`). The scripts run in bash 3.2 or
later.

## Checklist

### 1. People and consent (human)

- [ ] Pick the **operator** (a Noru engineer who directs the writing agent) and the
      **independent reviewer** (a second Noru person). They must be different people.
- [ ] Both agree, in writing, that their GitHub logins and review timestamps will appear in a
      public repository, in published manifests, and in Sigstore's public transparency log, where
      they cannot be removed (acc `docs/privacy.md`).
- [ ] Fill in `identities.operator`, `identities.reviewer` and `exception.owner` in
      `scenarios.yml`. Leave `identities.reviewer_agent_operator` empty to make the independent
      reviewer the operator of the reviewing agent in scenario 10, or name a third person who has
      also agreed.

### 2. Repository (operator, org admin)

- [ ] Create the public repository `noru-tech/agent-change-control-demo`, empty, MIT.
- [ ] Settings > Actions > General: workflow permissions **read repository contents**; leave
      "Allow GitHub Actions to create and approve pull requests" **off** (the apps open and review
      pull requests, not `GITHUB_TOKEN`).
- [ ] Settings > Code security: enable private vulnerability reporting. Code scanning needs no
      setup; the workflows upload SARIF.
- [ ] Give the independent reviewer **write** access, so GitHub also counts their approvals.
- [ ] Topics:
      `gh repo edit noru-tech/agent-change-control-demo --add-topic agent-change-control,ai-agents,separation-of-duties,four-eyes,in-toto,sigstore,compliance,soc2,iso27001`
- [ ] Community files (code of conduct, contributing, security, support) come from
      `noru-tech/.github` automatically; add none here.

### 3. GitHub Apps (operator, org admin)

Create three apps owned by `noru-tech`, each with no webhook, installed on this repository only.

| App | Repository permissions |
| --- | --- |
| `noru-demo-writer` | Contents: read and write. Pull requests: read and write. Issues: read and write (labels). |
| `noru-demo-reviewer` | Pull requests: read and write. Contents: read. |
| `noru-demo-reviewer-same` | Pull requests: read and write. Contents: read. |

- [ ] Generate a private key for each app and note each app's **client ID**.
- [ ] If the slugs differ from the names above, update `identities` and
      `evidence.agent_accounts` in `scenarios.yml`.

### 4. Environment and settings (operator)

- [ ] Create the environment **`agents`** with deployment branches limited to `main`.
- [ ] Environment secrets: `WRITER_APP_PRIVATE_KEY`, `REVIEWER_APP_PRIVATE_KEY`,
      `REVIEWER_SAME_APP_PRIVATE_KEY`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`.
- [ ] Environment variables: `WRITER_APP_CLIENT_ID`, `REVIEWER_APP_CLIENT_ID`,
      `REVIEWER_SAME_APP_CLIENT_ID`, `OTHER_VENDOR_MODEL` (the OpenAI model for scenarios 09
      and 10), and optionally `SAME_VENDOR_MODEL` (defaults to `claude-opus-5-5`).

### 5. First push (operator)

- [ ] `scripts/preview.sh` passes locally.
- [ ] Push this directory as the first commit on `main`. The ruleset is not on yet.
- [ ] The `ci` workflow passes on `main`.

### 6. Seed (operator, then both humans)

Run `scripts/seed.sh` as the operator. It stops and waits at each step below; do them in the
GitHub UI (Files changed > Review changes > Approve) when it asks.

- [ ] **(reviewer)** approve history pull requests h1, h2 and h3. The script merges each one.
      h4 is merged without review, by design.
- [ ] **(reviewer)** approve scenario 05 once. The agent then pushes a second commit. Do **not**
      approve 05 again.
- [ ] **(reviewer)** approve scenarios 01, 04, 06 and 07.
- [ ] **(operator)** approve scenario 02, your own agent's change.
- [ ] Nobody reviews 03. No human reviews 08, 09 or 10; the script runs the agent reviews.

Do not approve, comment-approve or dismiss anything else on the scenario pull requests. Every
review is part of a verdict.

### 7. Commit the seeded state (operator)

- [ ] Copy `heads/<scenario 10 head>/review-output.md` from the `attestations` branch to
      `scenarios/10/review-output.md`, unedited.
- [ ] In the README, scenario 10 section, fill in the model (from the review's footer on the pull
      request) and the date of the run.
- [ ] Commit `scenarios.yml` (pull request numbers), `README.md` (links),
      `manifests/history.json`, `.agent-change-control/dispositions.json` and
      `scenarios/10/review-output.md` directly to `main`.

### 8. Check (operator)

- [ ] `scripts/verify.sh` passes.
- [ ] Every scenario pull request shows the check result in `scenarios.yml` (`check`).

### 9. Ruleset and first manifest (operator, org admin)

- [ ] `gh api repos/noru-tech/agent-change-control-demo/rulesets --method POST --input ruleset/main.json`
- [ ] Try to merge scenario 03 and confirm GitHub refuses.
- [ ] `gh workflow run monthly-scan.yml --repo noru-tech/agent-change-control-demo -f month=<the seed month, YYYY-MM>`
- [ ] Download the release asset and run `acc validate` on it, then follow the README's
      "Verify a signed verdict yourself" end to end.

### 10. Publish (operator)

- [ ] Add "See it on real pull requests" with a link to this repository to the acc README.
- [ ] Pin this repository on the `noru-tech` organisation page next to acc.
- [ ] The Scorecard badge shows a score after the first `scorecard` run on `main`.
