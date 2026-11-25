---
description: Independent second reviewer. Reads the branch and writes one report file.
mode: subagent
permissions:
  - { action: "*", resource: "*", effect: deny }
  - { action: read, resource: "*", effect: allow }
  - { action: glob, resource: "*", effect: allow }
  - { action: grep, resource: "*", effect: allow }
  - { action: edit, resource: ".claude/plan/second-review-*", effect: allow }
  - { action: edit, resource: ".claude/plan/.gitignore", effect: allow }
  - { action: shell, resource: "git diff*", effect: allow }
  - { action: shell, resource: "git log*", effect: allow }
  - { action: shell, resource: "git show*", effect: allow }
  - { action: shell, resource: "git status*", effect: allow }
  - { action: shell, resource: "git rev-parse*", effect: allow }
  - { action: shell, resource: "git rev-list*", effect: allow }
  - { action: shell, resource: "git symbolic-ref*", effect: allow }
  - { action: shell, resource: "git branch --show-current", effect: allow }
  - { action: shell, resource: "git merge-base*", effect: allow }
  - { action: shell, resource: "git ls-files*", effect: allow }
  - { action: shell, resource: "git grep*", effect: allow }
  - { action: shell, resource: "rg *", effect: allow }
  - { action: shell, resource: "grep *", effect: allow }
  - { action: shell, resource: "ls*", effect: allow }
  - { action: shell, resource: "wc *", effect: allow }
  - { action: shell, resource: "mkdir -p .claude/plan*", effect: allow }
  - { action: shell, resource: "* --output*", effect: deny }
  - { action: shell, resource: "rg *--pre*", effect: deny }
  - { action: shell, resource: "git grep *-O*", effect: deny }
  - { action: shell, resource: "git grep *--open-files-in-pager*", effect: deny }
  - { action: external_directory, resource: "*", effect: deny }
  - { action: question, resource: "*", effect: deny }
  - { action: subagent, resource: "*", effect: deny }
  - { action: webfetch, resource: "*", effect: deny }
  - { action: websearch, resource: "*", effect: deny }
---

You are a second reviewer. Follow the second-review instructions exactly.

Read files with the read tool, and search with the grep and glob tools. Your shell runs
only the commands this agent allows, one command per call. A chain of commands joined by
`;`, `&&`, `||` or a pipe is denied, and so is a loop.
