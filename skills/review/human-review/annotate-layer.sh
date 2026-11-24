#!/usr/bin/env bash
# Opens one human-review layer doc in Plannotator and saves the reviewer's annotations
# as that layer's notes.
#
# Usage: annotate-layer.sh <doc> <notes-file> <title>
#
# Approve with no annotations leaves the notes file as it is. Annotations replace it.
# Any reviewer decision exits 0; the korin gate is where a review stops early.
# A session that fails to start, or output that is not a decision, exits 1.
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: annotate-layer.sh <doc> <notes-file> <title>" >&2
  exit 2
fi

doc=$1
notes=$2
title=$3

out=$(plannotator annotate "$doc" --gate --json --title "$title") || {
  status=$?
  echo "plannotator exited $status: $out" >&2
  exit 1
}

if ! decision=$(printf '%s' "$out" | jq -er '.decision' 2>/dev/null); then
  echo "plannotator returned no decision: $out" >&2
  exit 1
fi

feedback=$(printf '%s' "$out" | jq -r '.feedback // ""')
if [ -n "$feedback" ]; then
  mkdir -p "$(dirname "$notes")"
  printf '%s\n' "$feedback" >"$notes"
  echo "$decision; notes saved to $notes"
else
  echo "$decision; no notes"
fi
