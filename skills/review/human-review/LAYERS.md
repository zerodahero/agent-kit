# Layer docs

The four docs a human reads before the code review. Each doc answers one question, so the
reader reaches the code already knowing what it does and why. The goal is to **reduce**
what the reader holds in their head: every doc is short enough to take in at a glance.

## Rules for every doc

- **Short.** One screen is the target, two the ceiling. When a doc runs long, cut detail.
- **Exact.** Code in a doc is copied from `git diff` or `git show` at the pinned SHAs,
  never retyped. A bare `path:line` is the head side. Code that exists only at the base
  cites `base:path:line`.
- **Describe, never judge.** A doc says what the change does. The human decides whether it
  is right.
- **Header.** Each doc opens with `# <Layer>: <branch>` and a line holding the range
  `<base7>..<head7>`.
- **Plain Markdown.** Headings, lists, emphasis, code blocks, and Mermaid blocks only. The
  viewer renders no HTML tags, so `<sub>`, `<small>`, and `<br>` show as literal text.

## 01-purpose.md

The question: what is this change for?

Write for a person who uses the product, not one who reads the code. Plain words, no
identifiers, no file names. Say what changes for the people the product serves and why
that matters. Write in full sentences, in a calm explanatory voice, the way good product
docs explain a feature.

- **In one sentence.** What the change does, in one sentence.
- **Summary.** One paragraph: the problem, what the change does about it, and what someone
  will notice afterwards.

Then, only when present, a `## Notes` section at the end, one line each in italics:

- the claim's source (the plan file's path, or "commit messages");
- uncommitted files left out of this review;
- a link to a prior run's findings, labeled "prior findings at `<base7>-<head7>`, may be
  stale".

## 02-design.md

The question: how is it built, and where does each file fit?

- **Approach.** The architecture choice in one sentence. Use up to three only when there are
  separate choices.
- **Diagram.** A Mermaid `flowchart` of the parts this change touches and how they connect.
  Give each node a short, stable id and a readable label. Leave out parts the change does
  not reach. Mark new and changed nodes with these two class definitions, copied exactly.
  They set the text color with the fill, so labels stay legible in light and dark themes:

  ```text
  classDef new fill:#d1fae5,stroke:#047857,color:#064e3b
  classDef changed fill:#fef3c7,stroke:#b45309,color:#78350f
  ```

  Every other node keeps the theme's default style.
- **Files.** A file tree in a `text` block, holding only the directories on the path to a
  changed file. Collapse unchanged siblings to `…`. Mark each changed file `+` added, `~`
  modified, or `-` deleted, and end its line with `→ <node id>` for the diagram node it
  belongs to. Tests point at the node they test.

## 03-flow.md

The question: what path does the change take at run time, and where does that path jump?

- **Diagram.** A Mermaid `sequenceDiagram` of the main path the change adds or alters,
  entry point to side effect. At most two diagrams. Label each **seam** arrow
  `<label>: <name>`, using the seam kinds in [`SEAMS.md`](SEAMS.md). When the path changed,
  mark new steps with `Note over` and the word "new".
- **Seams.** For each seam the diagram crosses, in the order it crosses them, a close-up
  of that one hop. No code: a hunk means little out of context, and the code review shows
  it in place.
  - A heading `### <n>. <label>: <name>`.
  - A Mermaid `flowchart LR` of the hop alone: the sender, the mechanism that carries
    control (the token, event, queue, route, or decorator, named as the code names it), and
    each receiver. Add the place that wires them together, such as a module's provider list
    or a listener registration, with a dotted edge. Mark new and changed nodes with the
    Design doc's two class definitions.
  - Under the diagram, one line per node that is code: its label, then its `path:line`.
  - One line for a risk flag from `SEAMS.md`, only when this change triggers it.

  ````markdown
  ### 2. event: application.submitted

  ```mermaid
  flowchart LR
    submit["SubmitHandler"] -- "emits" --> evt(["application.submitted"])
    evt -- "@OnEvent" --> notify["NotifyReviewer"]
    mod["NotificationsModule"] -.->|registers| notify
    classDef new fill:#d1fae5,stroke:#047857,color:#064e3b
    class notify new
  ```

  - SubmitHandler: `api/src/submit/submit.handler.ts:42`
  - NotifyReviewer: `api/src/notify/notify-reviewer.listener.ts:12`
  - NotificationsModule: `api/src/notify/notifications.module.ts:8`
  ````
- Write "No seams" under the diagram when the path crosses none.

## 04-tests.md

The question: what behavior does the change promise?

Show test **names**, not test code, in testdox form. The code review stage covers the test
code.

- **Scope.** Every test the diff adds, changes, or removes. Leave out unchanged tests.
- **Components.** When the changed tests sit in more than one component of a monorepo,
  such as `frontend` and `webserver`, give each component a `## <component>` heading. Name
  it after the component's top-level directory. In a single-component repo, use no
  component headings.
- **Shape.** One list per test file. Its top item is the file's outer `describe` (or
  equivalent) in bold, followed by the file's path in parentheses, like a citation. A file
  with no outer `describe` takes the name of the unit it tests. Under that item, a nested
  list follows the inner `describe` blocks, with each test as a sentence. Tags are `[new]`,
  `[changed]`, and `[removed]`. Read removed names from the base side:

  ```markdown
  - **Application deadline** (`api/src/deadline.spec.ts`)
    - when the deadline has passed
      - [new] rejects a submission
      - [changed] tells the applicant the closing date
  ```
- **Names as written.** Copy each name from the code. Turn a `should_x_when_y` or
  `testXWhenY` name into words. Leave its meaning alone.
- Write "No tests changed" when the diff touches no test. The reader will note it.
