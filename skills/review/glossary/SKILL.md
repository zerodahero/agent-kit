---
name: glossary
description: Check the branch's domain terms against the codebase and glossary, then rename to the terms you confirm
argument-hint: "[git ref]"
disable-model-invocation: true
---

A **term** is a name for a domain concept: a thing, process, state, or role the code
models. Language, framework, and library vocabulary (`Promise`, `middleware`, `useEffect`)
is not a term unless the diff gives it a domain meaning.

Every term lives on one or both **surfaces**:

- **code**: identifiers, DB columns, API fields, env vars, comments, logs, internal docs.
  Write a code word in backticks: `score`.
- **UI**: text a user of the product sees: UI copy, user-facing errors, exported file
  headers, emails, published user docs. Write a UI word in curly quotes: “Evaluation”.

A term can carry a different word on each surface. Decide each surface's word separately.

## Find the glossary

The **glossary** is the first of these that exists: `CONTEXT.md`, `GLOSSARY.md`,
`docs/glossary.md`, a `Glossary` heading in `CLAUDE.md` or `AGENTS.md`. Where none exists,
the glossary is `docs/glossary.md`, created at the Record step. Say in one line which
glossary you used.

## Collect terms

The range is `$ARGUMENTS` as the base, else the merge-base with the default branch, plus
uncommitted work. Read every term the range introduces or renames, across:

- identifiers: types, functions, variables, files, modules, DB columns, API fields, env vars
- comments and docstrings
- docs and READMEs
- UI copy, error messages, and log messages

Sort each term into one class:

- **Known**: matches a glossary entry, including its UI label. Count it; list nothing.
- **Violation**: uses a word the glossary marks *Avoid*, or a UI label that differs from
  the recorded one.
- **Collision**: outside the diff, the repo names this concept with a different word, or
  uses this word for a different concept.
- **New**: none of the above.

For every Violation, Collision, and New term, search the repo outside the range for the
term and for synonyms of its meaning. Record the existing word, its use count, and one
representative path. This evidence is what makes a collision a fact rather than a guess.

Tag a term **contract** when it appears in a DB schema or migration, a public route or
request/response field, an exported symbol of a published package, an env var, or code
outside the range.

Collection is done when every identifier the range introduces or renames, and every
domain noun in changed prose, is Known, listed, or set aside as library vocabulary.

## Write the review file

Write the **review file** to `${TMPDIR:-/tmp}/glossary/<repo>-<branch>.md`, where `<repo>`
is the repo directory name and `<branch>` has slashes replaced by `-`. Read
[REVIEW-FORMAT.md](REVIEW-FORMAT.md) first: it sets the counts line, the per-term block,
and the rules for each field.

Where nothing is listed, report the counts line and stop.

## Review

Use Plannotator when it is available: a `plannotator` tool, or `plannotator` on `PATH`.
Otherwise use `AskUserQuestion`.

### With Plannotator

Run `plannotator annotate <review file>`. The result is one of:

- **Approved** or **Annotated**: each answered question decides its entry, and each
  unanswered one takes its `Recommended:` choice. A note or annotation on an entry
  adjusts it. Where an "Other" answer, note, or annotation asks a question instead of
  deciding, answer it under that entry in the file and re-run annotate with question
  blocks left only on the undecided entries.
- **Dismissed**: stop. Change nothing.

### With AskUserQuestion

Ask one question per term, 4 terms per call, in review-file order. Each question carries
the term ID and meaning, and its options are the entry's choices with the `Recommended:`
choice first, labelled "(Recommended)". Put the existing-word evidence in the option
descriptions.

- An answer decides its entry. A note on an answer adjusts it.
- Where an "Other" answer asks a question instead of deciding, answer it in chat and ask
  that term again in the next call.
- Where the user declines the questions, stop. Change nothing.

Review is done when every listed term has a decided word on each surface it lives on.

## Apply

Rename every decided term inside the range: its code word across the code surface,
including file and module names that carry it, and its UI word across the UI surface. Use
a symbol-aware rename where the project has one (an LSP, or a tool such as Serena
`rename_symbol`), and fall back to edits.

For contract-tagged renames, list the contract sites and ask about them in one
`AskUserQuestion` batch before touching any. A declined contract site keeps its old word.

## Record

Write every decided term to the glossary, kept terms included, in the entry format from
[GLOSSARY-FORMAT.md](GLOSSARY-FORMAT.md). Merge into an existing entry by adding to its
*Avoid* list. Never write a second entry for the same concept. Where this run created the
glossary, add one line to `CLAUDE.md` (or `AGENTS.md` where the repo uses that): `Domain
terms: docs/glossary.md. Name new code and prose with these terms.`

## Verify

Run the typecheck, lint, and test commands the repo defines (`package.json` scripts, mise
tasks, `Makefile`). Grep the range for every rejected term. The only hits allowed are
contract sites the user declined.

Once the checks pass, decide whether to commit by where the branch's work came from:

- **Planned work** (the branch carries out a plan approved in this session): commit the
  renames and glossary entries as one commit of their own, staging only the files this run
  touched. A review or fix running alongside then lands its own commits on top, with no
  shared uncommitted files.
- **Unplanned work**: leave the changes uncommitted for the user to review.

Report the renames applied, the terms kept, the deferred contract sites, and the check
results. End with one recommended next step.
