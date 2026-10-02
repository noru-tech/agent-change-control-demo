#!/usr/bin/env bash
# Evaluate a synthetic copy of every scenario offline and compare the outcomes with
# scenarios.yml. Needs no GitHub access and no credentials, only acc, node, jq and yq.
#
#   scripts/preview.sh            check every scenario
#   scripts/preview.sh --table    also print acc's table for each one
#
# A pass here means the expectations in scenarios.yml match how the pinned acc release
# evaluates each scenario. It says nothing about the live pull requests; scripts/verify.sh does.

source "$(dirname "$0")/lib.sh"
need node jq yq
ACC="$(acc_bin)"

# The pins in the change-control workflow must match scenarios.yml.
workflow="$ROOT/.github/workflows/change-control.yml"
grep -q "noru-tech/agent-change-control@$(cfg '.acc.action_sha') # v$(cfg '.acc.version')" "$workflow" \
  || die "change-control.yml does not pin the action to acc.action_sha (v$(cfg '.acc.version'))"
grep -q "version: \"$(cfg '.acc.version')\"" "$workflow" \
  || die "change-control.yml does not pin version: \"$(cfg '.acc.version')\""

out="$ROOT/.verify/preview"
rm -rf "$out"
config_json | node "$ROOT/scripts/preview.mjs" "$out"

failed=0
for id in $(cfg '.scenarios[].id'); do
  manifest="$out/$id.manifest.json"
  "$ACC" -q evaluate "$out/$id.events.json" --policy "$POLICY" --format json --output "$manifest"
  set +e
  "$ACC" -q check "$manifest" >/dev/null
  code=$?
  set -e
  if [ "${1:-}" = "--table" ]; then
    echo "== $id"
    "$ACC" -q check "$manifest" --format table || true
  fi
  if compare_outcomes "$id" "$manifest" && compare_check "$id" "$code"; then
    echo "ok   $id"
  else
    echo "FAIL $id"
    failed=1
  fi
done

[ "$failed" -eq 0 ] || die "scenarios.yml does not match acc $(cfg '.acc.version'); see the lines above"
echo "All scenarios match acc $(cfg '.acc.version')."
