---
name: human-review
description: Prepare a layered human review of this branch as a korin wizard that walks purpose, design, flow, and tests, then the full diff in tuicr
argument-hint: "[base ref]"
disable-model-invocation: true
---

You prepare a review that a **human** runs. You write four short docs and a korin wizard
that walks them in order: Purpose, Design, Flow, and Tests. It ends with a full code
review in tuicr. Each layer answers one question, so the human reaches the code already
knowing what it does and why. Every doc exists to **reduce** what the human holds in their
head, so short beats complete.

You never run the wizard. Everything you write is **pinned** to one base SHA and one head
SHA, so the wizard shows the same thing every time it runs.

## 1. Pin the range

- **Repo:** `git rev-parse --show-toplevel`, as an absolute path.
- **Branch:** `git branch --show-current`. When it is empty, stop and ask the user to check
  out the branch to review.
- **Base ref:** `$ARGUMENTS` when given. Otherwise the target of
  `git symbolic-ref --short refs/remotes/origin/HEAD`, else `main`, else `master`.
- **Base:** `git merge-base <base ref> HEAD`. **Head:** `git rev-parse HEAD`. Both full
  SHAs. When `git diff --quiet <base> <head>` succeeds, there is nothing to review: stop and
  say so.
- **Id:** the branch with each `/` as `-`, then `-`, then the first 6 characters of
  `printf %s "<branch>" | shasum`. `feature/foo` and `feature-foo` get different ids.
- **Run directory:** `<repo>/.reviews/<id>/<base7>-<head7>`, where `<base7>` and `<head7>`
  are the first 7 characters of each SHA.

When the run directory already holds a `meta.json`, its `base` and `head` must equal yours.
If they differ, stop and report the collision. If they match, this is a **rerun**: you
overwrite the docs and the wizard, and keep `notes/`, since the range is unchanged.

**Done when** the repo, branch, base ref, base, head, id, and run directory are all known.

## 2. Gather, from the pinned commits

Read code only through Git at the pinned SHAs. The working tree may hold edits that are not
in the range, so it is never a source.

- `git diff --numstat -M <base> <head>` and `git diff --name-status -M <base> <head>` list
  the changed files.
- `git diff <base> <head> -- <path>` gives a file's changes.
- `git show <head>:<path>` and `git show <base>:<path>` give whole files on each side.
- `git ls-tree -r --name-only <head>` gives the tree for the Design doc's file tree.
- `git grep -n <pattern> <head>` searches the head side, for callers and seams outside the
  diff.

Also collect:

- **The claim.** `.claude/plan/current.md` when it exists, else the messages of
  `git log --reverse <base>..<head>`.
- **Uncommitted work.** `git status --porcelain`. Any entry goes in Purpose as out of scope.
- **Prior runs.** Other run directories under `.reviews/<id>/`. The newest one's
  `findings.md` goes in Purpose as possibly stale. Copy none of its notes.
- **Seam kinds.** [`SEAMS.md`](SEAMS.md), plus `<repo>/.reviews/seams.md` when it exists.

**Done when** every changed file has been read at the head, and every modified or deleted
file also at the base.

## 3. Write the layer docs

Write the four docs into the run directory, following [`LAYERS.md`](LAYERS.md):
`01-purpose.md`, `02-design.md`, `03-flow.md`, and `04-tests.md`.

**Done when** all four exist, and each fits on two screens.

## 4. Build the run directory

- Create `<repo>/.reviews/.gitignore` containing `*` when it is missing.
- Create `<run directory>/notes/`.
- Write `meta.json` with `branch`, `base_ref`, `base`, `head`, and `generated_at`
  (ISO 8601).
- Copy `collect-findings.sh`, `annotate-layer.sh`, and `layer.korin` from this skill's
  directory into the run directory, and make the two scripts executable.
- Copy `template.korin` from this skill's directory to `<run directory>/review.korin`,
  then edit the copy:
  - Set `title` to `"Human review: <branch>"`.
  - Replace each `param <name> required` with `param <name> = "<value>"`: `repo` and `dir`
    (the run directory) as absolute paths, `base` and `head` as full SHAs.
  - When the `HUMAN_REVIEW_PREVIEW` environment variable is set, use its value as the
    default of `param preview`.
  - Replace the `# REVIEW NOTE` comment and the note under it with one note: the number of
    changed files, and the file to start with, chosen from the Flow doc's entry point.
  - Leave every other line as the template has it.

## 5. Check the wizard

Run `korin check --format json <run directory>/review.korin`. Fix each diagnostic and run
it again. Then read `korin plan` on it. Run `korin fmt` on it last.

**Done when** `korin check --format json` prints `[]` and `korin fmt --check` passes.

## 6. Hand off

Tell the user:

- **The command,** run from the repo root:
  `korin run .reviews/<id>/<base7>-<head7>/review.korin`
- **How a layer works.** The wizard is a korin guide: it pauses before each stage, and
  Enter runs it. With Plannotator, each doc opens in it, and the annotations become that
  layer's notes. Comment on a test name to flag it for a closer look. Without Plannotator,
  nvim opens the doc read-only on the left and the notes file on the right; write notes,
  then `:wqa`. Ctrl-C stops the review, and `findings.md` in the run directory keeps every
  finished layer. `--from "<stage>"` resumes at a stage.
- **Preview.** Only when `plannotator` is not on the `PATH` and `HUMAN_REVIEW_PREVIEW` is
  unset: for a live Markdown preview in nvim, set `HUMAN_REVIEW_PREVIEW` to an nvim command
  before generating, or add `--param preview="<nvim command>"` to the run.
- **What it needs:** `korin` 0.1.2 or later, `tuicr`, and either `plannotator` or `nvim`
  on the `PATH`. korin keeps its run journal in `.korin/` at the repo root, so that
  directory belongs in a gitignore.
- **Anything flagged:** uncommitted work left out, and a prior run's findings.
