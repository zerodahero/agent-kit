#!/usr/bin/env bash
# Every shipped skill is in the plugin's skills list, every list entry is a skill, and
# every skill directory, drafts included, has agents/openai.yaml with a display name and
# a short description under 60 characters. Reports every failure, then exits 1.
set -euo pipefail
cd "$(dirname "$0")/.."

manifest=.claude-plugin/plugin.json
failed=0

fail() {
  echo "error: $*" >&2
  failed=1
}

# The value of one key under interface: in an openai.yaml, without surrounding quotes.
field() {
  awk -v key="$2" '
    /^[^[:space:]#]/ { in_interface = ($0 ~ /^interface:[[:space:]]*$/); next }
    in_interface && $0 ~ "^[[:space:]]+" key ":" {
      sub("^[[:space:]]+" key ":[[:space:]]*", "")
      sub(/[[:space:]]+$/, "")
      if ($0 ~ /^".*"$/ || $0 ~ /^'\''.*'\''$/) $0 = substr($0, 2, length($0) - 2)
      print
      exit
    }
  ' "$1"
}

# The skills list, as paths without the leading ./ or a trailing slash.
listed=$(node -p "require('./$manifest').skills.map(s => s.replace(/^\.\//, '').replace(/\/$/, '')).join('\n')")

while IFS= read -r entry; do
  [ -f "$entry/SKILL.md" ] \
    || fail "$manifest lists $entry, which has no SKILL.md. Remove the entry or add the skill."
done <<<"$listed"

while IFS= read -r skill_md; do
  dir=${skill_md%/SKILL.md}

  case $dir in
  skills/drafts/*) ;;
  *)
    grep -qxF "$dir" <<<"$listed" \
      || fail "$dir is not in the skills list of $manifest. Add \"./$dir\", or move the skill to skills/drafts/."
    ;;
  esac

  yaml=$dir/agents/openai.yaml
  if [ ! -f "$yaml" ]; then
    fail "$yaml is missing. Add it with interface.display_name and interface.short_description."
    continue
  fi

  [ -n "$(field "$yaml" display_name)" ] || fail "$yaml has no interface.display_name."

  short=$(field "$yaml" short_description)
  if [ -z "$short" ]; then
    fail "$yaml has no interface.short_description."
  elif [ "${#short}" -ge 60 ]; then
    fail "$yaml has a short_description of ${#short} characters. Shorten it to under 60."
  fi
done < <(find skills -name SKILL.md | sort)

exit "$failed"
