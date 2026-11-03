# agent-kit

This repo is the `zerodahero` marketplace. It ships one Claude Code plugin,
`zerodahero-skills`, from the repo root.

## Skills

- Skills live in `skills/<bucket>/<skill>/SKILL.md`. Supporting files sit beside `SKILL.md`.
- Every shipped skill has an entry in the `skills` list in `.claude-plugin/plugin.json`.
  The plugin ships only what that list names.
- Drafts live in `skills/drafts/` and stay out of the `skills` list.
- Every skill directory has `agents/openai.yaml` with `interface.display_name` and a
  `short_description` under 60 characters. Codex and skills.sh read it.
- Skill text follows the writing-for-agents conventions.

## Releases

- To release, bump `version` in `.claude-plugin/plugin.json` and tag the commit
  `zerodahero-skills--v<version>`. Installed users get no update until the version changes.
- A renamed or removed skill is a major bump.
- Run `claude plugin validate . --strict` before you push. CI runs the same check.
