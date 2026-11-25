#!/usr/bin/env bash
# Both plugins and the opencode package release together at one version.
# Fails when any of their versions differ.
set -euo pipefail
cd "$(dirname "$0")/.."

manifests=(
  package.json
  .claude-plugin/plugin.json
  plugins/plan-capture/.claude-plugin/plugin.json
)

expected=$(node -p "require('./${manifests[0]}').version")
failed=0
for manifest in "${manifests[@]:1}"; do
  version=$(node -p "require('./$manifest').version")
  if [ "$version" != "$expected" ]; then
    echo "error: $manifest is $version but ${manifests[0]} is $expected. Set every manifest to one version." >&2
    failed=1
  fi
done
exit "$failed"
