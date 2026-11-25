// Builds the second-review prompt from the skill files in this package, so the skill stays
// the single source for what the reviewer does. Kept apart from plugin.js so tests can load
// it without @opencode/plugin installed.
import { readFile } from "node:fs/promises"
import { fileURLToPath } from "node:url"

const skillDir = new URL("../skills/review/second-review/", import.meta.url)

export const skillPath = fileURLToPath(new URL("SKILL.md", skillDir))

export function stripFrontmatter(text) {
  return text.replace(/^---\n[\s\S]*?\n---\n+/, "")
}

// The SKILL.md body with REVIEW-METHOD.md appended, so one prompt carries everything.
export async function buildContent() {
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
