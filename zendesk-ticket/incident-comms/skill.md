---
name: zendesk-ticket-incident-comms
description: For a ticket linked to a Datadog incident (has tags 'incident' and 'incident_XXXXX'), find the internal Golden Ticket for that incident and extract all customer-facing communications (public comments) from it. Use when the user asks about incident communications, golden ticket, incident updates, what was sent to customers during an incident, or wants to find the comms for an incident-linked ticket.
kanban: true
kanban_columns: triage
---

# Incident Communications Finder

Given a Zendesk ticket that is linked to a Datadog incident, this skill:
1. Detects the incident tag (`incident_XXXXX`) on the ticket
2. Searches for the internal **Golden Ticket** for that incident
3. Extracts all public/customer-facing communications from the Golden Ticket
4. Presents the communications in chronological order, ready to reuse or review

## When This Skill is Activated

Triggers:
- "what are the incident comms for ticket #XYZ"
- "find the golden ticket for #XYZ"
- "show me the incident communications"
- "what was sent to customers during this incident"
- "incident update for ticket #XYZ"
- "get comms from golden ticket"

## How to Use

Say: **"incident comms for ticket #2531965"** or **"find golden ticket for #XYZ"**

The agent will follow `incident-comms-prompt.md`.

## Output Format

```
## Incident: incident_XXXXX
## Golden Ticket: #YYYYYYY — {subject}

### Communication #1 — {timestamp}
{full public comment body}

### Communication #2 — {timestamp}
{full public comment body}

...
```

## Prerequisites

- `~/.cursor/skills/_shared/zd-api.sh` available and working
- Zendesk tab open in Chrome (required by `zd-api.sh` internally)

## AI Compliance Check (MANDATORY)

Before reading any ticket content, check for the `oai_opted_out` tag:
```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

If the output contains `ai_optout:true`:
- **SKIP** — do NOT read or display its content
- Output: `[AI BLOCKED — customer opted out of GenAI]`

This is a legal/compliance requirement. No exceptions.
