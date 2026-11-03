# agent-kit

General-purpose agent skills, packaged as a Claude Code plugin.

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

### opencode

Requires opencode 2.2.5 or later. Add the plugin to the `plugins` array in
`~/.config/opencode/opencode.json`:

```json
{
  "plugins": ["opencode-zerodahero"]
}
```

It adds the `second-review` skill and the `/second-review` command. Then install the
`second-reviewer` agent, whose permissions let it write only its report file and run only
read-only shell commands:

```bash
mkdir -p ~/.config/opencode/agents
curl -fsSL -o ~/.config/opencode/agents/second-reviewer.md \
  https://raw.githubusercontent.com/zerodahero/agent-kit/main/opencode/agents/second-reviewer.md
```

opencode plugins cannot add agents, so the agent is a separate file. Without it,
`/second-review` runs in your current agent and the skill's instructions are the only
guard against edits.

### Plan capture (optional)

```text
/plugin install zerodahero-plan-capture@zerodahero
```

Each time you approve a plan, this copies it into `.claude/plan/NNN.md` in the repo and
updates `.claude/plan/current.md`. `/review` and `/second-review` then find the plan
without a path. The folder ignores itself, so it never shows up in `git status`.

## Skills

| Skill | What it does |
| --- | --- |
| `glossary` | Checks the domain terms a branch introduces against the codebase and the glossary, asks you to confirm each word, then renames and records them. |
| `review` | Reviews the branch with the `code-reviewer` agent, merges any second reviews, and triages every finding into should fix, could fix, out of scope, and skip. |
| `second-review` | An independent review from another harness or model. It writes its findings to a file for `/review` to merge. It edits nothing else and runs no tests. |

`glossary` uses [Plannotator](https://github.com/backnotprop/plannotator) for the review
step when it is installed. Without it, the skill asks through Claude Code's question
prompts instead.

## Second review

Run a second opinion from a different harness, model, or provider, then merge it into the
primary review:

1. In opencode (or Codex, or another Claude Code session), run `/second-review`. It
   writes `.claude/plan/second-review-<branch>-<reviewer>.md`.
2. In the session that made the changes, run `/review`. It merges every second review for
   the branch, tags each finding with who raised it, and marks a review stale when the
   branch has moved since.

A second review merges once per commit, so running `/review` again does not repeat it.

## License

MIT. See [LICENSE](LICENSE).
