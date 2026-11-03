#!/usr/bin/env bash
# Tags and pushes a zerodahero-skills release. The tag starts release.yml, which publishes
# the opencode plugin to npm. Takes the version as 0.2.2, v0.2.2, or the full tag.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "error: $*" >&2
  exit 1
}

version=${1:?usage: release.sh <version>}
version=${version#zerodahero-skills--}
version=${version#v}
tag="zerodahero-skills--v$version"
package=$(node -p 'require("./package.json").name')

[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "$version is not a semver version like 0.2.2."

# The tag goes on what main holds on GitHub, so the release matches what merged.
[ "$(git branch --show-current)" = main ] || fail "check out main first."
[ -z "$(git status --porcelain)" ] || fail "the working tree has uncommitted changes."
git fetch --quiet origin main --tags
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] \
  || fail "main differs from origin/main. Run git pull --ff-only."

# The version bump lands through a PR, so both manifests must already carry it.
scripts/check-versions.sh
current=$(node -p 'require("./package.json").version')
[ "$current" = "$version" ] \
  || fail "the manifests are at $current, not $version. Merge a version bump first."

# A version ships once: no existing tag, local or remote, and nothing on npm.
if git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
  fail "tag $tag already exists."
fi
if [ -n "$(git ls-remote --tags origin "refs/tags/$tag")" ]; then
  fail "tag $tag already exists on origin."
fi
if npm view "$package@$version" version >/dev/null 2>&1; then
  fail "$package@$version is already on npm, and npm never republishes a version."
fi

git tag -a "$tag" -m "zerodahero-skills $version"
git push origin "$tag"
echo "Pushed $tag. Watch the publish with: gh run watch"
