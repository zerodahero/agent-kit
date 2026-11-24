#!/usr/bin/env bash
# Runs the opencode second review of this branch in a fresh session, for /review second.
# Attaches the second-review skill files, waits for the report, and scans opencode's
# events for denied tool calls.
#
# Usage: run-second.sh <reviewer> [--model provider/model] [--base ref] [--plan path]
#
# Exit codes: 0 the report is in and matches HEAD; 1 opencode failed or wrote no current
# report; 2 bad input or the sandbox is on; 3 the report is in, but a tool was denied.
set -euo pipefail

fail() {
  echo "error: $*" >&2
  exit 2
}

# This script runs outside the sandbox, so it refuses to write through a symlink a
# checkout could plant.
refuse_links() {
  local f
  for f in "$@"; do
    [ ! -L "$f" ] || fail "$f is a symlink. Refusing to write through it."
  done
}

usage="usage: run-second.sh <reviewer> [--model provider/model] [--base ref] [--plan path]"
reviewer=${1:?$usage}
shift
model='' base='' plan=''
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] && [ -n "$2" ] || fail "$usage"
  case $1 in
  --model) model=$2 ;;
  --base) base=$2 ;;
  --plan) plan=$2 ;;
  *) fail "$usage" ;;
  esac
  shift 2
done

[[ $reviewer =~ ^[A-Za-z0-9._-]+$ ]] || fail "reviewer '$reviewer' must be letters, digits, '.', '_' or '-'."
command -v opencode >/dev/null || fail "opencode is not on PATH."
command -v jq >/dev/null || fail "jq is not on PATH."

# opencode writes its log under its data dir. The Claude Code sandbox denies that write,
# and opencode fails only after its startup, so check first.
logdir="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/log"
probe="$logdir/.second-review-probe"
if ! { mkdir -p "$logdir" && touch "$probe" && rm -f "$probe"; } 2>/dev/null; then
  fail "cannot write $logdir. Run this script with the sandbox disabled."
fi

skill_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
second_dir="$skill_dir/../second-review"
[ -f "$second_dir/SKILL.md" ] && [ -f "$second_dir/REVIEW-METHOD.md" ] \
  || fail "no second-review skill files beside this skill, at $second_dir."

top=$(git rev-parse --show-toplevel 2>/dev/null) || fail "run this inside a git repo."
branch=$(git branch --show-current | tr / -)
[ -n "$branch" ] || fail "HEAD is detached. Check out a branch first."
head=$(git rev-parse --short HEAD)

dir="$top/.claude/plan"
refuse_links "$top/.claude" "$dir" "$dir/.gitignore"
mkdir -p "$dir"
[ -f "$dir/.gitignore" ] || echo '*' >"$dir/.gitignore"

# An earlier report at this path must never pass for this run's. Its name keeps it out of
# the second-review-* glob that /review reads.
report="$dir/second-review-$branch-$reviewer.md"
events="$dir/second-events-$branch-$reviewer.jsonl"
refuse_links "$report" "$events" "$dir/prev-second-review-$branch-$reviewer.md" \
  "$dir/failed-second-review-$branch-$reviewer.md"
[ -f "$report" ] && mv -f "$report" "$dir/prev-second-review-$branch-$reviewer.md"

args=(run --agent second-reviewer --title "second-review $branch" --format json
  --file "$second_dir/SKILL.md" --file "$second_dir/REVIEW-METHOD.md")
[ -n "$model" ] && args+=(--model "$model")

arguments="$reviewer${base:+ $base}${plan:+ $plan}"
message="Run the attached second-review SKILL.md as written. Its \$ARGUMENTS are: $arguments. Its link to REVIEW-METHOD.md means the attached REVIEW-METHOD.md."

# A deadline on every run: timeout where it exists, perl's alarm otherwise.
limit=${SECOND_REVIEW_TIMEOUT:-1800}
if command -v timeout >/dev/null; then
  runner=(timeout "$limit")
else
  runner=(perl -e 'alarm shift; exec @ARGV or die "exec: $!"' "$limit")
fi

status=0
(cd "$top" && "${runner[@]}" opencode "${args[@]}" "$message") >"$events" || status=$?

# A failed run's report moves out of the second-review-* glob, so no later /review
# takes it.
failed() {
  [ -f "$report" ] && mv -f "$report" "$dir/failed-second-review-$branch-$reviewer.md"
  echo "result: failed ($1)"
  exit 1
}

# A denied call comes back to the model as a tool error, and opencode still exits 0.
denied=$(jq -r 'select(.type == "tool_use" and .part.state.status == "error")
  | select((.part.state.error // "") | test("Permission denied|Blocked by configuration policy"))
  | "\(.part.tool): \(.part.state.input.command // .part.state.input.path // .part.state.input | tostring)"' "$events") \
  || failed "opencode's event log does not parse"
denials=$(printf '%s' "$denied" | grep -c . || true)
# jq picks the lines itself: a `| head` would close the pipe early, and pipefail would
# end the script before it prints a result.
errors=$(jq -rn '[inputs | select(.type == "error") | .error.message // "unknown"] | .[:3][]' "$events") \
  || failed "opencode's event log does not parse"
session=$(jq -rn 'first(inputs | .sessionID // empty)' "$events") || session=unknown

echo "report: ${report#"$top"/}"
echo "session: ${session:-unknown}"
echo "head: $head"
echo "denials: $denials"
[ -n "$denied" ] && printf '  denied %s\n' "$denied"
[ -n "$errors" ] && echo "opencode errors: $errors"

[ "$status" -eq 0 ] && [ -z "$errors" ] || failed "opencode exit $status"
[ -f "$report" ] || failed "no report written"
# The method's header line: `Range: … · HEAD: <sha> · Plan: …`.
grep -Eq "^Range: .* · HEAD: $head( ·|$)" "$report" || failed "the report's header does not say HEAD: $head"
if [ "$denials" -gt 0 ]; then
  echo "result: ran with $denials denied tool calls; see ${events#"$top"/}"
  exit 3
fi
echo "result: ran"
