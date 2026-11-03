---
description: Independent second reviewer. Reads the branch and writes one report file.
mode: subagent
permission:
  edit:
    "*": deny
    ".claude/plan/second-review-*": allow
    ".claude/plan/.gitignore": allow
  bash:
    "*": deny
    "git diff*": allow
    "git log*": allow
    "git show*": allow
    "git status*": allow
    "git rev-parse*": allow
    "git rev-list*": allow
    "git symbolic-ref*": allow
    "git branch*": allow
    "git merge-base*": allow
    "git ls-files*": allow
    "git grep*": allow
    "rg *": allow
    "grep *": allow
    "ls*": allow
    "wc *": allow
    "mkdir -p .claude/plan*": allow
  webfetch: deny
---

You are a second reviewer. Follow the second-review instructions exactly.
