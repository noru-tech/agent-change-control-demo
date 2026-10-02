#!/usr/bin/env bash
# Sign a provenance or review document for one head commit, check the signature, and publish the
# bundle to the attestations branch under heads/<head>/.
#
#   scripts/sign.sh provenance|review PREDICATE_FILE HEAD_SHA SCENARIO_ID
#
# Runs inside a GitHub Actions job with `id-token: write`: cosign signs keyless with the job's
# OIDC identity, so the certificate names the workflow file that ran. The writer workflow and the
# reviewer workflow are different files, so their signer identities differ (scenario 10).
#
# Why cosign and not actions/attest: acc 0.6.0 binds a signed document to a change only through
# a `gitCommit` subject equal to the head commit, and actions/attest writes sha256 subjects only.
# The Statement here carries both: the gitCommit subject that acc binds, and the sha256 of the
# predicate file, which is what `gh attestation verify` needs to match an artifact on disk.
#
# Environment: ATTESTATIONS_TOKEN, a token that may push to the attestations branch
# (the job's GITHUB_TOKEN with contents: write).

source "$(dirname "$0")/lib.sh"
need cosign gh git jq yq

kind="${1:?usage: sign.sh provenance|review PREDICATE_FILE HEAD_SHA SCENARIO_ID}"
predicate="${2:?}"
head="${3:?}"
id="${4:?}"
case "$kind" in
  provenance) type="$PROVENANCE_TYPE" ;;
  review) type="$REVIEW_TYPE" ;;
  *) die "kind must be provenance or review" ;;
esac
[ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ] || die "sign.sh needs a GitHub Actions job with id-token: write"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
name="$kind.predicate.json"
# Canonical bytes (sorted keys, no whitespace), so the sha256 subject is reproducible from the
# published file.
jq -cS . "$predicate" | tr -d '\n' > "$work/$name"
digest="$(sha256sum "$work/$name" | cut -d' ' -f1)"
branch_name="$(item_json "$id" | jq -r .branch)"
number="$(pr_for_branch "$branch_name")"
# The subject name is informational; acc binds by the gitCommit digest. The writer signs before
# the pull request exists, so it names the branch.
subject="github:$REPO:${number:+pr:$number}"
[ -n "$number" ] || subject="github:$REPO:branch:$branch_name"

jq -n --arg subject "$subject" --arg head "$head" --arg name "$name" \
  --arg digest "$digest" --arg type "$type" --slurpfile predicate "$work/$name" '{
    _type: "https://in-toto.io/Statement/v1",
    subject: [
      {name: $subject, digest: {gitCommit: $head}},
      {name: $name, digest: {sha256: $digest}}
    ],
    predicateType: $type,
    predicate: $predicate[0]
  }' > "$work/statement.json"

# As in acc docs/signing.md ("Signing an authorship claim"): cosign signs the Statement as is.
cosign attest-blob --statement "$work/statement.json" --bundle "$work/$kind.sigstore.json" --yes -

# Check what was just signed the way every later reader will.
workflow="$(cfg ".evidence.signer_workflows.$kind")"
gh attestation verify "$work/$name" --bundle "$work/$kind.sigstore.json" \
  --repo "$REPO" --signer-workflow "$REPO/$workflow" --source-ref refs/heads/main \
  --predicate-type "$type" --deny-self-hosted-runners >/dev/null
echo "signed $kind for $head (verified against $workflow)"

# Publish next to anything already there for this head (the writer and reviewer each add one).
branch="$(cfg '.evidence.attestations_branch')"
remote="https://x-access-token:${ATTESTATIONS_TOKEN:?}@github.com/${REPO}.git"
git -C "$work" init --quiet store
cd "$work/store" || exit 1
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
if git ls-remote --exit-code --heads "$remote" "$branch" >/dev/null; then
  git fetch --quiet --depth 1 "$remote" "$branch"
  git checkout --quiet -b "$branch" FETCH_HEAD
else
  git checkout --quiet --orphan "$branch"
  printf '%s\n' "# Signed bundles" "" \
    "Sigstore bundles for scenario pull requests, by head commit. See the README on main." > README.md
fi
mkdir -p "heads/$head"
cp "$work/$name" "$work/$kind.sigstore.json" "heads/$head/"
[ -z "${EXTRA_FILE:-}" ] || cp "$EXTRA_FILE" "heads/$head/"
git add -A
git -c commit.gpgsign=false commit --quiet -m "Add $kind bundle for $head (scenario $id)"
for _ in 1 2 3; do
  if git push --quiet "$remote" "HEAD:$branch"; then
    echo "published heads/$head/$kind.sigstore.json on $branch"
    exit 0
  fi
  git fetch --quiet --depth 1 "$remote" "$branch"
  git rebase --quiet FETCH_HEAD
done
die "could not push to $branch"
