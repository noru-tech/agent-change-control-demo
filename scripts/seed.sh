#!/usr/bin/env bash
# Seed the demo: merged history, then one open pull request per scenario, in the order the
# scenarios need. Run by the operator, on their own machine, logged in to gh as themselves.
#
#   scripts/seed.sh
#
# Agent actions run in GitHub Actions under the apps' installation tokens (agent-write.yml,
# agent-review.yml); this script dispatches them and waits. Operator actions (opening 06, 07 and
# h4, merging the history) run here with the operator's own login. Human approvals are never
# scripted: when one is needed the script prints who must approve what, and waits until GitHub
# shows the approval.
#
# Idempotent: each step checks GitHub first and skips what is already done, so re-running it on
# a seeded repository changes nothing. Safe to stop with Ctrl-C and run again.
#
# Order that matters:
#   - history is merged before the ruleset on main is enabled (h4 has no approval by design);
#   - scenario 05's follow-up commit is pushed only after the reviewer approved the first head.

source "$(dirname "$0")/lib.sh"
need gh git jq yq acc

POLL=20

# --- helpers -----------------------------------------------------------------------------------

say() { printf '\n== %s\n' "$*"; }

human() {
  printf '\n  >> HUMAN STEP: %s\n' "$*"
  printf '     (waiting; this script checks GitHub every %ss)\n' "$POLL"
}

branch_of() { item_json "$1" | jq -r .branch; }
pr_of() { pr_for_branch "$(branch_of "$1")"; }
merged() { [ "$(gh pr view "$1" --repo "$REPO" --json state --jq .state)" = MERGED ]; }

# dispatch WORKFLOW KEY=VALUE...: run a workflow on main and wait for it to finish.
dispatch() {
  local workflow="$1" before run args=()
  shift
  for kv in "$@"; do args+=(-f "$kv"); done
  before="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  gh workflow run "$workflow" --repo "$REPO" --ref main "${args[@]}"
  for _ in $(seq 1 30); do
    run="$(gh run list --repo "$REPO" --workflow "$workflow" --event workflow_dispatch --limit 5 \
      --json databaseId,createdAt --jq "[.[] | select(.createdAt >= \"$before\")] | last | .databaseId // empty")"
    [ -z "$run" ] || break
    sleep 2
  done
  [ -n "$run" ] || die "could not find the $workflow run just dispatched"
  gh run watch "$run" --repo "$REPO" --exit-status >/dev/null \
    || die "$workflow failed: $(gh run view "$run" --repo "$REPO" --json url --jq .url)"
}

# approved_by PR LOGIN [COMMIT]: LOGIN's latest decision on PR approves COMMIT (default: head).
approved_by() {
  local commit="${3:-$(head_of "$1")}"
  [ "$(gh api "repos/$REPO/pulls/$1/reviews" --paginate --jq \
    "[.[] | select(.user.login | ascii_downcase == (\"$2\" | ascii_downcase)) | select(.state != \"COMMENTED\")] | last | (.state == \"APPROVED\" and .commit_id == \"$commit\")")" = true ]
}

wait_for_approval() {
  local pr="$1" who="$2" role="$3"
  approved_by "$pr" "$who" && return 0
  human "$who ($role) approves https://github.com/$REPO/pull/$pr in the GitHub UI (Files changed > Review changes > Approve)"
  until approved_by "$pr" "$who"; do sleep "$POLL"; done
  echo "     approved by $who"
}

# open ID: open the item's pull request if it does not exist yet, then record its number.
open() {
  local id="$1" pr
  pr="$(pr_of "$id")"
  if [ -z "$pr" ]; then
    if [ "$(item_json "$id" | jq -r .opened_by)" = operator ]; then
      "$ROOT/scripts/open-change.sh" "$id"
    else
      dispatch agent-write.yml "item=$id" "mode=open"
    fi
    pr="$(pr_of "$id")"
    [ -n "$pr" ] || die "$id: no pull request after opening it"
  fi
  case "$id" in
    h*) yq -i "(.history[] | select(.id == \"$id\") | .pr) = $pr" "$CONFIG" ;;
    *) yq -i "(.scenarios[] | select(.id == \"$id\") | .pr) = $pr" "$CONFIG" ;;
  esac
  echo "  $id -> #$pr"
}

# --- preflight ---------------------------------------------------------------------------------

say "Preflight"
OPERATOR="$(login operator)"
REVIEWER="$(login reviewer)"
[ "$(tr '[:upper:]' '[:lower:]' <<<"$OPERATOR")" != "$(tr '[:upper:]' '[:lower:]' <<<"$REVIEWER")" ] \
  || die "the operator and the reviewer must be different people"
me="$(gh api user --jq .login)"
[ "$(tr '[:upper:]' '[:lower:]' <<<"$me")" = "$(tr '[:upper:]' '[:lower:]' <<<"$OPERATOR")" ] \
  || die "run this as the operator ($OPERATOR); gh is logged in as $me"
gh repo view "$REPO" --json name >/dev/null || die "cannot see $REPO"
"$ROOT/scripts/preview.sh" >/dev/null || die "scenarios.yml does not match acc offline; fix that first"
echo "  operator=$OPERATOR reviewer=$REVIEWER repo=$REPO"

# --- 1. merged history -------------------------------------------------------------------------

say "1. Merged history (before the ruleset)"
for id in $(cfg '.history[].id'); do
  open "$id"
  pr="$(pr_of "$id")"
  if merged "$pr"; then echo "  $id (#$pr) already merged"; continue; fi
  if [ "$(item_json "$id" | jq -r .review)" = reviewer ]; then
    wait_for_approval "$pr" "$REVIEWER" "independent reviewer"
  else
    echo "  $id (#$pr) is merged without review on purpose: it becomes the ACC003 finding"
  fi
  gh pr merge "$pr" --repo "$REPO" --squash --delete-branch
  echo "  merged $id (#$pr)"
done

# --- 2. scenario pull requests -----------------------------------------------------------------

say "2. Scenario pull requests"
for id in $(cfg '.scenarios[].id'); do open "$id"; done

# --- 3. reviews --------------------------------------------------------------------------------

say "3. Reviews"
pr() { cfg ".scenarios[] | select(.id == \"$1\") | .pr"; }

# Scenario 05 first: approve, then the agent pushes again. Once the follow-up is pushed the
# approval is on an older commit, which is the point.
p05="$(pr 05)"
if [ "$(gh api "repos/$REPO/pulls/$p05" --jq .commits)" -lt 2 ]; then
  wait_for_approval "$p05" "$REVIEWER" "independent reviewer"
  dispatch agent-write.yml "item=05" "mode=followup"
  echo "  05: follow-up commit pushed after the approval"
else
  echo "  05: follow-up already pushed"
fi

for id in 01 04 06 07; do wait_for_approval "$(pr "$id")" "$REVIEWER" "independent reviewer"; done
wait_for_approval "$(pr 02)" "$OPERATOR" "the agent's operator, approving their own agent's change"
echo "  03: no review, on purpose"

for id in 08 09 10; do
  dispatch agent-review.yml "item=$id"
  echo "  $id: agent review submitted"
done

# --- 4. exception for the unreviewed merge -----------------------------------------------------

say "4. Exception for the merge without independent approval"
owner="$(cfg '.exception.owner')"
[ -n "$owner" ] || die "exception.owner is empty in scenarios.yml (SETUP.md, step 1)"
h4="$(cfg '.history[] | select(.id == "h4") | .pr')"
merged_at="$(gh pr view "$h4" --repo "$REPO" --json mergedAt --jq '.mergedAt[0:10]')"
first="$(for id in $(cfg '.history[].id'); do gh pr view "$(cfg ".history[] | select(.id == \"$id\") | .pr")" --repo "$REPO" --json mergedAt --jq '.mergedAt[0:10]'; done | sort | head -1)"
manifest="$ROOT/manifests/history.json"
mkdir -p "$ROOT/manifests"
"$ROOT/scripts/scan.sh" "$first" "$merged_at" "$manifest" >/dev/null
finding="$(jq -r --arg c "github:$REPO:pr:$h4" '.findings[] | select(.change_id == $c and .rule_id == "ACC003") | .id' "$manifest")"
[ -n "$finding" ] || die "expected an ACC003 finding for #$h4"
if [ "$(jq --arg f "$finding" 'has($f)' "$ROOT/.agent-change-control/dispositions.json")" = false ]; then
  today="$(date -u +%Y-%m-%d)"
  expires="$(date -u -v+"$(cfg '.exception.expires_in_days')"d +%Y-%m-%d 2>/dev/null \
    || date -u -d "+$(cfg '.exception.expires_in_days') days" +%Y-%m-%d)"
  jq --arg f "$finding" --arg owner "$owner" --arg today "$today" --arg expires "$expires" \
    --arg rationale "$(cfg '.exception.rationale')" \
    '.[$f] = {status: "accepted", owner: $owner, decided_at: $today, expires_at: $expires,
              rationale: $rationale, remediated_at: null}' \
    "$ROOT/.agent-change-control/dispositions.json" > "$ROOT/.agent-change-control/dispositions.json.tmp"
  mv "$ROOT/.agent-change-control/dispositions.json.tmp" "$ROOT/.agent-change-control/dispositions.json"
  "$ROOT/scripts/scan.sh" "$first" "$merged_at" "$manifest" >/dev/null
fi
echo "  $finding accepted; manifest at manifests/history.json"

# --- 5. links ----------------------------------------------------------------------------------

say "5. README links"
for id in $(cfg '.scenarios[].id'); do
  sed -i.bak -E "s#^\[pr$id\]: .*#[pr$id]: https://github.com/$REPO/pull/$(pr "$id")#" "$ROOT/README.md"
done
rm -f "$ROOT/README.md.bak"

say "Seeded"
cat <<EOF
  Remaining steps (SETUP.md, steps 6 to 9):
  - commit and push scenarios.yml, README.md, manifests/history.json and
    .agent-change-control/dispositions.json to main;
  - copy heads/<scenario 10 head>/review-output.md from the attestations branch to
    scenarios/10/review-output.md and fill in the model and date in the README;
  - run scripts/verify.sh;
  - enable the ruleset (ruleset/main.json), then run the monthly-scan workflow once.
EOF
