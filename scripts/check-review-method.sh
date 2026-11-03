#!/usr/bin/env bash
# The code-reviewer agent body and the second-review method are one text in two files.
# Fails when they differ.
set -euo pipefail
cd "$(dirname "$0")/.."

agent=agents/code-reviewer.md
method=skills/review/second-review/REVIEW-METHOD.md

# The agent body: everything after the closing frontmatter fence, minus the blank line.
body=$(awk 'n>=2 {print; next} /^---$/ {n++; next}' "$agent" | sed '1{/^$/d;}')
copy=$(cat "$method")

if [ "$body" != "$copy" ]; then
  line=$(awk 'NR==FNR {a[FNR]=$0; next} a[FNR]!=$0 {print FNR; exit}' \
    <(printf '%s\n' "$body") "$method" 2>/dev/null || true)
  echo "error: $method differs from the body of $agent${line:+ (first at method line $line)}. Edit both." >&2
  exit 1
fi
