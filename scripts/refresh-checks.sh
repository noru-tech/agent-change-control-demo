#!/usr/bin/env bash
# Re-run every change-control run on each scenario pull request's current head, so that all of
# them show the final verdict.
#
#   scripts/refresh-checks.sh
#
# A pull request collects one change-control run per event: the one from when it was opened, one
# per review. Each is right for the moment it ran, but GitHub shows them side by side, so a
# scenario that passed after its approval still shows the red run from before it. acc reads the
# pull request's current state, so re-running them all makes them agree. Run after seeding, and
# after anything that adds a run (VERIFY.md).
#
# One at a time: change-control.yml cancels a pull request's in-progress run when another starts,
# so re-running several at once would leave all but the last cancelled.

source "$(dirname "$0")/lib.sh"
need gh jq yq

for id in $(cfg '.scenarios[].id'); do
  pr="$(cfg ".scenarios[] | select(.id == \"$id\") | .pr")"
  head="$(head_of "$pr")"
  runs="$(gh run list --repo "$REPO" --workflow change-control.yml --commit "$head" --limit 50 \
    --json databaseId,status --jq '.[] | select(.status == "completed") | .databaseId')"
  for run in $runs; do
    gh run rerun "$run" --repo "$REPO" >/dev/null
    sleep 3
    gh run watch "$run" --repo "$REPO" >/dev/null || true
  done
  echo "$id (#$pr): re-ran $(wc -w <<<"$runs" | tr -d ' ') run(s)"
done
