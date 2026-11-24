#!/usr/bin/env bash
# Runs one attempt of one plan-review round. Freezes the plan as the round input, builds
# the reviewer's prompt, runs the plan-reviewer agent in opencode, and scans its events
# for denied tool calls.
#
# Usage: run-round.sh <slug> <round> <plan> [provider/model] < instructions
#
# stdin carries the author's instructions: the anchor version, the ledger, the key map.
# Each `Attach: <path>` line in them attaches that file, so the reviewer can read a
# reference outside the repo.
# Exit codes: 0 the attempt ran clean; 1 opencode failed; 2 bad input; 3 a tool was
# denied, and the report must account for each denied call it printed.
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

slug=${1:?usage: run-round.sh <slug> <round> <plan> [provider/model] < instructions}
round=${2:?missing round}
plan=${3:?missing plan path}
model=${4:-}

[[ $slug =~ ^[A-Za-z0-9._-]+$ ]] || fail "slug '$slug' must be letters, digits, '.', '_' or '-'."
[[ $round =~ ^[1-9][0-9]*$ ]] || fail "round '$round' must be a positive integer."
[ -f "$plan" ] || fail "no plan at $plan."
command -v opencode >/dev/null || fail "opencode is not on PATH."
command -v jq >/dev/null || fail "jq is not on PATH."

# opencode writes its log under its data dir. The Claude Code sandbox denies that write,
# and opencode fails only after its startup, so check before spending an attempt.
logdir="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/log"
probe="$logdir/.plan-review-probe"
if ! { mkdir -p "$logdir" && touch "$probe" && rm -f "$probe"; } 2>/dev/null; then
  fail "cannot write $logdir. Run this script with the sandbox disabled."
fi

skill_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
top=$(git rev-parse --show-toplevel 2>/dev/null) || fail "run this inside a git repo."
dir="$top/.claude/plan"
refuse_links "$top/.claude" "$dir" "$dir/.gitignore"
mkdir -p "$dir"
[ -f "$dir/.gitignore" ] || echo '*' >"$dir/.gitignore"

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

# The round input is frozen on the first attempt. A retry reuses it, and a plan that
# changed mid-round is refused: the author revises only after a round succeeds.
input="$dir/plan-input-$slug-r$round.md"
prev="$dir/plan-input-$slug-r$((round - 1)).md"
if [ "$round" -gt 1 ] && [ ! -f "$prev" ]; then
  fail "round $round needs the round $((round - 1)) input at $prev."
fi
refuse_links "$input"
if [ -f "$input" ]; then
  [ "$(sha "$plan")" = "$(sha "$input")" ] \
    || fail "the plan changed since round $round's input was frozen. Finish or abandon round $round first, or, for a different plan, pick a new slug."
else
  cp "$plan" "$input"
  chmod a-w "$input"
fi
hash=$(sha "$input")

# Each attempt gets its own report path, so an earlier attempt's report never counts.
attempt=1
while [ -e "$dir/plan-review-$slug-r$round-a$attempt.md" ] \
  || [ -e "$dir/plan-events-$slug-r$round-a$attempt.jsonl" ] \
  || [ -e "$dir/plan-prompt-$slug-r$round-a$attempt.md" ]; do
  attempt=$((attempt + 1))
done
# The reviewer may edit only plan-review-*, so the event log and prompt sit outside it.
report="$dir/plan-review-$slug-r$round-a$attempt.md"
events="$dir/plan-events-$slug-r$round-a$attempt.jsonl"
prompt_file="$dir/plan-prompt-$slug-r$round-a$attempt.md"
report_rel=${report#"$top"/}
refuse_links "$report" "$events" "$prompt_file"

# opencode session IDs must start with "ses". One session per plan in this repo.
session="ses_planreview_$(printf '%s:%s' "$top" "$slug" | shasum -a 256 | cut -c1-20)"
reviewer="opencode${model:+-${model##*/}}"

instructions=$(cat)

attachments=()
while IFS= read -r path; do
  path=${path/#\~/$HOME}
  [ -f "$path" ] || fail "Attach: no file at $path."
  attachments+=(--file "$path")
done < <(printf '%s\n' "$instructions" | sed -n 's/^Attach:[[:space:]]*//p')

# The prompt travels as an attachment: a long diff or ledger would overflow argv.
{
  echo "Plan review, round $round."
  echo
  echo "- Report path: $report_rel"
  echo "- Reviewer name: $reviewer"
  echo "- Plan slug: $slug"
  echo "- Round input sha256: $hash"
  echo "- The attached round input is the plan for this round."
  if [ "$round" -eq 1 ]; then
    echo "- PLAN-REVIEW-METHOD.md is attached. Follow it in every round. LEDGER-FORMAT.md is attached for reference: it is how the author records your findings."
  fi
  if [ "$round" -gt 1 ]; then
    echo
    echo "## Diff since round $((round - 1))"
    echo
    echo '```diff'
    diff -u --label "round $((round - 1))" --label "round $round" "$prev" "$input" || true
    echo '```'
  fi
  echo
  echo "## From the author"
  echo
  printf '%s\n' "$instructions"
} >"$prompt_file"

args=(run --agent plan-reviewer --session "$session" --title "plan-review $slug" --format json
  --file "$prompt_file" --file "$input")
[ -n "$model" ] && args+=(--model "$model")
# The method rides along until a round has succeeded: round 1 only, on every attempt.
if [ "$round" -eq 1 ]; then
  args+=(--file "$skill_dir/PLAN-REVIEW-METHOD.md" --file "$skill_dir/LEDGER-FORMAT.md")
fi
if [ "${#attachments[@]}" -gt 0 ]; then
  args+=("${attachments[@]}")
fi

# A deadline on every run: timeout where it exists, perl's alarm otherwise.
limit=${PLAN_REVIEW_TIMEOUT:-1800}
if command -v timeout >/dev/null; then
  runner=(timeout "$limit")
else
  runner=(perl -e 'alarm shift; exec @ARGV or die "exec: $!"' "$limit")
fi

message="Plan review, round $round. The attached plan-prompt file is this round's instructions. Follow it."
status=0
"${runner[@]}" opencode "${args[@]}" "$message" >"$events" || status=$?
chmod a-w "$prompt_file" "$events"
[ -f "$report" ] && chmod a-w "$report"

# A denied call comes back to the model as a tool error, and opencode still exits 0.
denied=$(jq -r 'select(.type == "tool_use" and .part.state.status == "error")
  | select((.part.state.error // "") | test("Permission denied|Blocked by configuration policy"))
  | "\(.part.tool): \(.part.state.input.command // .part.state.input.path // .part.state.input | tostring)"' "$events") || {
  echo "result: failed (opencode's event log does not parse)"
  exit 1
}
denials=$(printf '%s' "$denied" | grep -c . || true)
# jq picks the lines itself: a `| head` would close the pipe early, and pipefail would
# end the script before it prints a result.
errors=$(jq -rn '[inputs | select(.type == "error") | .error.message // "unknown"] | .[:3][]' "$events") || {
  echo "result: failed (opencode's event log does not parse)"
  exit 1
}

echo "report: $report_rel"
echo "input: ${input#"$top"/} sha256:$hash"
echo "session: $session"
echo "attempt: $attempt"
echo "denials: $denials"
[ -n "$denied" ] && printf '  denied %s\n' "$denied"
[ -n "$errors" ] && echo "opencode errors: $errors"

if [ "$status" -ne 0 ] || [ -n "$errors" ]; then
  echo "result: failed (opencode exit $status)"
  exit 1
fi
if [ "$denials" -gt 0 ]; then
  echo "result: failed ($denials denied tool calls; see ${events#"$top"/})"
  exit 3
fi
echo "result: ran"
