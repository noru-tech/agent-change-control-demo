#!/usr/bin/env bash
# Have a reviewing agent review a scenario's pull request and submit its decision.
#
#   scripts/agent-review.sh ID
#
# Run by .github/workflows/agent-review.yml for scenarios 08, 09 and 10. The workflow picks the
# app (GH_TOKEN is its installation token) and the model from the scenario's `review`:
#   reviewer_same_app  same vendor as the writing agent (anthropic)
#   reviewer_app       another vendor (openai)
#
# Environment:
#   GH_TOKEN            the reviewing app's installation token
#   MODEL_VENDOR        anthropic or openai
#   MODEL               the model id to call
#   ANTHROPIC_API_KEY or OPENAI_API_KEY
#   ATTESTATIONS_TOKEN  for scripts/sign.sh, when the scenario signs its review
#   ACTIONS_TOKEN       the job's GITHUB_TOKEN, to re-run the change-control check afterwards
#
# The review the model writes is submitted as written. If it requests changes, the review is
# still submitted and the script fails: the scenario then needs a look, not a retry until the
# model agrees.

source "$(dirname "$0")/lib.sh"
need gh jq yq curl

id="${1:?usage: agent-review.sh ID}"
item="$(item_json "$id")"
field() { jq -r "$1" <<<"$item"; }
case "$(field .review)" in
  reviewer_app) app="$(login reviewer_app)"; agent="$app" ;;
  reviewer_same_app) app="$(login reviewer_same_app)"; agent=claude-code-review ;;
  *) die "scenario $id is not reviewed by an agent" ;;
esac

pr="$(pr_for_branch "$(field .branch)")"
[ -n "$pr" ] || die "scenario $id has no pull request yet"
head="$(head_of "$pr")"
already="$(gh api "repos/$REPO/pulls/$pr/reviews" \
  --jq "[.[] | select(.user.login == \"${app}[bot]\" and .commit_id == \"$head\")] | length")"
if [ "$already" -gt 0 ]; then
  echo "$id: ${app}[bot] already reviewed #$pr at $head; nothing to do"
  exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
gh api "repos/$REPO/pulls/$pr" -H "Accept: application/vnd.github.diff" > "$work/change.diff"
"$ROOT/scripts/review-model.sh" "${MODEL_VENDOR:?}" "${MODEL:?}" "$work/change.diff" \
  > "$work/review.md" 2> "$work/model.log" || { cat "$work/model.log" >&2; exit 1; }
served="$(sed -n 's/^model: //p' "$work/model.log")"

decision="$(grep -Eo '^DECISION: (APPROVE|REQUEST_CHANGES)\s*$' "$work/review.md" | tail -1 | awk '{print $2}')"
[ -n "$decision" ] || die "the model's review has no DECISION line; nothing submitted"

body="$work/body.md"
{
  sed '/^DECISION: /d' "$work/review.md"
  echo
  echo "---"
  echo "Submitted by \`${app}[bot]\`, a reviewing agent for this demo. The text above is the"
  echo "unedited output of \`$served\` ($MODEL_VENDOR), given the diff and"
  echo "[the review prompt](https://github.com/$REPO/blob/main/scripts/review-prompt.md)."
} > "$body"
event="$decision"
response="$(jq -n --arg commit "$head" --arg event "$event" --rawfile body "$body" \
  '{commit_id: $commit, event: $event, body: $body}' \
  | gh api "repos/$REPO/pulls/$pr/reviews" --method POST --input -)"
submitted="$(jq -r .submitted_at <<<"$response")"
echo "$id: ${app}[bot] submitted $event on #$pr at $head ($submitted)"

if [ "$(field '.sign_review // false')" = true ]; then
  owner="github:$(login reviewer_agent_operator)"
  predicate="$work/review.predicate.json"
  jq -n --arg id "github:${app}[bot]" --arg agent "$agent" --arg head "$head" --arg at "$submitted" \
    --arg owner "$owner" --arg digest "sha256:$(sha256sum "$ROOT/scripts/review-prompt.md" | cut -d' ' -f1)" \
    --arg model "$served" --arg session "${GITHUB_RUN_ID:-local}" --arg started "$started" \
    --arg decision "$([ "$event" = APPROVE ] && echo approved || echo changes_requested)" '{
      spec_version: "0.1",
      reviewer: {kind: "agent", id: $id, agent: $agent},
      decision: $decision,
      change: {head_commit: $head},
      submitted_at: $at,
      operator: {id: $owner},
      instructions: {owner: $owner, digest: $digest},
      model: $model,
      session: {id: $session, started_at: $started}
    }' > "$predicate"
  # The review text goes next to the bundle, so the README can point at the exact model output.
  cp "$work/review.md" "$work/review-output.md"
  EXTRA_FILE="$work/review-output.md" "$ROOT/scripts/sign.sh" review "$predicate" "$head" "$id"
fi

# The review event already started a change-control run, possibly before the bundle above was
# published. Re-run the latest one so the check reflects the signed review.
if [ -n "${ACTIONS_TOKEN:-}" ]; then
  run="$(GH_TOKEN="$ACTIONS_TOKEN" gh run list --repo "$REPO" --workflow change-control.yml \
    --commit "$head" --limit 1 --json databaseId --jq '.[0].databaseId // empty')"
  if [ -n "$run" ]; then
    GH_TOKEN="$ACTIONS_TOKEN" gh run watch "$run" --repo "$REPO" >/dev/null || true
    GH_TOKEN="$ACTIONS_TOKEN" gh run rerun "$run" --repo "$REPO" || true
    echo "$id: re-ran change-control run $run"
  fi
fi

[ "$event" = APPROVE ] || die "the model requested changes on #$pr; read the review before re-seeding"
