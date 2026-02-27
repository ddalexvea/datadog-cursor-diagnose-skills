---
name: zendesk-ticket-tldr
description: Generate TLDR summaries for all assigned tickets (open, pending, on hold) where you have already responded. Use when the user asks for ticket summaries, TLDR, status update, standup notes, or handoff notes.
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

## Filter Logic

- **Include:** tickets with status open, pending, or on hold assigned to you
- **Exclude:** tickets where you have NOT yet posted any public reply (newly assigned, untouched)
- **How to detect:** Read ticket content via Glean — if no message from "Alexandre" is found in the conversation, skip it

## Integration

Works standalone or alongside:
- `zendesk-ticket-watcher` — watcher detects, TLDR summarizes
- `zendesk-ticket-pool` — pool shows the list, TLDR gives depth
