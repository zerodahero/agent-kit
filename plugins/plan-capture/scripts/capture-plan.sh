#!/usr/bin/env bash
# PreToolUse hook on ExitPlanMode: copies the plan into <repo>/.claude/plan/NNN.md and
# current.md. Always exits 0, so a failure here never blocks a plan.
set -uo pipefail

payload=$(cat)
plan=$(jq -r '.tool_input.plan // empty' <<<"$payload" 2>/dev/null) || exit 0
[ -n "$plan" ] || exit 0

cwd=$(jq -r '.cwd // empty' <<<"$payload")
[ -n "$cwd" ] || cwd=$PWD
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root=$cwd
dir="$root/.claude/plan"
mkdir -p "$dir" || exit 0
[ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore"

# Highest existing number plus one, so a deleted file never causes an overwrite.
last=0
for f in "$dir"/[0-9][0-9][0-9].md; do
  [ -e "$f" ] || continue
  n=$(basename "$f" .md)
  n=$((10#$n))
  [ "$n" -gt "$last" ] && last=$n
done
file=$(printf '%s/%03d.md' "$dir" $((last + 1)))

printf '%s\n' "$plan" > "$file" && cp "$file" "$dir/current.md"
exit 0
