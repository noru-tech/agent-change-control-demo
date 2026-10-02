# Re-checking the demo after an acc release

The demo pins one acc release. After a new release, check that every scenario still means what
the README says, then move the pin.

## 1. Offline, before touching GitHub

1. Bump the pin in three places together:
   - `scenarios.yml`: `acc.version` and `acc.action_sha` (the commit of the new tag:
     `gh api repos/noru-tech/agent-change-control/commits/vX.Y.Z --jq .sha`);
   - `.github/workflows/change-control.yml`: the action's SHA and `# vX.Y.Z` comment, and `version:`.
   `scripts/preview.sh` refuses to run while they disagree.
2. Install the new release locally and run `scripts/preview.sh --table`.
3. Read the release's CHANGELOG for rule, policy and evidence changes. For each scenario whose
   outcome changed, run its matching fixture from `scenarios.yml` (`fixture:`) in the acc
   repository at the new tag:

   ```bash
   acc evaluate tests/fixtures/<fixture>/events.json --format table
   ```

   If the fixture changed the same way, update `expected` and `check` in `scenarios.yml`, the
   README table and the pull request's body, and record the change in `NOTES.md`. If it did not,
   the preview is wrong: fix `scripts/preview.mjs`.

## 2. Live pull requests

4. Merge the pin bump through a pull request (the ruleset requires the check).
5. Run `scripts/verify.sh`, or dispatch `verify-demo.yml`. Each scenario's live outcome must match
   `scenarios.yml`.
6. Re-run the change-control check on every scenario pull request so the visible checks use the
   new release:

   ```bash
   for pr in $(yq '.scenarios[].pr' scenarios.yml); do
     run=$(gh run list --workflow change-control.yml --branch "$(gh pr view "$pr" --json headRefName --jq .headRefName)" --limit 1 --json databaseId --jq '.[0].databaseId')
     gh run rerun "$run"
   done
   ```

## 3. When a scenario has to be re-seeded

Re-seeding a scenario (`agent-write.yml` with `mode: refresh`) pushes a new head, which makes every
approval on it stale. The humans then have to approve again, by hand:

| Scenario | Who re-approves |
| --- | --- |
| 01, 04, 06, 07 | the independent reviewer |
| 02 | the operator |
| 05 | the independent reviewer approves the refreshed head, **then** dispatch `agent-write.yml` with `mode: followup`; nobody approves again |
| 03 | nobody |
| 08, 09, 10 | nobody: dispatch `agent-review.yml` for the scenario. For 10 this also re-signs the review and replaces `scenarios/10/review-output.md` (commit the new one through a pull request and update the model and date in the README) |

Scenario 10's provenance is signed for the head commit, so a refresh also signs a new provenance
document. Old bundles stay on the `attestations` branch under their own head commits.

`scripts/seed.sh` is safe to re-run at any point: it skips every step GitHub already shows as done
and waits at the human steps that are not.

## 4. Monthly manifests

Nothing to do: `monthly-scan.yml` uses the pinned release from `scenarios.yml`. Manifests made with
an earlier release keep validating with `acc validate`; the predicate type changes only when the
specification version does (acc `docs/signing.md`).
