# Changelog

Every release ships the `zerodahero-skills` and `zerodahero-plan-capture` plugins and the
`opencode-zerodahero` npm package at one version.

## [0.7.1] - 2026-11-25

### Fixed

- **plan-review:** An empty `Attach:` line no longer fails the round. An empty value or
  `none` attaches nothing.
- **plan-review:** A denied tool call no longer fails an attempt when the report lists it
  under `Denied calls`. `run-round.sh` checks the list itself and prints
  `ran-with-denials`. It exits 3 only for a denied call the report leaves out.
- **plan-review:** Round 2 and later no longer send the ledger. The round input already
  carries it at the end of the plan.

### Added

- **plan-review:** `ledger.py show <plan>` prints the ledger without changing it.
- **plan-review:** A `Depth:` line in the round 1 instructions names outline-only
  sections. The reviewer checks what those sections must deliver, not how they are
  built.
- **plan-review:** The skill covers a review that starts after the plan is already open
  in Plannotator.

## [0.7.0] - 2026-11-25

### Fixed

- **opencode:** The `second-reviewer` agent no longer allows `rg --pre`, which runs any
  command, or every `git branch` form, which includes `git branch -D`. It now uses the
  V2 `permissions` list with the same deny rules as `plan-reviewer`. Download
  `second-reviewer.md` again to get the fix.

### Changed

- Both plugins and the npm package now release together at one version, tagged
  `v<version>`. `zerodahero-plan-capture` jumps from 0.1.0 to 0.7.0 to match.
- Each release has a GitHub release, with its notes taken from this changelog.

### Maintenance

- CI checks that every shipped skill is in the plugin's skills list, and that every
  `agents/openai.yaml` has a display name and a short description under 60 characters.
- CI checks that the two opencode reviewer agents share one read-only shell policy.
- Tests cover `ledger.py` (pytest through uv) and the opencode `second-review` prompt
  (`node:test`).
- ruff lints Python, and rumdl lints Markdown.
- Commit messages and PR titles follow Conventional Commits, checked by an hk
  `commit-msg` hook and in CI. git-cliff drafts each changelog entry.
- Renovate keeps the mise tools, pinned actions, Python dev dependencies, and the
  Claude Code and hk versions current.
- `mise run eval` runs skill-triggering evals locally.

## [0.6.0] - 2026-11-25

### Added

- The `neurospicy` output style, listed as `zerodahero-skills:neurospicy`. It leads with
  the point, keeps working-memory load low, and ends with one concrete next step.

## [0.5.0] - 2026-11-24

### Added

- `plan-review` ships in the plugin. It red-teams a plan in plan mode with a persistent
  opencode `plan-reviewer`, and keeps a review ledger through `ledger.py`.

## [0.4.0] - 2026-11-24

### Added

- `/review second [provider/model]` runs the code-reviewer agent and an opencode second
  review in parallel, and triages both at once.
- The `human-review` skill: a layered review of the branch as a korin wizard.
- The `plan-review` draft and the opencode `plan-reviewer` agent.

### Changed

- Triage can change a severity with a reason, record a rejected part of a finding, and
  opens with an index when more than 8 findings need action.
- A lone second review can be triaged, and findings render as flush-left blocks.
- The `second-reviewer` agent runs one shell command per call.

## [0.2.2] - 2026-11-03

### Fixed

- `/second-review` in opencode threw before prompting, and missed a project-level
  `second-reviewer` agent. It now switches agent through the server.

### Added

- `mise run plugin:update` refreshes the installed plugins from a checkout.
- `mise run release` refuses a version that is already tagged or on npm.

## [0.2.1] - 2026-11-03

### Changed

- First release through the release workflow. npm already held 0.2.0 from a manual
  publish that predates the review overlay and finding snippets.

## [0.2.0] - 2026-11-03

### Added

- The `review` and `second-review` skills, the `code-reviewer` agent, and the
  `opencode-zerodahero` npm package with the `/second-review` command.
- The opt-in `zerodahero-plan-capture` plugin, at its own version 0.1.0. It copies every
  approved plan into `.claude/plan/`.

## [0.1.0] - 2026-11-03

### Added

- The `zerodahero` marketplace and the `zerodahero-skills` plugin, with the `glossary`
  skill.
