#!/usr/bin/env bash
# Joins a human-review run's layer notes and its tuicr comments into findings.md.
#
# Usage: collect-findings.sh <run-dir> <repo-root> <base-sha> <head-sha> <status>
#
# <status> is the stage just completed, or "complete" after the final stage.
# No tuicr session for the range is normal before the Units layer. A failing tuicr
# command is an error: it is written into findings.md and the script exits 1.
set -euo pipefail

if [ "$#" -ne 5 ]; then
  echo "usage: collect-findings.sh <run-dir> <repo-root> <base-sha> <head-sha> <status>" >&2
  exit 2
fi

dir=$1
repo=$2
base=$3
head=$4
status=$5

out="$dir/findings.md"
tmp="$out.tmp"

if [ "$status" = "complete" ]; then
  status_line="Status: complete"
else
  status_line="Status: incomplete, last completed layer: $status"
fi

branch=$(jq -r '.branch // "unknown"' "$dir/meta.json" 2>/dev/null || echo unknown)

# tuicr names a session after the commits it shows, so match on the commit list.
expected=$(git -C "$repo" rev-list "$base..$head" | sort | jq -R . | jq -sc .)

tuicr_error=""
comments=""
if ! sessions=$(tuicr review list --repo "$repo" 2>&1); then
  tuicr_error="tuicr review list failed: $sessions"
else
  session=""
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if jq -e --argjson want "$expected" '(.commit_range // []) | sort == $want' "$path" >/dev/null 2>&1; then
      session=$path
      break
    fi
  done < <(printf '%s' "$sessions" | jq -r '.[].path')

  if [ -n "$session" ]; then
    if ! raw=$(tuicr review comments --session "$session" 2>&1); then
      tuicr_error="tuicr review comments failed: $raw"
    elif ! comments=$(printf '%s' "$raw" | jq -r '
      .[] | "- " + (if .location then "`" + .location + "`" + (if .side == "old" then " (base)" else "" end) else "review" end)
        + ": " + (.content | gsub("\n"; "\n  "))' 2>&1); then
      tuicr_error="could not read tuicr comments: $comments"
      comments=""
    fi
  fi
fi

{
  echo "# Findings: $branch"
  echo
  echo "Range: \`${base:0:7}..${head:0:7}\` ($base..$head)"
  echo
  echo "$status_line"
  echo
  echo "## Layer notes"
  found=0
  for note in "$dir"/notes/*.md; do
    [ -e "$note" ] || continue
    [ -s "$note" ] || continue
    found=1
    name=$(basename "$note" .md)
    echo
    echo "### $name"
    echo
    cat "$note"
  done
  if [ "$found" -eq 0 ]; then
    echo
    echo "No notes yet."
  fi
  echo
  echo "## tuicr comments"
  echo
  if [ -n "$tuicr_error" ]; then
    echo "Error: $tuicr_error"
  elif [ -z "$comments" ]; then
    echo "Comments: none yet"
  else
    echo "$comments"
  fi
} >"$tmp"
mv "$tmp" "$out"

if [ -n "$tuicr_error" ]; then
  echo "$tuicr_error" >&2
  exit 1
fi
echo "findings written to $out"
