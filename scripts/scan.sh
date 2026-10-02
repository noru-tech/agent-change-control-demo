#!/usr/bin/env bash
# Scan the merged pull requests of a window into a manifest, with recorded exceptions applied.
#
#   scripts/scan.sh SINCE UNTIL OUTPUT
#
# SINCE and UNTIL are YYYY-MM-DD (inclusive, UTC). The manifest is written to OUTPUT as acc's
# canonical JSON (RFC 8785 bytes), ready to sign with actions/attest.
#
# Exceptions live in .agent-change-control/dispositions.json, keyed by finding id. acc keeps
# finding ids stable, so a disposition recorded once applies to every later scan of the same
# change. Editing a finding's `disposition` is the only edit acc allows (docs/policy.md,
# "Recording exceptions"); `acc validate` confirms the result.

source "$(dirname "$0")/lib.sh"
need jq yq
ACC="$(acc_bin)"

since="${1:?usage: scan.sh SINCE UNTIL OUTPUT}"
until="${2:?}"
output="${3:?}"
dispositions="$ROOT/.agent-change-control/dispositions.json"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
args=(scan github "$REPO" --since "$since" --until "$until" --policy "$POLICY" --format json --output "$work/scan.json")
while IFS= read -r line; do args+=(--agent-account "$line"); done < <(cfg '.evidence.agent_accounts[]')
while IFS= read -r line; do args+=(--agent-vendor "$line"); done < <(cfg '.evidence.agent_vendors[]')
"$ACC" "${args[@]}"

jq --slurpfile d "$dispositions" \
  '.findings |= map(if $d[0][.id] then .disposition = $d[0][.id] else . end)' \
  "$work/scan.json" > "$work/edited.json"
"$ACC" validate "$work/edited.json"
# Re-render through acc so the file is canonical again (signing needs the exact bytes).
set +e
"$ACC" -q check "$work/edited.json" --as-of "$until" --format json --output "$output"
code=$?
set -e
[ "$code" -le 1 ] || die "acc check exited $code"
"$ACC" validate "$output"

echo "manifest: $output"
"$ACC" -q check "$output" --as-of "$until" --format table || true
exit 0
