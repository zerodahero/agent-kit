---
name: review
description: Review this branch with the code-reviewer agent, merge any second reviews, and triage the findings
argument-hint: "[git ref | plan path | plan number]"
disable-model-invocation: true
---

The **plan folder** is `.claude/plan/` at the repo's git top level. It holds plans, which
the `zerodahero-plan-capture` plugin writes when it is installed, and every review report.
When you write to it, create `.claude/plan/.gitignore` containing `*` if that file is
missing, so the folder never shows up in `git status`.

`<branch>` below is `git branch --show-current | tr / -`.

## Resolve the plan

`$ARGUMENTS` is any mix of a git ref, a plan reference, and empty. Resolve the plan in
this order and stop at the first that hits:

1. `$ARGUMENTS` names a path that exists. That is the plan.
2. `$ARGUMENTS` is a bare number. The plan is `.claude/plan/<number, zero-padded to
   three digits>.md`, matching how the plan-capture hook names its files.
3. `.claude/plan/current.md` exists. That is the plan.
4. A plan was approved in this session. That plan's file is the plan.
5. Nothing matched. There is no plan, and the agent reviews without one.

Say in one line which plan you used and how you found it. A `current.md` left over from
an earlier task is then visible rather than silent.

Whatever is left in `$ARGUMENTS` after the plan reference passes through as the diff
base. Where nothing is left, the agent resolves the base branch itself.

## Dispatch

Run the `zerodahero-skills:code-reviewer` agent on this branch. Hand it the resolved plan
path and the diff base.

**Do not print its report.** Hold it for the `Merged:` line below, then write it verbatim
to `.claude/plan/review-<branch>.md`.

The triage below is the only thing you render. Every finding appears exactly once.

## Collect second reviews

A **second review** is a report another harness or model wrote with the `second-review`
skill. It sits at `.claude/plan/second-review-<branch>-<reviewer>.md`. Its first line is
`Reviewer: <reviewer>`, and its header line carries `HEAD: <sha>`.

1. Glob `.claude/plan/second-review-<branch>-*.md`.
2. Read the `Merged:` line of the existing `.claude/plan/review-<branch>.md`, if any.
   Skip each second review whose reviewer and SHA already appear there. A reviewer that
   re-ran on a newer commit has a new SHA and merges again.
3. For each remaining second review, compare its SHA with HEAD. Where they differ, count
   `git rev-list --count <sha>..HEAD`. That review is **stale**, and each of its findings
   carries `(stale: <n> commits since)`. Locate a stale finding by its snippet rather than
   its line number, since the lines may have moved.
4. Add a line under the header of the report you write:
   `Merged: <reviewer>@<sha>, <reviewer>@<sha>`. Carry over the entries from the old
   `Merged:` line too, so a skipped review stays skipped next time.

Say in one line which second reviews you merged, which you skipped as already merged, and
which are stale. Where none exist, say nothing.

## Triage

Triage the agent's findings and every merged second-review finding as one set.

**Remove duplicates first.** Two findings are one when they name the same site and the
same defect. Keep the clearer wording, take the higher severity, and tag it `both`. A
finding only one reviewer raised is tagged `primary` or with its reviewer name.

Sort every finding into exactly one bucket.

| Bucket | Means |
| --- | --- |
| **Should fix** | In scope for the work, or adjacent to what this branch changed |
| **Could fix** | Just outside the scope, noticed because of the changes or the changed files |
| **Out of scope** | Genuinely separate work — a follow-up ticket or its own initiative |
| **Skip** | Not valid — a false positive, a misread, or a rule that does not apply here |

The reviewers tag each finding with its proximity to the diff. Map it, then adjust:

```
changed-line  → Should fix
changed-file  → Could fix
elsewhere     → Out of scope
```

You have context the reviewers lack: what this branch is for, what the user verified by
hand, which files they are still working in, what they said earlier in the session.
Move a finding between the first three buckets on that basis and say why in a clause.
Within a bucket, `both` findings sort first.

A second reviewer had none of this session's context. Check each of its findings against
the code before you bucket it.

**The Skip guard.** Move a finding to **Skip** only because it is *wrong*. A coding
standards, comment, or repo hygiene finding on `changed-line` or `changed-file` never
lands in Skip — not because the file is being rewritten anyway, not because it is minor,
not because it is Low. Those belong in **Should fix** or **Could fix**.

## Output

Read [TRIAGE-FORMAT.md](TRIAGE-FORMAT.md) before you render. It sets the verdict line,
the finding shape, the IDs, and the snippet rules.

## Out of scope follow-up

After the report, offer the three decisions for the **Out of scope** findings: pull one
into the current scope, open a ticket for it, or drop it.

Where the repo documents an issue tracker — `docs/agents/issue-tracker.md`,
`CONTRIBUTING.md`, or a tracker section in `CLAUDE.md` — a ticket follows that. Where
the repo documents none, ask which tracker before creating anything.

Offer only. Never create a ticket unless the user asks.
