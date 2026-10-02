#!/usr/bin/env bash
# Check every scenario pull request against scenarios.yml with the pinned acc release.
#
#   scripts/verify.sh            all scenarios
#   scripts/verify.sh 05 10      only these
#
# For each scenario: gather the same evidence the change-control workflow uses
# (scripts/acc-inputs.sh), run `acc pr <n> --format json`, and compare every rule's outcome and
# the policy exit status with `expected` and `check`. Exits 1 with a readable diff on any
# mismatch, so .github/workflows/verify-demo.yml can open an issue.
#
# Needs gh (logged in, or GH_TOKEN set; public read access is enough), acc, jq and yq.

source "$(dirname "$0")/lib.sh"
need gh jq yq
ACC="$(acc_bin)"
# acc reads GITHUB_TOKEN or GH_TOKEN, not gh's login; without one it is limited to 60 requests an
# hour, which ten pull requests exceed.
if [ -z "${GITHUB_TOKEN:-}" ] && [ -z "${GH_TOKEN:-}" ]; then
  GITHUB_TOKEN="$(gh auth token)" || die "set GITHUB_TOKEN or log in with gh"
  export GITHUB_TOKEN
fi

ids=("$@")
if [ "${#ids[@]}" -eq 0 ]; then
  while IFS= read -r id; do ids+=("$id"); done < <(cfg '.scenarios[].id')
fi

out="$ROOT/.verify/live"
mkdir -p "$out"
failed=0
for id in "${ids[@]}"; do
  pr="$(cfg ".scenarios[] | select(.id == \"$id\") | .pr // \"\"")"
  [ -n "$pr" ] || { echo "FAIL $id: no pull request number in scenarios.yml (run scripts/seed.sh)"; failed=1; continue; }

  inputs="$out/$id.inputs"
  "$ROOT/scripts/acc-inputs.sh" "$pr" "$inputs"
  args=(pr "$pr" --repo "$REPO" --policy "$POLICY" --format json --output "$out/$id.manifest.json")
  while IFS= read -r line; do [ -z "$line" ] || args+=(--agent-account "$line"); done < "$inputs/agent-accounts.txt"
  while IFS= read -r line; do [ -z "$line" ] || args+=(--agent-vendor "$line"); done < "$inputs/agent-vendors.txt"
  [ ! -d "$inputs/traces" ] || args+=(--agent-trace "$inputs/traces")
  if [ -d "$inputs/verification" ]; then
    for file in "$inputs"/verification/*.json; do args+=(--verification "$file"); done
    args+=(--verified-by "$(cat "$inputs/verified-by.txt")")
  fi

  set +e
  "$ACC" -q "${args[@]}"
  code=$?
  set -e
  if [ "$code" -gt 1 ]; then
    echo "FAIL $id (#$pr): acc exited $code; see https://github.com/noru-tech/agent-change-control/blob/main/docs/exit-codes.md"
    failed=1
    continue
  fi
  if compare_outcomes "$id" "$out/$id.manifest.json" && compare_check "$id" "$code"; then
    echo "ok   $id (#$pr)"
  else
    echo "FAIL $id (#$pr)"
    failed=1
  fi
done

[ "$failed" -eq 0 ] || die "verdicts drifted from scenarios.yml under acc $(cfg '.acc.version')"
echo "All scenario pull requests match scenarios.yml under acc $(cfg '.acc.version')."
