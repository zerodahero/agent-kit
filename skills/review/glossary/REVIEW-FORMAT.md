# Review file format

Open with a counts line: `5 terms to decide (1 violation, 2 collisions, 2 new) · 14
known · glossary: docs/glossary.md`. Then one block per term, Violations first, then
Collisions, then New:

````markdown
## T3 · Listing [collision]

- **Meaning:** an open job advert a worker can apply to.
- **Code:** `Listing` · `src/hire/listing.ts`, +4 more

  ```ts
  export interface Listing {
  ```

- **UI:** “Listing” · job card heading in `JobCard.tsx`

  ```tsx
  <h3>Listing</h3>
  ```

- **Codebase says:** code `Posting` (31 uses, `src/postings/`); UI “Job”; glossary: Posting
- **Why chosen:** Inferred: matches the Indeed API field name.

:::question
T3 · Listing: which words?

- [ ] Keep: code `Listing` · UI “Listing”
- [ ] Code `Posting` · UI “Job”
- [ ] Code `Opening` · UI “Opening”

Recommended: Code `Posting` · UI “Job”
:::
````

- The **heading** names the term in plain text, followed by its class tags.
- **Code** and **UI** each list that surface's word and its sites. A term on one surface
  writes `none` on the other line.
- Each site is a path and a **snippet**: the 1–3 lines that use the word, copied verbatim
  into a fenced block with a language tag, trimmed with `…`. A path carries no line number.
  Show the first site only, then `+N more`. Contract sites are the exception.
- **Why chosen** carries the real reason where this session wrote the code. Elsewhere it
  starts with `Inferred:` and cites its evidence: prior art, the library's term, the
  commit message.
- The **question** line starts with the term ID, so each answer maps back to its entry.
- **Choices** are Keep, then two or three alternatives. Each names the word for every
  surface the term lives on. Plannotator and `AskUserQuestion` both offer "Other", so add
  no Custom choice.
- **Recommended** copies one choice label exactly: the repo's existing word for a
  Collision, the glossary word for a Violation, and otherwise the most readable candidate.
  Recommend Keep when no candidate beats the current term. Leave every choice `- [ ]`:
  Plannotator renders `- [x]` as already settled.
- A contract term gets `[contract]` beside its class and a **Contract sites:** line listing
  every contract site, each as a path and snippet.
