---
name: second-review
description: Review this branch as an independent second reviewer and write the findings to a file for the primary agent
argument-hint: "[reviewer name] [git ref] [plan path]"
disable-model-invocation: true
---

You are a **second reviewer**. Another agent made the changes on this branch and has
already run the tests, linters, and builds. Your job is an independent read of the diff,
written to one report file that the primary agent merges into its own review.

The report file is the only file you write. Your tools are reading files, searching, and
read-only `git`. Form your view from the code alone: the primary agent's reports in
`.claude/plan/review-*.md` and other reviewers' `second-review-*` files stay unread, so
your read stays independent.

## 1. Name yourself

The **reviewer name** is the first word of `$ARGUMENTS` when it is not a git ref or a
path. Otherwise it is `<harness>-<model>` in lowercase, with spaces and dots as `-`:
`opencode-gpt-5`, `codex-o4-mini`, `claude-code-sonnet-4-5`.

## 2. Resolve the plan

Use the first that hits:

1. `$ARGUMENTS` names a path that exists. That is the plan.
2. `.claude/plan/current.md` exists. That is the plan.
3. Nothing matched. There is no plan.

What is left in `$ARGUMENTS` is the diff base.

## 3. Review

Read [REVIEW-METHOD.md](REVIEW-METHOD.md) and follow it in full. You are the reviewer it
addresses, and the plan and diff base above are what the caller hands you. This step is
done when every lens and every blast-radius row in the method has a finding or a one-line
note.

## 4. Write the report

Write the report to `.claude/plan/second-review-<branch>-<reviewer name>.md` at the git
top level, where `<branch>` is `git branch --show-current | tr / -`. Overwrite any earlier
report of your own. Create `.claude/plan/.gitignore` containing `*` when it is missing.

The report is the method's report, with one line above it:

```markdown
Reviewer: opencode-gpt-5
```

The method's header line carries the HEAD SHA. The primary agent uses that SHA to tell a
current review from a stale one, so take it from `git rev-parse --short HEAD`.

Where the harness refuses the write, print the full report in chat instead, and say in one
line that the write failed.

## 5. Tell the user

Print three lines, and nothing more of the report:

1. The report's verdict line.
2. The severity counts: `🔴 1 · 🟡 3 · 🔵 2`.
3. `Report: .claude/plan/second-review-<branch>-<reviewer name>.md. Run /review in the primary session to merge it.`
