# shellcheck shell=bash
# shellcheck disable=SC2034  # variables used by the scripts that source this file
# Shared helpers for the demo scripts. Source it; do not run it.
# Requires: bash 4+, jq, yq (mikefarah, v4), and acc for anything that evaluates.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/scenarios.yml"
POLICY="$ROOT/.agent-change-control/policy.yml"
RULES=(ACC001 ACC002 ACC003 ACC006 ACC007 ACC008 ACC009 ACC010)

die() { echo "error: $*" >&2; exit 1; }

need() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null || die "$tool is required (see SETUP.md, prerequisites)"
  done
}

# cfg EXPR: read one value from scenarios.yml.
cfg() { yq -r "$1" "$CONFIG"; }

# config_json: the whole of scenarios.yml as JSON.
config_json() { yq -o=json '.' "$CONFIG"; }

# acc_bin: the acc on PATH, which must be the pinned release.
acc_bin() {
  local want have
  want="$(cfg '.acc.version')"
  have="$(acc --version 2>/dev/null | awk '{print $2}')"
  [ "$have" = "$want" ] || die "acc $want is pinned in scenarios.yml, but acc on PATH is '${have:-missing}'"
  echo acc
}

# compare_outcomes ID MANIFEST: diff each rule's status in MANIFEST against scenarios.yml.
# Prints one line per mismatch; returns 1 if any rule differs.
compare_outcomes() {
  local id="$1" manifest="$2" rule want got rc=0
  for rule in "${RULES[@]}"; do
    want="$(cfg ".scenarios[] | select(.id == \"$id\") | .expected.$rule")"
    got="$(jq -r --arg r "$rule" '[.assessments[] | select(.rule_id == $r) | .status] | first // "missing"' "$manifest")"
    if [ "$want" != "$got" ]; then
      printf '  %s %s: expected %s, got %s\n' "$id" "$rule" "$want" "$got"
      rc=1
    fi
  done
  return "$rc"
}

# compare_check ID EXIT: compare acc's policy exit status with the scenario's expected check.
compare_check() {
  local id="$1" code="$2" want got
  want="$(cfg ".scenarios[] | select(.id == \"$id\") | .check")"
  case "$code" in
    0) got=success ;;
    1) got=failure ;;
    *) got="error (exit $code)" ;;
  esac
  if [ "$want" != "$got" ]; then
    printf '  %s check: expected %s, got %s\n' "$id" "$want" "$got"
    return 1
  fi
}

REPO="${GITHUB_REPOSITORY:-$(cfg '.repository')}"
PROVENANCE_TYPE="https://noru.tech/spec/ai-change-provenance/provenance/v0.1"
REVIEW_TYPE="https://noru.tech/spec/ai-change-provenance/review/v0.1"

# item_json ID: one scenario ("01".."10") or history entry ("h1".."h4") as JSON.
item_json() {
  config_json | jq -e --arg id "$1" '[.scenarios[], .history[] | select(.id == $id)] | first' \
    || die "no scenario or history entry with id '$1' in scenarios.yml"
}

# item_dir ID: where the item's files live.
item_dir() {
  case "$1" in
    h*) echo "$ROOT/scenarios/history/$1" ;;
    *) echo "$ROOT/scenarios/$1" ;;
  esac
}

# pr_for_branch BRANCH: the number of the pull request from BRANCH (any state), or empty.
pr_for_branch() {
  gh pr list --repo "$REPO" --head "$1" --state all --json number --jq '.[0].number // empty'
}

# head_of PR: the pull request's current head commit.
head_of() { gh api "repos/$REPO/pulls/$1" --jq .head.sha; }

# login ROLE: a GitHub login from scenarios.yml identities (operator, reviewer, ...).
login() {
  local value
  value="$(cfg ".identities.$1")"
  if [ "$1" = reviewer_agent_operator ] && [ -z "$value" ]; then value="$(cfg '.identities.reviewer')"; fi
  [ -n "$value" ] || die "identities.$1 is empty in scenarios.yml (SETUP.md, step 1)"
  echo "$value"
}

# bot_identity APP_SLUG: "name <email>" git uses for commits by a GitHub App's bot user.
bot_identity() {
  local id
  id="$(gh api "users/$1%5Bbot%5D" --jq .id)"
  echo "$1[bot] <$id+$1[bot]@users.noreply.github.com>"
}

# api_or_empty PATH JQ: run `gh api PATH --jq JQ`, printing nothing when the path does not exist
# (gh writes the 404 body to stdout, which must not be mistaken for content).
api_or_empty() {
  local result
  if result="$(gh api "$1" --jq "$2" 2>/dev/null)"; then printf '%s' "$result"; fi
}

# set_pr ID NUMBER: write a pull request number into scenarios.yml without reformatting the file
# (yq -i drops blank lines and comment alignment). Matches the `pr:` line right after `id: "ID"`.
set_pr() {
  local tmp
  tmp="$(mktemp)"
  awk -v id="$1" -v pr="$2" '
    $0 ~ "^  - id: \"?" id "\"?$" { hit = 1; print; next }
    hit && $1 == "pr:" { sub(/pr: .*/, "pr: " pr); hit = 0 }
    { print }
  ' "$CONFIG" > "$tmp"
  mv "$tmp" "$CONFIG"
}
