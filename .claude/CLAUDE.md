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
- Skill text follows the writing-for-agents conventions.
- `agents/code-reviewer.md` and `skills/review/second-review/REVIEW-METHOD.md` share one
  body. Edit both. `scripts/check-review-method.sh` checks them, and CI runs it.
- `opencode/plugin.js` builds the opencode `second-review` skill and `/second-review`
  command from the `second-review` skill files at startup. A change to those files
  reaches opencode as is. opencode plugins cannot add agents, so
  `opencode/agents/second-reviewer.md` ships as a file users install themselves.

## Development

- An install from the local marketplace runs from a cached copy in
  `~/.claude/plugins/cache/`, pinned to the installed version and commit. Edits in this
  checkout do not reach it.
- To test edits, start a session with `claude --plugin-dir .` from the repo root.
- `mise run plugin:update` refreshes the installed copy from this checkout's current
  branch. `zerodahero-skills` updates only on a version bump. `zerodahero-plan-capture`
  is read live from `plugins/plan-capture/`, so a `/reload-plugins` picks up its edits.
- `mise.toml` pins Node and every lint tool. CI reads the same file through
  `jdx/mise-action`.
- `hk.pkl` defines the checks. Run `hk install` once per clone so pre-commit runs them
  and stages their fixes. `hk check --all` runs everything, and CI runs the same.
- Pin every GitHub Action to a full commit SHA with its version as a comment. `pinact`
  and `zizmor` enforce this.

## Releases

- To release, bump `version` in both `.claude-plugin/plugin.json` and `package.json`, and
  tag the commit `zerodahero-skills--v<version>`. Installed users get no update until the
  version changes. `scripts/check-versions.sh` fails when the two versions differ. The
  tag triggers `release.yml`, which publishes the opencode plugin to npm through npm
  trusted publishing. There is no npm token. Renaming `release.yml` breaks publishing
  until the trusted publisher on npmjs.com is updated to match.
- `zerodahero-plan-capture` in `plugins/plan-capture/` versions on its own. Tag its
  releases `zerodahero-plan-capture--v<version>`.
- A renamed or removed skill is a major bump.
- Before you push, run `hk check --all`, `claude plugin validate . --strict`, and
  `claude plugin validate plugins/plan-capture --strict`. CI runs the same checks.
