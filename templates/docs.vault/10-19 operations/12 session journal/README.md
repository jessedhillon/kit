# Session journal

Per-session notes written by the agent throughout a working session. The journal persists context across sessions and helps future agents pick up where previous ones left off.

## File path

```
docs.vault/10-19 operations/12 session journal/{date}_{session_id}.md
```

- `{date}` is the ISO date, e.g. `2026-04-20`
- `{session_id}` is the short (8-char) prefix of the agent's session ID

To find the session ID: look for the most recently modified `.jsonl` file in `.state/claude/projects/` for this project.

## Format

```markdown
---
description: session journal — {date} ({short_id})
session_id: {full_session_id}
date: {YYYY-MM-DD}
branch: {current_branch}
---

## Decisions

- What was decided and why

## Learnings

- What was learned and where/how it came up

## Action Items

- What needs to be done and any relevant context

## Key Exchanges

- One-sentence summary of an exchange and its outcome
```

Omit empty sections.

## Authoring guidance

- Create the journal early in the session and append as work progresses — don't wait until the end.
- Keep entries terse; a bullet should fit on one line where possible.
- The journal is not a diary — it's a handoff document for the next agent (or the same one after a compaction). Focus on things a future reader would need to know.
- A `PreCompact` hook may run before context compaction and append additional findings from the transcript.

## Scope and orphaned changes

Journals and vault updates are always in scope for the current change. Capture
durable decisions promptly and review orphaned documentation changes from earlier
sessions before including them. Explain their inclusion in the review description.
