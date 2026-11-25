// Smoke test for the opencode plugin's prompt. Run with: node --test tests/opencode/
import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

import { buildContent, skillPath, stripFrontmatter } from "../../opencode/content.js"

const method = await readFile(new URL("../../skills/review/second-review/REVIEW-METHOD.md", import.meta.url), "utf8")
const content = await buildContent()

test("skillPath points at the second-review SKILL.md", async () => {
  assert.match(skillPath, /skills\/review\/second-review\/SKILL\.md$/)
  await readFile(skillPath, "utf8")
})

test("the prompt has no frontmatter", () => {
  assert.doesNotMatch(content, /^---\n/)
  assert.doesNotMatch(content, /^name: second-review$/m)
})

test("the link to REVIEW-METHOD.md is replaced", () => {
  assert.match(content, /the Review method section below/)
  assert.doesNotMatch(content, /\]\(REVIEW-METHOD\.md\)/, "a reworded link would leave a dead reference")
})

test("the prompt ends with the full review method", () => {
  assert.ok(content.endsWith(`## Review method\n\n${method}`))
})

test("the prompt keeps the $ARGUMENTS placeholder the command fills in", () => {
  assert.match(content, /\$ARGUMENTS/)
})

test("stripFrontmatter leaves a file without frontmatter alone", () => {
  assert.equal(stripFrontmatter("# Title\n"), "# Title\n")
})
