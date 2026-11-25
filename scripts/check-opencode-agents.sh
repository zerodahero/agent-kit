#!/usr/bin/env bash
# The opencode reviewer agents share one read-only shell policy. Fails when an agent uses
# the V1 permission map, does not deny everything first, or has shell rules the other
# agent lacks, apart from the extras listed below.
set -euo pipefail
cd "$(dirname "$0")/.."

agents=(opencode/agents/plan-reviewer.md opencode/agents/second-reviewer.md)

# Shell rules only one agent needs, as "<agent file> <effect> <resource>".
extras=(
  # Finds the default branch when the review base is not given.
  "opencode/agents/second-reviewer.md allow git symbolic-ref*"
  # Creates .claude/plan/ before the first report.
  "opencode/agents/second-reviewer.md allow mkdir -p .claude/plan*"
)

failed=0
fail() {
  echo "error: $*" >&2
  failed=1
}

frontmatter() {
  awk '/^---$/ {n++; next} n == 1' "$1"
}

# The agent's shell rules as "<effect> <resource>", sorted, minus its extras.
shell_rules() {
  local agent=$1 rule extra
  frontmatter "$agent" \
    | sed -nE 's/^ *- *\{ *action: *"?shell"?, *resource: *"([^"]*)", *effect: *([a-z]+) *\}.*/\2 \1/p' \
    | sort \
    | while IFS= read -r rule; do
      for extra in "${extras[@]}"; do
        [ "$extra" = "$agent $rule" ] && continue 2
      done
      printf '%s\n' "$rule"
    done
}

for agent in "${agents[@]}"; do
  if frontmatter "$agent" | grep -q '^permission:'; then
    fail "$agent uses the V1 permission map. Use the V2 permissions list, as the other agent does."
  fi
  first=$(frontmatter "$agent" | grep -m1 -E '^ *- *\{' || true)
  if ! grep -qE '^ *- *\{ *action: *"\*", *resource: *"\*", *effect: *deny *\}' <<<"$first"; then
    fail "$agent must start its permissions with { action: \"*\", resource: \"*\", effect: deny }."
  fi
done

a=${agents[0]} b=${agents[1]}
while IFS= read -r rule; do
  [ -n "$rule" ] && fail "shell rule \"$rule\" is in $a but not $b. Add it to both, or list it in extras in $0."
done < <(comm -23 <(shell_rules "$a") <(shell_rules "$b"))
while IFS= read -r rule; do
  [ -n "$rule" ] && fail "shell rule \"$rule\" is in $b but not $a. Add it to both, or list it in extras in $0."
done < <(comm -13 <(shell_rules "$a") <(shell_rules "$b"))

exit "$failed"
