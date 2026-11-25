---
name: plan-review-fires
tags: [triggering]
runs: 3
max_turns: 4
---

I'm in plan mode and have drafted the plan below. It changes our data model, so before I
read it closely I want it red-teamed by a second reviewer.

## Plan: move benefits to a versioned table

1. Add a `benefit_version` table keyed by `(benefit_id, version)`.
2. Backfill one version per existing `benefit` row.
3. Point the API's reads at the latest version.
4. Drop the mutable columns from `benefit` once reads have moved.
