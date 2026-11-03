# Triage format

````markdown
**3 should fix, 2 could fix, 1 out of scope, 2 skipped.** 🔴 1 · 🟡 3 · 🔵 2

Range: `main...HEAD` · Plan: `.claude/plan/004.md` · Second reviews: opencode-gpt-5 (current), codex-o4 (stale) · Full report: `.claude/plan/review-zat-hire-form.md`

Cross-file checks: e2e locators clean, migrations present, docs anchors clean.

## Should fix (3) — 🔴 1 · 🟡 1 · 🔵 1

- **S1** · 🔴 **High** · both · `src/hire/hire.controller.ts`
  `@Roles()` with no `RolesGuard` — the endpoint fails open.

  ```ts
  @Roles('hiringManager')
  @Post('postings')
  ```

- **S2** · 🟡 **Medium** · primary · `src/hire/salary.ts`
  New behaviour with no test — nothing covers the dollars-to-cents conversion.

  ```ts
  export function toCents(dollars: number): number {
  ```

- **S3** · 🔵 **Low** · primary · `src/hire/Form.tsx`, `src/hire/SalaryField.tsx`
  Explanatory comments. CLAUDE.md "Do not comment the code".

  `src/hire/Form.tsx`

  ```tsx
  // reset the salary fields when the type changes
  ```

  `src/hire/SalaryField.tsx`

  ```tsx
  // the API wants cents, not dollars
  ```

## Could fix (2) — 🟡 1 · 🔵 1

- **C1** · 🟡 **Medium** · opencode-gpt-5 · `src/hire/hire.repository.ts`
  Unbounded `findAll()` — no limit, and the table grows per posting.

  ```ts
  return this.db.selectFrom('hire_posting').selectAll().execute();
  ```

- **C2** · 🔵 **Low** · codex-o4 (stale: 2 commits since) · `src/hire/hire.service.ts`
  `cnt` abbreviates count. Name it `count`.

  ```ts
  const cnt = postings.length;
  ```

## Out of scope (1) — 🟡 1

- **O1** · 🟡 **Medium** · primary · `src/workers/augment.py`
  Retry policy is default across this worker. Its own change.

  ```python
  worker = Worker(client, task_queue=TASK_QUEUE, workflows=WORKFLOWS, activities=ACTIVITIES)
  ```

## Skip (2)

- **X1** · opencode-gpt-5 · `src/workflows/ingest.py` — flagged `datetime.now()` as non-deterministic; it sits in the `fetch_postings` activity, not `run()`.
- **X2** · primary · `src/hire/Form.tsx` — claimed no test; covered by the `"submits salary"` test in `Form.spec.tsx`.

**Next:** fix S1 first — the missing `RolesGuard` is a live authorization hole.
````

Rules for that shape:

- **Counts lead.** The verdict line carries the bucket counts and the severity totals,
  so the reader knows the shape before reading.
- **The range line** names the range, the plan, and the full report path. It names the
  second reviews only when any merged, each marked `current` or `stale`.
- **Every finding carries an ID**: its bucket letter, then its position in that bucket.
  **S** should fix, **C** could fix, **O** out of scope, **X** skip — the third Should
  fix finding is **S3**. Numbering restarts per bucket, and a rolled-up finding takes one
  ID. Name findings by ID in the Next line and the follow-up.
- **Every finding carries its source** after the severity: `both`, `primary`, or the
  second reviewer's name, with its stale note when it has one.
- **Two lines per finding, then its snippet** — ID, severity, source, and path; then the
  prose; then the snippet. Never one long wrapping line.
- **A snippet** is the 1–3 lines a finding is about, copied verbatim into a fenced block
  with a language tag, trimmed with `…`. Locate code by path and snippet; a path carries no
  line number. A finding about something missing quotes the changed lines that need it; a
  systemic finding with no single site takes none.
- **A rolled-up finding** carries one snippet per location. Its path line lists every path;
  where the paths differ, each snippet's path sits on its own line above it.
- **Severity is 🔴 High, 🟡 Medium, 🔵 Low**, carried over from the reviewers. Each bucket
  heading ends in its own severity mix, omitting any severity it has none of.
- **Skip is one line each**, reason in a clause, under a heading carrying the count.
  Skip takes no severity dots — an invalid finding has no meaningful severity — and no
  snippet; its reason names code by symbol or test name.
- **Omit an empty bucket entirely.** Never print a "none" line.
- **No emoji beyond the three severity dots.** Nothing decorative, no section icons.
- **One recommended next step**, not a menu. Recommend, do not hedge.
