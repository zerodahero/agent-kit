---
name: review
description: Review this branch with the code-reviewer agent, or triage a second review of it, and sort the findings
argument-hint: "[full] [git ref | plan path | plan number]"
disable-model-invocation: true
---

The **plan folder** is `.claude/plan/` at the repo's git top level. It holds plans, which
the `zerodahero-plan-capture` plugin writes when it is installed, and every review report.
When you write to it, create `.claude/plan/.gitignore` containing `*` if that file is
missing, so the folder never shows up in `git status`.

`<branch>` below is `git branch --show-current | tr / -`.

A **second review** is a report another harness or model wrote with the `second-review`
skill. It sits at `.claude/plan/second-review-<branch>-<reviewer>.md`. Its first line is
`Reviewer: <reviewer>`, and its header line carries `HEAD: <sha>`. A second review is
**triaged** once its `<reviewer>@<sha>` appears on the `Merged:` line of
`.claude/plan/review-<branch>.md`.

## Resolve the plan

Where `$ARGUMENTS` starts with the word `full`, set it aside for the mode below. The rest of
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

## Choose the mode

Glob `.claude/plan/second-review-<branch>-*.md`, and set aside every second review already
triaged. For each one left, compare its SHA with HEAD. Where they differ, the review is
**stale** by `git rev-list --count <sha>..HEAD` commits.

| Found | Mode |
| --- | --- |
| `full` in `$ARGUMENTS` | **Full**, merging every untriaged second review |
| No untriaged second review | **Full** |
| Untriaged second reviews, none stale | **Second only** |
| An untriaged second review that is stale | Ask with `AskUserQuestion`: triage the second reviews alone, marked stale (recommended), or run a full review that merges them |

Say the mode in one line, with each second review you take and whether it is current or
stale. A second review usually arrives after the primary review's findings are fixed, so
**Second only** never reruns the primary reviewer on code just reviewed.

## Full: dispatch

Run the `zerodahero-skills:code-reviewer` agent on this branch. Hand it the resolved plan
path and the diff base.

**Do not print its report.** Write it verbatim to `.claude/plan/review-<branch>.md`, with a
`Merged:` line under its header. That line lists every second review this run takes as
`<reviewer>@<sha>`, plus the entries from the old file's `Merged:` line, so nothing is
triaged twice.

## Second only: read the earlier review

Leave the primary reviewer idle. Read the second reviews you took, and the existing
`.claude/plan/review-<branch>.md` when there is one: its findings are the **earlier
review**, the one the user has been fixing since.

Add each second review's `<reviewer>@<sha>` to the `Merged:` line of
`.claude/plan/review-<branch>.md`. Where that file does not exist, create it holding only a
`Merged:` line.

## Triage

Triage every finding this run took as one set: the agent's and the second reviews' in
**Full**, the second reviews' alone in **Second only**. The triage is the only thing you
render, and every finding appears in it exactly once.

**Remove duplicates first.** Two findings are one when they name the same site and the
same defect. Keep the clearer wording, take the higher severity, and tag it `both`. A
finding only one reviewer raised is tagged `primary` or with its reviewer name.

**In Second only, check each finding against the earlier review.** A second-review
finding that matches an earlier finding is a re-raise. Check the code: where it is fixed,
the finding goes to **Skip** with `fixed since the earlier review` as its reason. Where it
still stands, tag it `both`.

A stale finding carries `(stale: <n> commits since)`. Locate it by its snippet rather
than its line number, since the lines may have moved.

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
