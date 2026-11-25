# Review ledger format

The ledger is a section at the end of the plan, under `## Review ledger`. It records every
finding the plan reviewer raised, what the author decided, and how each one closed. The
plan's `## Revision notes` say *how* the plan changed and cite ledger IDs. The ledger says
*why*. Keep each fact in one of the two.

`ledger.py`, beside this file, maintains it: `init` writes the empty section, `apply`
merges a report, and `set` changes cells. Its output keeps the layout below, so edit the
ledger through it and keep prose edits to the Escalations section.

## Header

One line under the heading:

`Reviewer: <name> · Session: <id> · Rounds: 3 · Anchor: v1 · Status: converged`

`Rounds` counts successful rounds. `Status` is `in review`, `converged`, `escalated`, or
`halted` (a load-bearing shift stopped the loop).

## Table

| ID   | Sev | Raised                 | Finding                                    | Claude's decision                                        | Status            | Shift                       | Depends on |
| ---- | --- | ---------------------- | ------------------------------------------ | -------------------------------------------------------- | ----------------- | --------------------------- | ---------- |
| L-01 | 🔴  | 1 · R1-F1              | §Backfill — the backfill has no rollback.  | accept — add a reversible staging table (L-01 on step 3) | resolved          | none                        | —          |
| L-02 | 🟡  | 2 · R2-F1 · fix-caused | §Backfill — the staging table bypasses A2. | rebut — the table is new, `benefit` is untouched         | rebuttal-accepted | load-bearing (A2), reviewer | L-01       |
| L-03 | 🔵  | 1 · R1-F4              | §Tests — name tests after behaviour.       | defer — low                                              | deferred          | none                        | —          |

- **ID**: `L-01` and up, assigned at merge, stable across rounds. Never reuse one.
- **Sev**: 🔴, 🟡, or 🔵.
- **Raised**: the round, the reviewer's round-local key, and the tag when there is one:
  `fix-caused`, `new-surface`, `missed-earlier`, or `regression r<N>` when a resolved
  item reopened.
- **Finding**: the plan section and the first sentence of the reviewer's finding. The
  evidence stays in the round's report, `.claude/plan/plan-review-<slug>-r<N>-a<A>.md`.
- **Claude's decision**: `accept`, `accept (plan-only)`, `rebut`, or `defer`, then ` — `
  and a one-line reason.
- **Status**: from the closure table below.
- **Shift**: `none`, `minor (A<n>)`, or `load-bearing (A<n>)`, plus `drift` when it
  applies, and which agent flagged it: reviewer, Claude, or both. Where the two agents
  disagree about the shift, write both readings and escalate it.
- **Depends on**: other ledger IDs, or `—`. Escalations group their questions by these.

## Closure

Each outcome has one owner who closes it. Claude cannot close a 🔴 or 🟡 on its own.

| Claude's decision             | Closed when                              | Status                                                                       |
| ----------------------------- | ---------------------------------------- | ---------------------------------------------------------------------------- |
| accept                        | the reviewer reports `verified-fixed`    | `resolved`                                                                   |
| rebut                         | the reviewer reports `rebuttal-accepted` | `rebuttal-accepted`                                                          |
| defer, on a 🟡                | the reviewer reports `deferral-accepted` | `deferred`                                                                   |
| defer, on a 🔵                | at once, with no reviewer step           | `deferred`                                                                   |
| any, then disputed or a shift | the user answers the escalation          | `human-decided: fix`, `human-decided: accept risk`, or `human-decided: drop` |

The user's dispositions: `fix` acts on the finding, `accept risk` keeps the plan and
records the risk, and `drop` rules the finding out.

Statuses on the way: `open` (awaiting a fix or a reply), `disputed` (the reviewer
disagreed after a rebuttal), `escalated` (put to the user, no answer yet).

`resolved` means the reviewer verified the fix. `human-decided: accept risk` means the
user accepted residual risk. The two stay distinct.

An unchanged argument against a closed item is never retried, so a legitimate deferral
does not loop. A **regression** is the exception: when a later revision or a new anchor
version breaks a `resolved` item, the reviewer reopens it with new evidence. Its status
returns to `open`, and its Raised field gains `regression r<N>`.

Two statuses record history only:

- `superseded`: a later revision removed the thing the finding was about.
- `withdrawn`: the reviewer retracted it.

## Implementation obligations

An accepted item that needs code is an **obligation**. Cite its ID on the plan step that
implements it: `3. Stage imported rows in benefit_import_staging (L-01).` The code
reviewers read the plan's final text, and the tag leads them to the ledger row for detail.

An accepted item fixed in the plan text alone is `accept (plan-only)`, and no step cites
it. Code review ignores it, along with `superseded`, `withdrawn`, and uncited rows.

## Signals

A table below the ledger, one row per successful round. `ledger.py apply` writes it:

| Round | New 🔴/🟡 | fix-caused | new-surface | missed-earlier | Ping-pong | Hotspot       |
| ----- | --------- | ---------- | ----------- | -------------- | --------- | ------------- |
| 1     | 5         | —          | —           | —              | —         | §Backfill (3) |
| 2     | 4         | 25%        | 75%         | 0%             | —         | §Staging (3)  |

- **fix-caused**, **new-surface**, and **missed-earlier**: shares of that round's new
  🔴/🟡.
- **Ping-pong**: IDs rebutted twice. The author fills it in.
- **Hotspot**: the plan section holding the most new findings that round, with its count.

## Escalations

Every disputed item and every shift, as questions grouped into rounds by `Depends on`. A
question waits for the round after the items it depends on. The author asks each round
with `AskUserQuestion` and records the answers here.

```markdown
### Escalations

#### Round 1

❓ **Q1** - **Stage imports in a new table (L-02)**: The reviewer reads the staging table
as a change to the data model A2 locks. Claude reads A2 as locking `benefit` alone.

➡️ Keep the staging table. It is new, and `benefit` is untouched.

Alternative (reviewer): drop staging and roll back from an audit log.

Answer: yes — human-decided: drop
```

Claude's position is the ➡️ recommendation, worded so that "yes" accepts it. The
reviewer's position is the alternative. The answer line records the user's disposition
once given.
