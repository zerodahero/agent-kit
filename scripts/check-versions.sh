#!/usr/bin/env bash
# The opencode package and the Claude Code plugin release together.
# Fails when their versions differ.
set -euo pipefail
cd "$(dirname "$0")/.."

plugin=$(node -p 'require("./.claude-plugin/plugin.json").version')
package=$(node -p 'require("./package.json").version')

if [ "$plugin" != "$package" ]; then
  echo "error: .claude-plugin/plugin.json is $plugin but package.json is $package." >&2
  exit 1
fi
