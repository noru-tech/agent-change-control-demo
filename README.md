# agent-change-control-demo

Ten pull requests that stay open, each showing one verdict of
[`acc`](https://github.com/noru-tech/agent-change-control), the check that
[enforces the four-eyes principle for coding agents](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/four-eyes.md).

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/noru-tech/agent-change-control-demo/badge)](https://scorecard.dev/viewer/?uri=github.com/noru-tech/agent-change-control-demo)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

Each pull request is one scenario. Open it, look at the `change-control` check, and read the job
summary: who wrote the change, who directed the agent, who approved which commit, and which rule
passed or failed. Nothing to install.

Two accounts are not necessarily two people. When an agent opens a pull request and the engineer
who directed it approves it, GitHub shows two accounts but only one person has judged the change.
`acc` records the human behind the agent and checks that someone else approved the commit being
merged.

## The scenarios

| # | Scenario | Evidence of authorship | Review | Expected | Pull request |
| --- | --- | --- | --- | --- | --- |
| 01 | Clean agent change | declaration | independent human approves the head | PASS | [open][pr01] |
| 02 | Operator approves their own agent's change | declaration | the operator approves | FAIL [ACC001][r1], [ACC002][r2] | [open][pr02] |
| 03 | No approval | declaration | none | FAIL [ACC001][r1] | [open][pr03] |
| 04 | Operator unknown | account mapping only | independent human approves | WARN [ACC006][r6], ACC001 `unknown` | [open][pr04] |
| 05 | Stale approval | declaration | approved, then the agent pushed again | FAIL [ACC001][r1] | [open][pr05] |
| 06 | Authorship from trailers | Claude Code `Co-Authored-By` trailer | independent human approves | PASS on `derived` evidence | [open][pr06] |
| 07 | Authorship from Agent Trace | Agent Trace record under `traces/` | independent human approves | PASS on `derived` evidence | [open][pr07] |
| 08 | Same-vendor agent review | declaration | the same-vendor reviewer app approves | FAIL [ACC008][r8], ACC001; INFO [ACC007][r7] | [open][pr08] |
| 09 | Other-vendor agent review, unsigned | declaration | the other-vendor reviewer app approves, unsigned | FAIL ACC001; WARN [ACC010][r10] | [open][pr09] |
| 10 | Four eyes with no human approval | signed provenance | an OpenAI model reviews and approves, signed | PASS, no human approval | [open][pr10] |

"Expected" is the outcome of the check under acc 0.6.0. Two of them read differently in acc's
table than on the check. In 04 the table says WARN and the check is green, because ACC006 is a
warning under the default policy. In 10 the table also says WARN, because ACC007 records every
agent approval as an observation (info), and the check is green.

Scenarios 06 and 07 show that acc reads what agents already write today. A team can start without
asking anyone to change tools, then move to declarations and signatures.

Every rule outcome for every scenario is in [`scenarios.yml`](scenarios.yml). Run
`scripts/preview.sh` to check those outcomes against acc offline, without GitHub. A nightly job
re-collects the live pull requests and opens an issue if any verdict drifts
([`verify-demo.yml`](.github/workflows/verify-demo.yml)).

The policy is acc's default, plus one switch: on pull requests labelled `agent-review`, an agent's
approval can count as the second pair of eyes
([`.agent-change-control/policy.yml`](.agent-change-control/policy.yml)). Only scenarios 09 and 10
carry the label.

## Scenario 10: four eyes with no human approval

[Scenario 10][pr10] passes with no human approval on the pull request. This is what it shows, and
what it rests on.

1. **The writer signs what it wrote.** The writer workflow ([`agent-write.yml`](.github/workflows/agent-write.yml))
   pushes the change as the writer app and signs a provenance document for the head commit. The
   document names the agent (`claude-code`, vendor Anthropic) and the human who directed it.
2. **A different model reviews it.** The reviewer workflow ([`agent-review.yml`](.github/workflows/agent-review.yml))
   gives the diff to an OpenAI model and submits that model's review, unedited, through the
   reviewer app. It then signs a review document for the same head commit. The document names the
   reviewing agent, the decision, the model, and the human who operates the reviewer. That human is
   not the writer's operator.
3. **The check verifies both signatures, then evaluates.** The change-control workflow verifies
   each bundle with `gh attestation verify` and allows only the expected workflow on `main` to have
   signed each kind of document. It then passes the verified results to acc (`verification`,
   `verified-by`).
4. **acc checks independence on three dimensions.** Operator: the reviewer's operator is not the
   change's effective human. Provider: the reviewer's vendor differs from the writer's. Identity:
   the review was signed by a different identity than the authorship claim. ACC001 passes with a
   reason that names the policy, and ACC009 passes.

The model's review is in [`scenarios/10/review-output.md`](scenarios/10/review-output.md).
Model: `<filled in after the run>`. Run on `<date>`.

### What this rests on

- **Signing identity is workflow identity.** Both documents are signed keyless through Sigstore
  with GitHub's OIDC token. The certificate names the workflow file that ran:
  `.github/workflows/agent-write.yml` for the provenance and `.github/workflows/agent-review.yml`
  for the review. Different files give different identities, and acc records them as different.
- **acc does not verify signatures.** The workflow does, with `gh attestation verify`, and the
  manifest records who verified them and how. That statement is part of what you trust.
- **A human is still accountable on each side.** Each agent has a named operator, and the two are
  different people. The demo removes the second human approval, not the humans.

### The limitation

Anyone with admin rights on this repository controls both workflows. Such a person could change
the reviewer to approve anything, or sign as both writer and reviewer. In this repository the two
signing identities are separate files, not separate people. That is enough to show the mechanism.
It is not enough for a real deployment.

A production setup separates the reviewer's control from the writer's:

```text
acme/payments-api            (writer: agents open pull requests here)
  └─ change-control.yml      verifies both bundles, then runs acc
       --signer-workflow acme/payments-api/.github/workflows/agent-write.yml        (provenance)
       --signer-workflow acme-review/reviewer/.github/workflows/review.yml          (review)

acme-review/reviewer         (separate organisation, separate admins)
  └─ review.yml              reads the diff, runs the reviewing model, submits the review
                             with its own app, signs the review document
```

The reviewer's organisation has admins who cannot push to the writer's repository, and the
writer's admins cannot edit the reviewer's workflow. The verifier pins each document kind to its
own repository. The identity check then means what it says: two parties, not two files.

## Merged history

`main` has four merged pull requests so that `acc scan` has a month to report on. Three are agent
changes, merged after an independent human approved them. The fourth was merged by the operator
without any review while this demo was being set up, before the ruleset on `main` was enabled.
That was done on purpose, to produce one ACC003 finding (merged without independent approval).
It is not an incident.

The exception is recorded as a disposition in
[`.agent-change-control/dispositions.json`](.agent-change-control/dispositions.json): status
`accepted`, an owner, the date it was decided, an expiry date and the rationale. The scan applies
it, and [`manifests/history.json`](manifests/history.json) is the manifest with the disposition in
place. `acc check --as-of <date>` then passes for dates within the exception window, while the
finding itself stays in the record.

## The ruleset

After seeding, a ruleset on `main` requires the `change-control` check from GitHub Actions and
allows no bypass ([`ruleset/main.json`](ruleset/main.json)). The failing scenarios cannot be
merged. That is part of the demo.

The ruleset requires zero approving reviews. GitHub's own count would accept the reviewer app's
approval in scenario 09, and would reject scenario 10. acc applies the independence rules, so the
check is the gate.

## Try it on your own repository

The minimal workflow, from acc's [GitHub Action docs](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/github-action.md):

```yaml
name: change-control
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
  pull_request_review:
    types: [submitted, dismissed]

permissions:
  contents: read
  pull-requests: read

jobs:
  acc:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: noru-tech/agent-change-control@v0.6.0
```

Pin both actions to commit SHAs in production, as this repository does. Then tell acc who the
agent was. Agents or their operators can put this block in the pull request description:

````text
```agent-change-control
author: claude-code
operator: your-github-login
```
````

If your agents already write `Co-Authored-By` trailers (Claude Code, Copilot), acc reads those
with no change at all, as scenario 06 shows.

## Verify a signed verdict yourself

Each month, [`monthly-scan.yml`](.github/workflows/monthly-scan.yml) scans the previous month's
merged pull requests, signs the manifest through GitHub artifact attestations and publishes it as
a release asset. Verification has two halves, as in acc's
[signing docs](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/signing.md):
the signature says who signed, and `acc validate` says whether the findings follow from the facts.

```bash
REPO=noru-tech/agent-change-control-demo
TAG=$(gh release list --repo "$REPO" --json tagName --jq '[.[] | select(.tagName | startswith("manifest-"))][0].tagName')
gh release download "$TAG" --repo "$REPO" --pattern "$TAG.json"

# 1. Signature and identity, against GitHub's attestation store
gh attestation verify "$TAG.json" --repo "$REPO" \
  --predicate-type https://noru.tech/spec/ai-change-provenance/v0.3

# 2. Content: unwrap the Statement and re-evaluate it
gh attestation download "$TAG.json" --repo "$REPO"    # writes <digest>.jsonl
jq -r '.dsseEnvelope.payload' "$(ls -t ./*.jsonl | head -1)" | base64 -d > statement.json
acc validate statement.json
```

The two documents behind scenario 10 are on the `attestations` branch, under the head commit of
its pull request. Check them the same way the change-control workflow does:

```bash
REPO=noru-tech/agent-change-control-demo
PR=$(yq '.scenarios[] | select(.id == "10") | .pr' scenarios.yml)
HEAD=$(gh pr view "$PR" --repo "$REPO" --json headRefOid --jq .headRefOid)
for kind in provenance review; do
  for f in "$kind.predicate.json" "$kind.sigstore.json"; do
    gh api "repos/$REPO/contents/heads/$HEAD/$f?ref=attestations" \
      -H "Accept: application/vnd.github.raw" > "$f"
  done
done

gh attestation verify provenance.predicate.json --bundle provenance.sigstore.json --repo "$REPO" \
  --signer-workflow "$REPO/.github/workflows/agent-write.yml" --source-ref refs/heads/main \
  --predicate-type https://noru.tech/spec/ai-change-provenance/provenance/v0.1

gh attestation verify review.predicate.json --bundle review.sigstore.json --repo "$REPO" \
  --signer-workflow "$REPO/.github/workflows/agent-review.yml" --source-ref refs/heads/main \
  --predicate-type https://noru.tech/spec/ai-change-provenance/review/v0.1
```

Each Statement has two subjects: the head commit (`gitCommit`), which is how acc binds the
document to the change, and the sha256 of the predicate file, which is what
`gh attestation verify` matches on disk.

## What is real in this demo

- **The service is synthetic.** `kassaflow` is a made-up invoicing API with no real data, no
  customers and no deployment. The code plays no part in any verdict: acc never reads code to
  decide who wrote it.
- **The changes were written by Claude Code** ahead of time, under the operator's direction, and
  are stored under `scenarios/`. The writer app pushes them. That is why the declarations say
  `claude-code`, and why the trailer in scenario 06 is accurate. The Agent Trace record in
  scenario 07 is generated by the seed script in Agent Trace format; Claude Code does not write
  that format itself.
- **The accounts are real.** Two people with their own GitHub accounts, and three GitHub Apps.
  Every human approval was clicked by that human in the GitHub UI. No script presses a human's
  button.
- **One agent review is a model run; two are not.** In scenario 10 an OpenAI model reviewed the
  diff, and its unedited output is the review. In 08 and 09 the reviewer apps approve with a note
  saying no model was run. acc decides on who approved which commit, not on what a review says,
  so those two verdicts are the same either way.
- **The people agreed to appear here.** Their logins and review times are in the pull requests,
  in the manifests and in the signed attestations, which are public and, for Sigstore, permanent.
  Read acc's [privacy note](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/privacy.md)
  before you publish manifests from your own repository.

## Layout

| Path | What it is |
| --- | --- |
| [`scenarios.yml`](scenarios.yml) | Every scenario: branch, pull request, expected outcome per rule, matching acc fixture |
| [`scenarios/`](scenarios) | The pre-written change and pull request text for each scenario and history entry |
| [`.agent-change-control/`](.agent-change-control) | The policy and the recorded exception |
| [`scripts/`](scripts) | Seeding, evidence gathering, signing, the reviewer, verification |
| [`.github/workflows/`](.github/workflows) | `change-control`, `agent-write`, `agent-review`, `monthly-scan`, `verify-demo`, `ci`, `scorecard` |
| [`SETUP.md`](SETUP.md), [`VERIFY.md`](VERIFY.md) | How the demo was built, and how to re-check it after an acc release |

MIT licence. Maintained by [Noru](https://noru.tech). You do not need a Noru account, or to have
heard of Noru, to use anything here.

[pr01]: https://github.com/noru-tech/agent-change-control-demo/pulls?q=is%3Apr+head%3Ademo%2F01-clean-agent-change
[pr02]: https://github.com/noru-tech/agent-change-control-demo/pulls?q=is%3Apr+head%3Ademo%2F02-operator-self-approved
[pr03]: https://github.com/noru-tech/agent-change-control-demo/pulls?q=is%3Apr+head%3Ademo%2F03-no-approval
[pr04]: https://github.com/noru-tech/agent-change-control-demo/pulls?q=is%3Apr+head%3Ademo%2F04-operator-unknown
[pr05]: https://github.com/noru-tech/agent-change-control-demo/pulls?q=is%3Apr+head%3Ademo%2F05-stale-approval
[pr06]: https://github.com/noru-tech/agent-change-control-demo/pulls?q=is%3Apr+head%3Ademo%2F06-trailer-derived
[pr07]: https://github.com/noru-tech/agent-change-control-demo/pulls?q=is%3Apr+head%3Ademo%2F07-agent-trace
[pr08]: https://github.com/noru-tech/agent-change-control-demo/pulls?q=is%3Apr+head%3Ademo%2F08-same-vendor-review
[pr09]: https://github.com/noru-tech/agent-change-control-demo/pulls?q=is%3Apr+head%3Ademo%2F09-agent-review-unsigned
[pr10]: https://github.com/noru-tech/agent-change-control-demo/pulls?q=is%3Apr+head%3Ademo%2F10-zero-human-four-eyes
[r1]: https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC001.md
[r2]: https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC002.md
[r6]: https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC006.md
[r7]: https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC007.md
[r8]: https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC008.md
[r10]: https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC010.md
