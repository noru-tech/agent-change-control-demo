#!/usr/bin/env bash
# Install the acc release pinned in scenarios.yml into DIR and print DIR, for workflows that run
# the CLI directly (the change-control workflow uses the action, which installs it the same way).
#
#   scripts/install-acc.sh DIR
#
# Checks the archive's SHA-256 file and its GitHub artifact attestation before unpacking, as acc's
# README ("Verify before you run") describes. Linux runners only.

source "$(dirname "$0")/lib.sh"
need gh curl tar

dir="${1:?usage: install-acc.sh DIR}"
version="$(cfg '.acc.version')"
case "$(uname -m)" in
  x86_64) target=x86_64-unknown-linux-musl ;;
  aarch64) target=aarch64-unknown-linux-musl ;;
  *) die "unsupported machine $(uname -m)" ;;
esac
archive="agent-change-control-$target.tar.xz"
mkdir -p "$dir"
cd "$dir" || exit 1
gh release download "v$version" --repo noru-tech/agent-change-control --clobber \
  --pattern "$archive" --pattern "$archive.sha256" >&2
sha256sum -c "$archive.sha256" >&2
gh attestation verify "$archive" --repo noru-tech/agent-change-control \
  --signer-workflow noru-tech/agent-change-control/.github/workflows/release.yml >&2
tar -xJf "$archive"
"$dir/agent-change-control-$target/acc" --version >&2
echo "$dir/agent-change-control-$target"
