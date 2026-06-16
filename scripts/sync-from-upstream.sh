#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
manifest_path="$repo_root/nix/package-manifest.json"
tmpdir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

require git
require jq
require rsync

homepage="$(jq -r '.meta.homepage' "$manifest_path")"
default_branch="$(jq -r '.source.defaultBranch // "main"' "$manifest_path")"

if [[ ! "$homepage" =~ ^https://github\.com/([^/]+)/([^/#]+) ]]; then
  echo "failed to parse GitHub owner/repo from homepage: $homepage" >&2
  exit 1
fi

owner="${BASH_REMATCH[1]}"
repo="${BASH_REMATCH[2]}"
source_repo="${1:-https://github.com/$owner/$repo.git}"
source_ref="${2:-$default_branch}"
upstream_dir="$tmpdir/upstream"

echo "syncing $source_repo @ $source_ref"
git clone --depth 1 --branch "$source_ref" "$source_repo" "$upstream_dir" >/dev/null 2>&1
rev="$(git -C "$upstream_dir" rev-parse HEAD)"
version="$(sed -n 's/^version = "\([^"]*\)"/\1/p' "$upstream_dir/Cargo.toml" | head -n 1)"

if [[ -z "$version" ]]; then
  echo "failed to determine version from $upstream_dir/Cargo.toml" >&2
  exit 1
fi

rm -rf "$repo_root/upstream"
mkdir -p "$repo_root/upstream"
rsync -a --delete --exclude '.git' "$upstream_dir/" "$repo_root/upstream/"

jq \
  --arg version "$version" \
  --arg rev "$rev" \
  --arg branch "$source_ref" \
  '.source.path = "upstream"
   | .source.channel = "github-head"
   | .source.defaultBranch = $branch
   | .source.version = $version
   | .source.rev = $rev
   | .package.version = $version' \
  "$manifest_path" > "$manifest_path.tmp"
mv "$manifest_path.tmp" "$manifest_path"

echo "updated:"
echo "  source:   $source_repo"
echo "  ref:      $source_ref"
echo "  rev:      $rev"
echo "  version:  $version"
