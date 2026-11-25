# Changelog

Every release ships the `zerodahero-skills` and `zerodahero-plan-capture` plugins and the
`opencode-zerodahero` npm package at one version.

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
