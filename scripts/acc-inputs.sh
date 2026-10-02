#!/usr/bin/env bash
# Gather the evidence acc needs for one pull request, beyond what it collects from the API itself:
#
#   scripts/acc-inputs.sh PR OUT_DIR
#
# Writes into OUT_DIR:
#   agent-accounts.txt   LOGIN=AGENT lines, from scenarios.yml
#   agent-vendors.txt    AGENT=VENDOR lines, from scenarios.yml
#   traces/              Agent Trace records committed under traces/ on the pull request's head
#   verification/        `gh attestation verify --format json` output for every signed bundle
#                        published for the head commit (scenario 10)
#   verified-by.txt      who verified those bundles, for acc's --verified-by
#
# Used by .github/workflows/change-control.yml (inputs to the acc action) and by
# scripts/verify.sh (the same inputs as CLI flags), so both see the same evidence.
#
# A bundle that is published but fails verification stops the script: a signature that does not
# check out is an error to look at, never something to drop silently.

source "$(dirname "$0")/lib.sh"
need gh jq yq

pr="${1:?usage: acc-inputs.sh PR OUT_DIR}"
out="${2:?usage: acc-inputs.sh PR OUT_DIR}"
rm -rf "$out"
mkdir -p "$out"

cfg '.evidence.agent_accounts[]' > "$out/agent-accounts.txt"
cfg '.evidence.agent_vendors[]' > "$out/agent-vendors.txt"

head="$(head_of "$pr")"

# Agent Trace records on the head commit. Read through the API, so no code from the pull
# request is checked out or run.
traces="$(api_or_empty "repos/$REPO/contents/traces?ref=$head" '.[] | select(.name | endswith(".json")) | .path')"
if [ -n "$traces" ]; then
  mkdir -p "$out/traces"
  for path in $traces; do
    gh api "repos/$REPO/contents/$path?ref=$head" -H "Accept: application/vnd.github.raw" > "$out/traces/$(basename "$path")"
  done
fi

# Signed bundles for the head commit, each checked against the workflow allowed to sign it.
branch="$(cfg '.evidence.attestations_branch')"
listing="$(api_or_empty "repos/$REPO/contents/heads/$head?ref=$branch" '.[].name')"
for kind in provenance review; do
  grep -qx "$kind.sigstore.json" <<<"$listing" || continue
  mkdir -p "$out/bundles" "$out/verification"
  for file in "$kind.sigstore.json" "$kind.predicate.json"; do
    gh api "repos/$REPO/contents/heads/$head/$file?ref=$branch" -H "Accept: application/vnd.github.raw" > "$out/bundles/$file"
  done
  case "$kind" in
    provenance) type="$PROVENANCE_TYPE" ;;
    review) type="$REVIEW_TYPE" ;;
  esac
  workflow="$(cfg ".evidence.signer_workflows.$kind")"
  gh attestation verify "$out/bundles/$kind.predicate.json" --bundle "$out/bundles/$kind.sigstore.json" \
    --repo "$REPO" --signer-workflow "$REPO/$workflow" --source-ref refs/heads/main \
    --predicate-type "$type" --deny-self-hosted-runners --format json > "$out/verification/$kind.json" \
    || die "the $kind bundle for $head does not verify against $workflow"
done

if [ -d "$out/verification" ]; then
  by="gh attestation verify (signer workflow pinned per document kind, source ref refs/heads/main)"
  if [ -n "${GITHUB_RUN_ID:-}" ]; then
    by="$by, in $GITHUB_SERVER_URL/$REPO/actions/runs/$GITHUB_RUN_ID"
  else
    by="$by, by scripts/verify.sh"
  fi
  echo "$by" > "$out/verified-by.txt"
fi

echo "evidence for #$pr at $head:" \
  "traces=$(ls "$out/traces" 2>/dev/null | wc -l | tr -d ' ')" \
  "signed=$(ls "$out/verification" 2>/dev/null | wc -l | tr -d ' ')" >&2
