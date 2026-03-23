---
name: zendesk-ticket-bits-handoff
description: Hand off a Zendesk ticket investigation to Bits AI (Bits CLI) for Datadog-heavy work — logs, traces, metrics, APM, incidents, customer org queries. Use when the user says use Bits, handoff to Bits, investigate with Bits, Bits AI, or when the ticket needs Support Admin/Datadog MCP access in customer org.
kanban: true
kanban_columns: investigation
---

# Hand Off to Bits AI

When a ticket investigation needs **Datadog data in the customer's org** (logs, traces, metrics, APM, incidents, Support Admin), recommend or hand off to **Bits CLI** instead of continuing in Cursor. Bits has full Datadog MCP access, persistent memory, and native incident analysis — better suited for ops/investigation workflows.

**Use Bits when:**
- Ticket needs logs/metrics/traces query in **customer org** (Support Admin)
- Incident analysis with timeline, severity, mitigations
- APM service discovery, trace search, dependency mapping
- Deep Datadog context across multiple products

**Stay in Cursor when:**
- Code changes, sandbox reproduction, file editing
- Internal docs (Confluence, Glean), Zendesk API, flare analysis
- Quick triage, routing, TLDR, info-needed

## How to Use

Just say: **"use Bits for #1234567"** or **"hand off to Bits AI for ZD-1234567"**

## When This Skill is Activated

Triggers on:
- "use Bits for #XYZ" / "hand off to Bits for ZD-XYZ"
- "investigate with Bits" / "Bits AI for ticket #XYZ"
- User asks "should I use Bits for this ticket?"
- Kanban "Continue in Bits" handoff (if wired)

Then:
1. Extract the ticket ID
2. **Run the AI Compliance Check below FIRST**
3. Prepare handoff context and provide the Bits launch command

## AI Compliance Check (MANDATORY — FIRST STEP)

**Before preparing ANY handoff**, check for the `oai_opted_out` tag:

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

If the output contains `ai_optout:true`:
1. **STOP IMMEDIATELY** — do NOT prepare Bits handoff
2. Tell the user: **"Ticket #{TICKET_ID}: AI processing is blocked — customer has opted out of GenAI. Handle manually."**
3. Exit the skill

## Handoff Steps

1. **Read ticket summary** — Use `zd-api.sh read {TICKET_ID}` or Glean to get subject, priority, product, customer org
2. **Build handoff prompt** — One-liner the agent can paste into Bits:
   ```
   Investigate Zendesk ticket #{TICKET_ID}: [subject]. Customer org [org_id if known]. Priority [priority]. Focus on [logs|traces|metrics|incident|APM] in their Datadog org.
   ```
3. **Provide Bits launch command** — Tell the user to run:

   ```bash
   bits -p "Investigate Zendesk ticket #{TICKET_ID}: [subject]. Customer org [org_id]. Focus on [relevant Datadog products]."
   ```

   Or for interactive session:

   ```bash
   bits
   ```

   Then paste the handoff prompt.

4. **Optional** — If `investigations/ZD-{TICKET_ID}.md` exists, include path so Bits can reference it:
   ```
   Context file: investigations/ZD-{TICKET_ID}.md
   ```

## Prerequisites

- **Bits CLI** installed: `brew install --cask datadog/tap/bits`
- **dd-auth** for Datadog OAuth (AppGate required)
- Bits MCP: Datadog, Atlassian (Jira/Confluence) — add via `/mcp add` if needed

See: [Bits CLI (formerly cmd-CLI)](https://datadoghq.atlassian.net/wiki/spaces/ODP/pages/6004998171/Bits-CLI+formerly+known+as+cmd-CLI)

## Output

- Handoff prompt (copy-paste ready)
- Bits launch command
- Path to investigation file if it exists

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
