// opencode v2 plugin: registers the second-review skill and the /second-review command.
// content.js builds both from the skill files in this package. The second-reviewer agent
// ships separately as opencode/agents/second-reviewer.md, because plugins cannot add
// agents.
import { Plugin, Skill } from "@opencode/plugin"
import { buildContent, skillPath } from "./content.js"

const description =
  "Review this branch as an independent second reviewer and write the findings to a file for the primary agent"

export default Plugin.define({
  id: "zerodahero.second-review",
  async setup(ctx) {
    const content = await buildContent()

    await ctx.skill.transform((editor) => {
      if (editor.get("second-review")) return
      editor.add({
        id: Skill.ID.make("second-review"),
        name: Skill.Name.make("second-review"),
        description,
        autoinvoke: false,
        path: skillPath,
        content,
      })
    })

    await ctx.command.transform((editor) => {
      editor.add({
        name: "second-review",
        description,
        async execute({ sessionID, prompt }) {
          const args = (prompt?.text ?? "").trim()
          // The server resolves the agent in the session's own project, so a global or a
          // project-level second-reviewer both work. Without one, stay on the current agent.
          try {
            await ctx.session.switchAgent({ sessionID, agent: "second-reviewer" })
          } catch {}
          await ctx.session.prompt({
            sessionID,
            text: content.replaceAll("$ARGUMENTS", args || "(none)"),
          })
        },
      })
    })
  },
})
