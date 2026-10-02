#!/usr/bin/env bash
# Create a scenario's branch and commits, and open its pull request.
#
#   scripts/open-change.sh ID [--followup] [--refresh]
#
# ID is a scenario ("01".."10") or a history entry ("h1".."h4") from scenarios.yml.
#
# Who acts is decided by the token in GH_TOKEN, and must match the item's `opened_by`:
#   writer_app  run by .github/workflows/agent-write.yml with the writer app's installation token
#   operator    run by the operator on their own machine, with their own `gh` login
#
# --followup  push the scenario's follow-up commit to an existing pull request (scenario 05)
# --refresh   rebuild the branch even if its pull request already exists (force-push)
#
# Idempotent: when the pull request already exists, and neither flag is given, nothing changes.
# The changes themselves are pre-written under scenarios/<ID>/files (see README, "What is real").

source "$(dirname "$0")/lib.sh"
need gh git jq yq

id="${1:?usage: open-change.sh ID [--followup] [--refresh]}"
shift
followup=false
refresh=false
for arg in "$@"; do
  case "$arg" in
    --followup) followup=true ;;
    --refresh) refresh=true ;;
    *) die "unknown argument $arg" ;;
  esac
done

item="$(item_json "$id")"
dir="$(item_dir "$id")"
field() { jq -r "$1" <<<"$item"; }
branch="$(field .branch)"
opened_by="$(field .opened_by)"
token="${GH_TOKEN:-$(gh auth token)}"
remote="https://x-access-token:${token}@github.com/${REPO}.git"

# Commit identity: the writer app's bot user, or the operator's GitHub noreply address, so that
# GitHub (and therefore acc) attributes each commit to the right account.
if [ "$opened_by" = writer_app ]; then
  author="$(bot_identity "$(login writer_app)")"
else
  me="$(gh api user --jq .login)"
  [ "$(tr '[:upper:]' '[:lower:]' <<<"$me")" = "$(login operator | tr '[:upper:]' '[:lower:]')" ] \
    || die "item $id is opened by the operator ($(login operator)), but gh is logged in as $me"
  author="$(gh api user --jq '"\(.name // .login) <\(.id)+\(.login)@users.noreply.github.com>"')"
fi
export GIT_AUTHOR_NAME="${author% <*}" GIT_COMMITTER_NAME="${author% <*}"
export GIT_AUTHOR_EMAIL="${author##*<}" GIT_COMMITTER_EMAIL="${author##*<}"
GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL%>}" GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL%>}"

existing="$(pr_for_branch "$branch")"
if [ -n "$existing" ] && [ "$followup" = false ] && [ "$refresh" = false ]; then
  echo "$id: pull request #$existing already exists for $branch; nothing to do"
  exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git clone --quiet --no-tags "$remote" "$work/repo"
cd "$work/repo" || exit 1

commit() {
  git add -A
  git -c commit.gpgsign=false commit --quiet -m "$1"
}

if [ "$followup" = true ]; then
  [ -n "$existing" ] || die "$id: --followup needs the pull request to exist first"
  [ -d "$dir/followup" ] || die "$id has no follow-up commit"
  git checkout --quiet "$branch"
  cp -R "$dir/followup/." .
  commit "Widen invoice number range and validate the year"
  git push --quiet origin "$branch"
  echo "$id: pushed follow-up commit $(git rev-parse HEAD) to #$existing"
  exit 0
fi

base="$(git rev-parse origin/main)"
git checkout --quiet -B "$branch" "$base"
cp -R "$dir/files/." .
message="$(field .title | sed -E 's/^[0-9]+: //')"
if [ "$(field '.trailers // false')" = true ]; then
  # Scenario 06: the trailer Claude Code writes into the commits it produces. The change under
  # scenarios/06/files was written with Claude Code, so the trailer is accurate.
  message="$message"$'\n\n'"Co-Authored-By: Claude <noreply@anthropic.com>"
fi
commit "$message"

if [ "$(field '.agent_trace // false')" = true ]; then
  # Scenario 07: an Agent Trace record (https://agent-trace.dev) for the commit above, bound to it
  # by vcs.revision. acc reads it with --agent-trace and derives the agent from tool.name.
  revision="$(git rev-parse HEAD)"
  mkdir -p traces
  file="$(cd "$dir/files" && find src -name '*.ts' | head -1)"
  lines="$(wc -l < "$file" | tr -d ' ')"
  record_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  jq -n --arg id "$record_id" --arg rev "$revision" --arg file "$file" --argjson lines "$lines" \
    --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
      version: "0.1.0",
      id: $id,
      timestamp: $at,
      vcs: {type: "git", revision: $rev},
      tool: {name: "claude-code"},
      files: [{path: $file, conversations: [{contributor: {type: "ai"},
        ranges: [{start_line: 1, end_line: $lines}]}]}]
    }' > "traces/$record_id.json"
  commit "Add Agent Trace record for $file"
fi

head="$(git rev-parse HEAD)"
git push --quiet --force origin "$branch"

if [ "$(field '.sign_provenance // false')" = true ]; then
  # Scenario 10: a provenance document for the head commit, signed in this workflow run.
  predicate="$work/provenance.predicate.json"
  jq -n --arg op "github:$(login operator)" --arg base "$base" --arg head "$head" \
    --arg session "${GITHUB_RUN_ID:-local}" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
      spec_version: "0.1",
      agent: {name: "claude-code", version: null},
      operator: {id: $op},
      session: {id: $session, started_at: $at},
      change: {base_commit: $base, head_commit: $head}
    }' > "$predicate"
  "$ROOT/scripts/sign.sh" provenance "$predicate" "$head" "$id"
fi

if [ -n "$existing" ]; then
  echo "$id: refreshed $branch at $head (pull request #$existing)"
  exit 0
fi

body="$work/body.md"
sed "s/{{operator}}/$(login operator)/g; s/{{reviewer}}/$(login reviewer)/g" "$dir/body.md" > "$body"
if [ "$(field .declaration)" = true ]; then
  printf '\n```agent-change-control\nauthor: claude-code\noperator: %s\n```\n' "$(login operator)" >> "$body"
fi

args=(--repo "$REPO" --head "$branch" --base main --title "$(field .title)" --body-file "$body")
for label in $(field '.labels // [] | .[]'); do
  gh label create "$label" --repo "$REPO" --force \
    --description "agent_review policy applies (see .agent-change-control/policy.yml)" >/dev/null
  args+=(--label "$label")
done
url="$(gh pr create "${args[@]}")"
echo "$id: opened $url at $head"
