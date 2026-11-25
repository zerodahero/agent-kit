---
name: plan-review
description: Red-team a plan in plan mode with a persistent opencode reviewer before the user reads it. Use when a plan settles architecture, a data model, an external contract, or a scope boundary, or when the user asks for plan review.
argument-hint: "[provider/model]"
---

You run a review loop on the plan you are writing. A **plan reviewer**, an opencode agent
in one persistent session, red-teams the plan over several rounds. You record every
finding in a **ledger** at the end of the plan, revise, and send the plan back, until
nothing blocking is left. Then the user reads a plan that has already survived review,
and sees only the decisions that need a human.

The reviewer's feedback is input, not authority. So is yours to it. Accept a point
because it is right, never to converge. What the two of you cannot settle goes to the
user.

**Files.** [LEDGER-FORMAT.md](LEDGER-FORMAT.md) defines the ledger: read it before the
first merge. [PLAN-REVIEW-METHOD.md](PLAN-REVIEW-METHOD.md) is the reviewer's method:
read it to know what its reports hold. Two scripts in this directory do the mechanical
work: `run-round.sh` runs each round, and `ledger.py` maintains the ledger.

**Sandbox.** Run both scripts with the sandbox disabled. opencode writes its log outside
the sandbox, and the plan file sits outside it too. `run-round.sh` checks this first and
exits 2 at once with that message.

## 1. Start

The loop runs in plan mode, after scoping and before the plan goes to the user. Outside
plan mode, say so and stop.

When the user typed `/plan-review`, start. When you reached this skill on your own, check
the scoped work for a **load-bearing** decision: architecture, a data model, an external
contract, or a scope boundary. With one, offer the review in one `AskUserQuestion` and
start on a yes. With none, write the plan without the loop and say nothing about it.

The plan may already be open in Plannotator: `ExitPlanMode` ran before the user asked
for review. The user may be annotating that version. Ask whether they have notes on it
before you start. Apply notes they send under their own revision rules, then start the
loop on the revised plan. Tell the user that the loop ends in a new version, so notes on
the open version after this point are lost.

`$ARGUMENTS`, when present, is a `provider/model` for the reviewer. Without it, the
reviewer runs on opencode's default model.

The **slug** keys every file the loop writes. Make it 3–5 words from the plan's title,
kebab-cased (`release-await-deploy`), and keep it for the whole loop.

## 2. Anchor

The **anchor** is a locked block at the top of the plan. It records what the scoping
agreed, so both agents measure direction against it and never against each other. Draft
it from the scoping conversation:

```markdown
## Anchor v1 (locked: only the user edits)

Purpose: <one sentence>

Risk: <what failure costs here, such as "internal tooling, a human watches every run">

| # | Item | Kind | Load-bearing | Source |
|---|---|---|---|---|
| A1 | Import runs as a Temporal workflow, one activity per row batch | architecture | yes | agreed |
| A2 | New `benefit_import` table; `benefit` schema unchanged | data model | yes | you |
| A3 | Partial failure keeps good rows and reports bad ones | behaviour | no | inferred |

Non-goals: N1 an import UI · N2 dedupe against existing benefits
```

- **Kind**: architecture, data model, external contract, scope boundary, behaviour, or
  constraint. The first four are load-bearing.
- **Source**: `you` (the user said it), `agreed` (you proposed it, the user accepted), or
  `inferred` (nobody discussed it). Inferred items are where the user looks hardest.
- **Risk** sets how hard the reviewer grades. Without it, every round adds hardening.

The anchor is the plan's list of decisions. The plan body cites anchor IDs (`A3`) and
explains *how* each item is built, without a second list of the same choices.

Show the anchor in one `AskUserQuestion`, with an option preview of one line per item,
`A1 · architecture · yes · agreed — <item>`, under the purpose and risk lines: "Approve",
plus "Edit" for changes through Other. Apply the user's edits and ask again. This step is
done when the user approves. Write the anchor to the top of the plan file, under the
title. From here on, the anchor changes only by the user's hand.

## 3. Write the plan

Write the plan below the anchor. Then add the empty ledger:

```bash
${CLAUDE_SKILL_DIR}/ledger.py init <plan path>
```

## 4. Run a round

`N` counts successful rounds, starting at 1. Each run of the script is an **attempt**. A
failed attempt leaves `N` where it is.

Run one attempt at a time, in the background with `run_in_background`, from the repo
root, with the round's instructions on stdin:

```bash
${CLAUDE_SKILL_DIR}/run-round.sh <slug> <N> <plan path> [provider/model] <<'EOF'
<instructions>
EOF
```

The **instructions** carry what only you know. In round 1, use this shape:

```markdown
Anchor: v1
Key files: <paths the plan changes or rests on, one line each>
External references: <docs outside the repo the plan relies on>
Attach: <absolute path of one external reference; one line per file>
Must not run: <commands or systems the reviewer must leave alone, or "none">
Focus: <the 1–3 risks you most want checked>
Depth: <outline-only sections, or "full">
```

The script attaches each `Attach:` file, so the reviewer reads it without leaving the
repo. `Attach:` is optional: leave it out, or write `none`, when there is nothing to
attach.

`Depth:` names the sections that are outlines, such as later phases that get their own
plans. The reviewer checks that such a section states its obligation, not how it is
built. Without the line, every section draws full-depth findings.

From round 2 on, send the anchor's current version and the key map that `ledger.py
apply` printed (`R1-F2 → L-03`). Repeat `Depth:` when it changed. The ledger needs no
copy: it sits at the end of the plan, so the round input carries it, and the diff shows
what changed in it. Add a rebuttal or deferral argument only when it is longer than the
one-line reason in its decision cell. The script adds the round input, its hash, the report path, the diff, and in round 1 the
method. It sends them as one attached prompt file, and keeps the prompt and opencode's
event log beside the report.

Wait for the completion notification. The script's output names the report path, the
input hash, the session, and the result: `ran`, `ran-with-denials`, or `failed`.

`ran-with-denials` means a tool call was denied, and the script found each denied call in
the report's `Denied calls` section. That attempt is valid. A check the reviewer could not
complete shows up in `Coverage`, which the checks below cover.

**Check the attempt.** The attempt fails when any of these holds:

- the script exits 1 or 2
- the script exits 3: a denied call it printed as `missing in report` is not in the
  report's `Denied calls` section. Check those lines by hand first. When the report
  lists the call in other words, such as a reflowed multi-line command, the attempt
  stands.
- the report path the script printed holds no report
- the report's verdict line or header line does not parse
- the header's `Input` hash differs from the hash the script printed, or its `Round` or
  `Anchor` differs from this round's
- the header says `Coverage: incomplete`
- the report has no lens lines: one per lens in round 1, and lines for the diff, the
  anchor, and regressions from round 2 on. A report with a header and no body is
  truncated, never clean.

Tell the user a failed attempt failed, with the reason, and leave the report unmerged. A
failed attempt is never a clean review. Retry once when the cause looks transient. After
a second failure in the same round, stop the loop and ask the user how to proceed. When
the user decides to abandon the round, delete its frozen input
(`.claude/plan/plan-input-<slug>-r<N>.md`, read-only, so `rm -f`), revise if they asked,
and run round `N` again.

## 5. Merge

Read the report. Then merge it into the ledger:

```bash
${CLAUDE_SKILL_DIR}/ledger.py apply <plan path> <report path> <session>
```

It gives each new key the next ledger ID, applies the reviewer's dispositions by the
closure table in [LEDGER-FORMAT.md](LEDGER-FORMAT.md), reopens regressions, records each
🔵 as deferred, and adds the signals row. It prints the key map, the load-bearing shifts,
the disputed items, the reviewer's `Recommend`, and the IDs that need your decision.
Keep the key map for the next round.

1. Decide every ID under `decide`: **accept**, **rebut**, or **defer**, each with a
   one-line reason. Review each ID under `still open` too, and change its decision only
   when you now see it differently. Write all decisions in one call:

   ```bash
   ${CLAUDE_SKILL_DIR}/ledger.py set <plan path> <<'EOF'
   L-14 | decision | accept — move the backfill into the workflow
   L-15 | decision | rebut — A2 locks only `benefit`
   EOF
   ```

   `set` also takes `<ID> | status | <status>`, `<ID> | shift | <shift>`, and
   `header | Status | <status>`.

2. Check each finding's direction yourself. Where acting on it would pull the plan away
   from an anchor item, record the shift as yours. Where you and the reviewer read the
   shift differently, record both readings.

3. Where any finding carries a load-bearing shift, by either reading, stop here and go
   to step 6. The plan stays as it is until the user answers, so nothing touches a
   locked decision first.

4. Revise the plan for every accepted item. Cite an item that needs code as `(L-xx)` on
   the plan step that implements it. Mark one fixed in the plan text alone as
   `accept (plan-only)`.

5. Add a bullet to the plan's `## Revision notes` that cites the ledger IDs it acts on:
   `R2: moved the backfill into the workflow (L-04, L-07).`

6. Fill in the signals row's Ping-pong cell when an item was rebutted twice.

## 6. Decide what comes next

Take the first row that matches:

| State                                                                   | Next                                                                                                                                                                                                             |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A load-bearing shift, from either agent                                 | **Halt.** Set the ledger status to `halted` and escalate it now (step 7). The rest of the review waits on the answer.                                                                                            |
| An item rebutted twice (**ping-pong**)                                  | Escalate it now.                                                                                                                                                                                                 |
| An item the reviewer marked `disputed`                                  | Escalate it now.                                                                                                                                                                                                 |
| Half or more of this round's new 🔴/🟡 are `fix-caused`, and at least 2 | Escalate them now. Your fixes are creating problems. `new-surface` findings never count here: new design draws new findings.                                                                                     |
| The reviewer's header says `Recommend: stop`                            | Escalate every open 🔴 and 🟡 (step 7), with the reviewer's reason.                                                                                                                                              |
| Every 🔴 and 🟡 is closed by the closure table, or `escalated`          | Go to step 7 with whatever is escalated, then step 8.                                                                                                                                                            |
| `N` is under 5                                                          | Run round `N + 1`.                                                                                                                                                                                               |
| `N` is 5 or more                                                        | Ask the user whether to run another round. Show this round's signals row, the open items, and your recommendation. On a no, escalate every open 🔴 and 🟡 (step 7), so none reaches the user as silently closed. |

An accepted fix closes only when the reviewer verifies it, so the last round of a loop
is a verification round.

## 7. Escalate

Write each escalation into the ledger's `### Escalations`, grouped by `Depends on`, in
the format LEDGER-FORMAT.md gives. Then ask the user with `AskUserQuestion`, up to 4
questions per call, one dependency round at a time, with your recommendation first.

Record each answer as `human-decided: fix`, `accept risk`, or `drop`. Where an answer
changes what an anchor item decides, the user has edited the anchor: write it as
`Anchor v<K+1>` with a one-line changelog, and tell the reviewer next round, as in step 8. Answers of `fix`
reopen their items as accepted. Revise, and run another round so the reviewer verifies
them. After a halt, continue the loop from step 4.

## 8. Hand off

Check every `(L-xx)` citation in the plan against the ledger. An obligation stands only
while its item is accepted, or `human-decided: fix`. Remove the citation from a step
whose item ended any other way. Then set the ledger status to `converged`, or to
`escalated` when the user accepted risks. Call `ExitPlanMode`. The plan reaches the user with its revision notes and ledger.

The user's feedback on the plan follows their own revision rules, without the reviewer,
unless the user edits the anchor or a load-bearing item. Then write the edited anchor as
`Anchor v<K+1>`, with a one-line changelog under its heading. Tell the reviewer in the
next round's instructions that v<K+1> supersedes v<K>, and return to step 4. Steps 4–7
apply in full.

Once the user approves the plan, copy it to `.claude/plan/current.md`, so `/review` and
`/second-review` find it. Code review later uses a fresh reviewer session, never this one:
this reviewer approved the plan.
