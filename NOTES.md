# Notes for Bip

Where the acc docs and code (at tag `v0.6.0`) disagreed with the spec, what I did about it, and
what is still open. Your local acc checkout (`main` at `1cf3928`) is six commits behind `v0.6.0`,
so I read the docs and fixtures from the tag, and built 0.6.0 from it to run the fixtures.

Status: everything here is built and checked offline. Nothing has run on GitHub yet: the
repository, apps, identities and model keys don't exist, so no workflow has executed. Items
marked **first run** can only be confirmed once seeding starts.

## Where acc differs from the spec

1. **The spec's policy file is rejected by acc 0.6.0.** Without a `rules` key, validation fails
   with `ACV010 schema validation failed at` (with an empty path). `rules` is required by
   `schemas/policy.schema.json`, even though `docs/policy.md` says "partial rule maps inherit
   defaults". I added `rules: {}`. Worth fixing in acc: either make `rules` optional, or say it's
   required and put a path in the error.

2. **`actions/attest` cannot sign the scenario 10 documents in a form acc reads.** acc binds a
   provenance or review document to a change only through a `gitCommit` subject equal to the head
   commit (`src/provenance/attestations.rs`, `covers`). `actions/attest` writes sha256 subjects
   only. The writer and reviewer workflows therefore sign with `cosign attest-blob --statement`
   (keyless, GitHub OIDC), as acc `docs/signing.md` shows for authorship claims. Each Statement
   has two subjects:
   - the `gitCommit` head, which is what acc binds;
   - the sha256 of the predicate file, which is what `gh attestation verify` matches on disk.

   The monthly manifest still uses `actions/attest`, as the spec asks.

3. **acc's own example of verifying a review cannot work as written.** In `docs/signing.md`, the
   command `gh attestation verify --bundle review.sigstore.json … review.intoto.json` needs the
   artifact's sha256 among the Statement's subjects. `examples/review.intoto.json` has only a
   `gitCommit` subject, so the command finds no match. The second subject from item 2 is the
   workaround here. The acc docs should say so.

4. **Stale text in acc about signed reviews.** Three places say acc cannot read signed review
   documents yet:
   - `docs/policy.md` (minimum review evidence);
   - `KNOWN-LIMITATIONS.md` ("`signed` review evidence cannot yet come from the forge");
   - the module comment of `src/provenance/attestations.rs` ("Review claims are not read").

   `docs/signing.md`, `docs/agent-authorship.md` and the code all say acc 0.6.0 does read them.

5. **The fixtures are merged changes; the scenarios are open pull requests.** On an open pull
   request ACC003 is `not_applicable`, so ACC003 appears in no scenario. The fixtures report it as
   `fail` for 02, 08 and 09, and for `stale-approval`.

6. **Scenario 05's fixture is a human change.** `stale-approval` is human-authored and merged
   (ACC001 `not_applicable`, ACC003 `fail`). The demo's 05 is agent-authored and open, so ACC001
   fails, as the spec's table says. The verdict matches the spec, but not the fixture rule for
   rule.

7. **Scenario 03 has no fixture.** The closest one, `open-pr`, is human-authored. I confirmed 03's
   outcome with the offline preview (`scripts/preview.sh`), which evaluates a synthetic copy of
   each scenario with acc 0.6.0.

8. **Scenario 07's "fixture" is a record, not an evaluation.** `tests/fixtures/agent-trace` holds
   an Agent Trace record used by the collector tests; it has no expected verdict.

9. **Spec table vs acc, per scenario.** Every row in `scenarios.yml` lists all eight rules.
   - **04:** ACC002 is also `unknown`. The check passes (green), because ACC006 is a warning.
   - **08:** I dropped the `agent-review` label. With the label, ACC010 also fails, because the
     same-vendor review is unsigned. The fixture `agent-review-same-vendor` runs without the
     agent_review policy, and the fixture wins under the spec's rule. If you want the label back,
     add `ACC010: fail` to its expected outcomes.
   - **09:** ACC001 is `fail` (high), so the check fails. ACC007 also fires (info).
   - **10:** ACC007 fires (info), so acc's table prints WARN while the check passes. The README
     explains this.

10a. **acc's SARIF cannot be uploaded to code scanning.** Found on the first seeding run. acc
     0.6.0 sets every result's location to the pull request's URL (`src/output/sarif/mod.rs`).
     Code scanning rejects the file: "SARIF URI scheme "https" did not match the checkout URI
     scheme "file"". acc's own docs (`docs/github-action.md`, "Blocking or advisory") and
     `examples/workflow-required-check.yml` both tell users to upload it, so that setup fails for
     everyone. acc's own repository doesn't upload SARIF, which is likely why it went unnoticed.
     A failed upload also turns the job red when acc passes. I removed the upload from
     `change-control.yml`, against the spec. Fix in acc: give each result a repository file as
     its location (for example the policy file, or a fixed `.agent-change-control` path) and put
     the pull request URL in the message or in `properties`.

## Decisions I made

10. **GitHub Apps, not machine users.** A GitHub App with pull requests: write can submit an
    `APPROVE` review through the REST API. The repository setting "Allow GitHub Actions to create
    and approve pull requests" covers only `GITHUB_TOKEN`. acc treats any account passed through
    `agent-account` as an agent, reviewers included (`src/collectors/github/mod.rs`, `actor`).
    **First run:** confirm the reviewer app's approval shows up as an agent review in the manifest.

11. **Different signer identities.** acc takes the review's `identity` from
    `verificationResult.signature.certificate.subjectAlternativeName` in the
    `gh attestation verify` output. A keyless signature from Actions has the workflow file in its
    SAN, so `agent-write.yml` and `agent-review.yml` give different strings. **First run:** confirm
    both appear under `attestations` in the manifest with different `signer.identity`.

12. **Where the bundles live.** They're on an `attestations` branch under `heads/<head sha>/`.
    Storing them on the pull request branch would change its head, and pushing to `main` is
    blocked once the ruleset is on. The branch is not protected. That's acceptable because
    verification pins the signer workflow and `--source-ref refs/heads/main`, and a forged bundle
    fails the check loudly. Optional hardening: a ruleset that lets only GitHub Actions push to
    that branch. Possible extra: upload the bundles to the GitHub attestation store
    (`POST /repos/{owner}/{repo}/attestations`). That isn't done, because I couldn't confirm the
    endpoint accepts bundles that `actions/attest` did not make.

13. **The writing agent applies pre-written changes; it is not a live model run.** The changes
    under `scenarios/` were written by Claude Code in this session, under your direction.
    `author: claude-code` is therefore accurate, and so is the trailer in 06, provided **you are
    the operator**. If someone else operates, the changes should be re-made under their direction,
    or the README should say who directed them. The README's "What is real" section says the
    changes were pre-written.

14. **The trailer and the declarations are scenario data.** Scenario 06's commit carries
    `Co-Authored-By: Claude <noreply@anthropic.com>`, and the agent pull request bodies declare
    `author: claude-code`, because the spec requires them. Neither the scaffolding nor any commit
    I'd make on your behalf carries attribution.

15. **The Agent Trace record in 07 comes from the seed script.** It uses `tool.name: claude-code`
    to match who wrote the code. Claude Code doesn't emit Agent Trace itself, and the README says
    so. To show a tool that does emit it (Cursor, for example), the change would have to be
    written with that tool.

16. **Models.** Only scenario 10 runs a model: an OpenAI model reviews the diff, and its unedited
    output is the review. I didn't pick the model id; set `OTHER_VENDOR_MODEL`. The key is needed
    only while seeding 10 and can be deleted afterwards.
    - In 08 and 09 the reviewer apps approve with a note saying no model ran. acc decides on who
      approved which commit, so the verdicts don't depend on review text. The "same vendor" in
      08 comes from mapping the app to `claude-code-review` (Anthropic in acc's registry), not
      from calling an Anthropic model.
    - The other-vendor reviewer is registered as agent `noru-demo-reviewer` with
      `--agent-vendor noru-demo-reviewer=openai`. acc's built-in `codex` entry would be wrong:
      the reviewer is not Codex.
    - If the model requests changes, the review is still submitted, and the workflow fails rather
      than retrying until the model approves.

17. **Reviewer-agent operator in 10.** This defaults to the independent reviewer. That's
    acceptable to acc (it isn't the writer's operator). A third consenting person would read more
    cleanly; set `identities.reviewer_agent_operator`.

18. **The policy comes from the base branch.** `change-control.yml` checks out the base commit,
    so a pull request cannot loosen the policy it is judged by. Traces on the pull request's head
    are read through the API as data.

19. **The ruleset requires zero approvals.** GitHub's approval count would accept the reviewer
    app in 09, and would block 10. acc is the gate.

## Open questions

20. **Human pull requests pass the gate without review.** On an open, human-authored pull request,
    ACC001 and ACC003 are both `not_applicable`, so the change-control check is green with no
    approval. That includes Dependabot and pin bumps in this repository. ACC003 only catches it
    after the merge. That's acc's design (acc gates agent changes), but a reader may assume the
    ruleset forces review on everything. Should the README say so, or should acc grow an
    open-PR equivalent of ACC003?

21. **SARIF upload.** Removed; see item 10a.

22. **cosign details.** These are written per acc `docs/signing.md` but not yet run:
    - `cosign attest-blob --statement … --bundle … --yes -`;
    - cosign v3 (from `cosign-installer` v4.1.2) writing the new bundle format that
      `gh attestation verify --bundle` reads.

    **First run** of `agent-write.yml` for scenario 10. `sign.sh` checks its own output with
    `gh attestation verify` straight away, so a problem shows up there.

23. **Writing style.** The spec refers to your writing-style rules "in the brief", which I don't
    have. The README follows the plain voice of acc's README. Check it against your rules before
    publishing.

24. **Exception owner.** `exception.owner` in `scenarios.yml` is empty; seeding stops until it's
    set. I didn't want to guess an address.

25. **Agent Trace format.** The record has the fields acc 0.6.0 reads (`version`, `id`,
    `vcs.revision`, `tool.name`, `files[].conversations[].contributor.type` and `ranges`), shaped
    like acc's fixture. I haven't checked it against the Agent Trace specification itself.
