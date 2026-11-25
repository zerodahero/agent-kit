#!/usr/bin/env bash
# Prepares a release PR: sets every manifest to the new version and prepends its
# changelog entry from the commits since the last tag. Review CHANGELOG.md before you
# commit. Takes the version as 0.7.0 or v0.7.0.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "error: $*" >&2
  exit 1
}

version=${1:?usage: prepare-release.sh <version>}
version=${version#v}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "$version is not a semver version like 0.7.0."
grep -qF "## [$version]" CHANGELOG.md && fail "CHANGELOG.md already has a $version entry."

for manifest in package.json .claude-plugin/plugin.json plugins/plan-capture/.claude-plugin/plugin.json; do
  # Replace the first "version" value only, so the file keeps its layout. The JS template
  # literal is meant for node, not the shell.
  # shellcheck disable=SC2016
  VERSION=$version node -e '
    const fs = require("fs")
    const file = process.argv[1]
    const text = fs.readFileSync(file, "utf8")
    fs.writeFileSync(file, text.replace(/"version": "[^"]*"/, `"version": "${process.env.VERSION}"`))
  ' "$manifest"
done
scripts/check-versions.sh

git-cliff --unreleased --tag "v$version" --prepend CHANGELOG.md
rumdl fmt --quiet CHANGELOG.md

echo "Set $version in every manifest and added its CHANGELOG.md entry. Review the entry, then open the release PR."
