---
name: zendesk-ticket-tldr
description: Generate TLDR summaries for all assigned tickets (open, pending, on hold) where you have already responded. Uses Chrome JS (real-time) as primary, Glean MCP as fallback. Use when the user asks for ticket summaries, TLDR, status update, standup notes, or handoff notes.
---

# Ticket TLDR Generator

Generates structured TLDR summaries for all your active Zendesk tickets. Only summarizes tickets where you have already posted a response — skips newly assigned tickets you haven't answered yet.
## When This Skill is Activated

Triggers: "tldr my tickets", "ticket summaries", "standup notes", "status update", "summarize my tickets", "handoff notes"

## How to Use

1. Say **"tldr my tickets"** in any agent chat
2. The agent reads this skill, follows `tldr-prompt.md`
3. Outputs a TLDR per ticket to `investigations/TLDR-all.md` (single file, all tickets)

For a single ticket: **"tldr ticket #XYZ"**

## Output

| File | Purpose |
|------|---------|
| `investigations/TLDR-all.md` | All active ticket TLDRs in one file |

## TLDR Template

Each ticket TLDR follows this structure:

```
## ZD-{ID}: {SUBJECT}

**Description of Customer's Issue:**
What the customer is experiencing, context, and background.

**Issues/Concerns:**
Specific blockers, errors, or customer concerns.

**Investigation:**
What has been found so far — error logs, config issues, test results, call notes.

**Important links/attachments:**
KB articles, screenshots, commands shared, flare references.

**Next steps:**
What needs to happen next — waiting on customer, escalation, team question.

**Need from Customer:**
What information or action is needed from the customer before proceeding.
```

## Prerequisites

- **macOS** with `osascript`
- **Google Chrome** running with a tab open on `zendesk.com`
- **"Allow JavaScript from Apple Events"** enabled in Chrome (one-time setup)

## AI Compliance Check (MANDATORY)

For each ticket, before generating a TLDR summary, check for the `oai_opted_out` tag:

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

If the output contains `ai_optout:true`:
- **SKIP this ticket entirely** — do NOT read its content or generate a summary
- In the output file, add a line: `## ZD-{TICKET_ID}: [AI BLOCKED — customer opted out of GenAI]`
- Do NOT include any ticket content, subject details, or analysis

This is a legal/compliance requirement. No exceptions.

## Filter Logic

- **Include:** tickets with status new, open, pending, or hold (on-hold TSE / on-hold Eng) assigned to you
- **Exclude:** tickets where you have NOT yet posted any public reply (newly assigned, untouched)
- **Exclude:** tickets with `ai_optout:true` tag (customer opted out of GenAI — see AI Compliance Check above)
- **How to detect:** Check ticket comments via Chrome JS (primary) or Glean (fallback) — if no message from the current user is found, skip it

## Integration

Works standalone or alongside:
- `zendesk-ticket-watcher` — watcher detects, TLDR summarizes
- `zendesk-ticket-pool` — pool shows the list, TLDR gives depth
