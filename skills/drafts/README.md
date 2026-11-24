# Drafts

Skills in progress. They are not listed in `.claude-plugin/plugin.json`, so they do not
ship with the plugin. Move a skill to a shipped bucket and add it to the `skills` list when
it is ready.

To try a draft in any repo, link it into your personal skills:

```bash
ln -s "$PWD/skills/drafts/<skill>" ~/.claude/skills/<skill>
```

`claude --plugin-dir .` does not load drafts, because it reads the same `skills` list.
