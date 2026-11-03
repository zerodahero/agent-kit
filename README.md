# agent-kit

General-purpose agent skills by Zack Teska, packaged as a Claude Code plugin.

## Install

In Claude Code:

```text
/plugin marketplace add zerodahero/agent-kit
/plugin install zerodahero-skills@zerodahero
```

Skills appear as `/zerodahero-skills:<skill>`. Typing `/<skill>` autocompletes to them.

### For a team

Add this to a project's `.claude/settings.json` so collaborators are offered the plugin
when they trust the project:

```json
{
  "extraKnownMarketplaces": {
    "zerodahero": {
      "source": { "source": "github", "repo": "zerodahero/agent-kit" }
    }
  },
  "enabledPlugins": {
    "zerodahero-skills@zerodahero": true
  }
}
```

### Other agents

The skills use the standard `SKILL.md` layout, so [skills.sh](https://skills.sh) can copy
them into Codex and other harnesses:

```bash
npx skills add zerodahero/agent-kit
```

## Skills

| Skill | What it does |
| --- | --- |
| `glossary` | Checks the domain terms a branch introduces against the codebase and the glossary, asks you to confirm each word, then renames and records them. |

`glossary` uses [Plannotator](https://github.com/backnotprop/plannotator) for the review
step when it is installed. Without it, the skill asks through Claude Code's question
prompts instead.

## License

MIT. See [LICENSE](LICENSE).
