// opencode v2 plugin: registers the second-review skill and the /second-review command.
// Both are built from the skill files in this package, so the skill stays the single
// source for what the reviewer does. The second-reviewer agent ships separately as
// opencode/agents/second-reviewer.md, because plugins cannot add agents.
import { readFile } from "node:fs/promises"
import { fileURLToPath } from "node:url"
import { Plugin, Skill } from "@opencode/plugin"

const skillDir = new URL("../skills/review/second-review/", import.meta.url)
const skillPath = fileURLToPath(new URL("SKILL.md", skillDir))

const description =
  "Review this branch as an independent second reviewer and write the findings to a file for the primary agent"

function stripFrontmatter(text) {
  return text.replace(/^---\n[\s\S]*?\n---\n+/, "")
}

// The SKILL.md body with REVIEW-METHOD.md appended, so one prompt carries everything.
async function buildContent() {
  const [skill, method] = await Promise.all([
    readFile(new URL("SKILL.md", skillDir), "utf8"),
    readFile(new URL("REVIEW-METHOD.md", skillDir), "utf8"),
  ])
  const body = stripFrontmatter(skill).replaceAll(
    "[REVIEW-METHOD.md](REVIEW-METHOD.md)",
    "the Review method section below",
  )
  return `${body.trimEnd()}\n\n## Review method\n\n${method}`
}

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
