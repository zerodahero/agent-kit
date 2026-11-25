# agent-kit

This repo is the `zerodahero` marketplace. It ships two Claude Code plugins:
`zerodahero-skills` from the repo root, and the opt-in `zerodahero-plan-capture` from
`plugins/plan-capture/`. The root `package.json` and `opencode/plugin.js` also make the
repo an opencode v2 plugin, published to npm as `opencode-zerodahero`.

## Skills

- Skills live in `skills/<bucket>/<skill>/SKILL.md`. Supporting files sit beside `SKILL.md`.
- Every shipped skill has an entry in the `skills` list in `.claude-plugin/plugin.json`.
  The plugin ships only what that list names.
- Drafts live in `skills/drafts/` and stay out of the `skills` list.
- Every skill directory has `agents/openai.yaml` with `interface.display_name` and a
  `short_description` under 60 characters. Codex and skills.sh read it.
- `scripts/check-skills.sh` checks the `skills` list and every `openai.yaml`.
- `evals/` holds skill-triggering evals. `mise run eval` runs them locally, calls the
  model, and costs about $1. CI does not run them. Add a case when a skill's
  `description` or `disable-model-invocation` changes.
- Skill text follows the writing-for-agents conventions.
- Output styles live in `output-styles/<name>.md`. The plugin ships every file there
  through the default scan, so `plugin.json` has no `outputStyles` key.
- `agents/code-reviewer.md` and `skills/review/second-review/REVIEW-METHOD.md` share one
  body. Edit both. `scripts/check-review-method.sh` checks them, and CI runs it.
- `opencode/plugin.js` builds the opencode `second-review` skill and `/second-review`
  command from the `second-review` skill files at startup. A change to those files
  reaches opencode as is. opencode plugins cannot add agents, so
  `opencode/agents/second-reviewer.md` ships as a file users install themselves.
  `tests/opencode/` tests the prompt that `opencode/content.js` builds.
- The opencode agents `plan-reviewer.md` and `second-reviewer.md` share one read-only
  shell policy, in the V2 `permissions` list. Change both.
  `scripts/check-opencode-agents.sh` checks them, and lists the rules only one agent
  needs.

## Development

- An install from the local marketplace runs from a cached copy in
  `~/.claude/plugins/cache/`, pinned to the installed version and commit. Edits in this
  checkout do not reach it.
- To test edits, start a session with `claude --plugin-dir .` from the repo root.
- `mise run plugin:update` refreshes the installed copy from this checkout's current
  branch. `zerodahero-skills` updates only on a version bump. `zerodahero-plan-capture`
  is read live from `plugins/plan-capture/`, so a `/reload-plugins` picks up its edits.
- `mise.toml` pins Node, Python, uv, and every lint tool. CI reads the same file through
  `jdx/mise-action`. Renovate keeps the pins current.
- `hk.pkl` defines the checks, including ruff, rumdl, and pytest through
  `uv run --frozen pytest`. Run `hk install` once per clone, and again after a hook is
  added, so pre-commit runs the checks and commit-msg checks the message.
  `hk check --all` runs everything, and CI runs the same.
- Commit messages and PR titles follow Conventional Commits. PRs are squash-merged, so
  the PR title becomes the commit on `main` and its changelog line. CI checks the title.
- Pin every GitHub Action to a full commit SHA with its version as a comment. `pinact`
  and `zizmor` enforce this.

## Releases

- Both plugins and the npm package release together at one version.
  `scripts/check-versions.sh` fails when `package.json`, `.claude-plugin/plugin.json`,
  or `plugins/plan-capture/.claude-plugin/plugin.json` differ.
- To release, run `mise run release:prepare <version>`. It sets every manifest and
  prepends a git-cliff entry to `CHANGELOG.md`. Edit the entry, and merge it in a PR
  titled `chore(release): <version>`. Then run `mise run release <version>` on an
  up-to-date `main`. It refuses a version that is already tagged, already on npm, or
  missing from `CHANGELOG.md`, then pushes the tag `v<version>`. Tags before 0.7.0 are
  `zerodahero-skills--v<version>`.
- Installed users get no update until the version changes.
- The tag triggers `release.yml`. It publishes the opencode plugin to npm through npm
  trusted publishing, then creates the GitHub release from the `CHANGELOG.md` entry.
  There is no npm token. Renaming `release.yml` breaks publishing until the trusted
  publisher on npmjs.com is updated to match.
- A renamed or removed skill is a major bump.
- Before you push, run `hk check --all`, `claude plugin validate . --strict`, and
  `claude plugin validate plugins/plan-capture --strict`. CI runs the same checks.
