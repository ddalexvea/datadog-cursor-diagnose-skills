Generate TLDR summaries for all active Zendesk tickets assigned to me.

## Step 1: Fetch all assigned tickets

### Primary: Chrome JS (real-time)

Run ALL searches:
```bash
~/.cursor/skills/_shared/zd-api.sh search "type:ticket assignee:me (status:new OR status:open)"
~/.cursor/skills/_shared/zd-api.sh search "type:ticket assignee:me status:pending"
~/.cursor/skills/_shared/zd-api.sh search "type:ticket assignee:me status:hold"
```

Output includes: ID | status | priority | product | tier | complexity | replies | updated | subject

### Fallback: Glean MCP

If Chrome is unavailable, first resolve your name:
```bash
AGENT_NAME=$(~/.cursor/skills/_shared/zd-api.sh me | cut -d'|' -f2 | xargs)
```

Search 1 — Open tickets:
- Tool: user-glean_ai-code-search
- query: *
- app: zendesk
- dynamic_search_result_filters: assignee:{AGENT_NAME}|status:open
- exhaustive: true

Search 2 — Pending tickets:
- Tool: user-glean_ai-code-search
- query: *
- app: zendesk
- dynamic_search_result_filters: assignee:{AGENT_NAME}|status:pending
- exhaustive: true

Search 3 — On-hold tickets (TSE on hold, Eng on hold, etc.):
- Tool: user-glean_ai-code-search
- query: *
- app: zendesk
- dynamic_search_result_filters: assignee:{AGENT_NAME}|status:hold
- exhaustive: true

**Note:** Glean data may be up to 30 minutes stale.

## Step 1b: AI Compliance Check (MANDATORY)

For each ticket found, check for the `oai_opted_out` tag:

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

If the output contains `ai_optout:true`:
- **SKIP this ticket entirely** — do NOT read its content or generate a summary
- In the output file, add: `## ZD-{TICKET_ID}: [AI BLOCKED — customer opted out of GenAI]`
- Continue to next ticket

This is a legal/compliance requirement. No exceptions.

## Step 2: Read ALL ticket contents

### Primary: Chrome JS

For each ticket (that passed the AI Compliance Check), read metadata + comments and check if replied:
```bash
~/.cursor/skills/_shared/zd-api.sh read {TICKET_ID}
~/.cursor/skills/_shared/zd-api.sh replied {TICKET_ID}
```

Default 500 chars/comment is usually enough for TLDR. Use `0` for full body if needed.

### Fallback: Glean MCP

If Chrome is unavailable, read all tickets in a single batch:
- Tool: user-glean_ai-code-read_document
- urls: ["https://datadog.zendesk.com/agent/tickets/ID_1", "https://datadog.zendesk.com/agent/tickets/ID_2", ...]

## Step 3: Filter — skip tickets where I haven't responded

- `ai_optout:true` → **SKIP** this ticket (AI BLOCKED — see Step 1b)
- `NOT_REPLIED` → **SKIP** this ticket (newly assigned, not yet answered)
- `REPLIED` → **INCLUDE** in TLDR

For Glean fallback: scan the conversation for messages from `AGENT_NAME` (resolved via `zd-api.sh me` above).

## Step 3b: Check existing investigation files

For each included ticket, check if an investigation file exists:

```bash
ls investigations/ZD-{TICKET_ID}.md 2>/dev/null
```

If the file exists, read it to enrich the TLDR. Key sections:
- `## Ticket Summary` — verified metadata
- `## Timeline` — investigation findings, similar tickets, docs found
- `## Customer Response Draft` — shows what response is ready to send
- `## Review History` — TSE feedback and agent revisions (shows back-and-forth count)
- `## Investigation Decision` / `## Triage Decision` — current routing and reason
- `## Chat TLDR` — summary from interactive chat sessions (merge into your TLDR)

Use this data to produce a more accurate TLDR than ticket comments alone. The investigation file reflects the current state of work, not just the ticket conversation.

## Step 4: Generate TLDR for each included ticket

For each ticket, write a TLDR following this exact template:

```
## ZD-{ID}: {SUBJECT}
**Status:** {open/pending/on hold} | **Priority:** {priority} | **Customer:** {org name}

**Description of Customer's Issue:**
{Summarize what the customer is experiencing. Include context like what they were doing, what product/feature is involved, and any relevant background. Reference screenshots or attachments by name if mentioned in the ticket, e.g. (screenshot - filename.png)}

**Issues/Concerns:**
{What specific blockers or errors the customer is facing. What are they worried about.}

**Investigation:**
{What has been done so far — error logs found, config checked, calls done, tests attempted. Include actual error messages or log excerpts if present in the ticket. Structure chronologically if multiple investigation steps were done.}

**Important links/attachments:**
{List any KB articles, doc links, flare references, screenshots, or commands shared in the ticket. Use actual URLs when available.}

**Next steps:**
{What needs to happen next — waiting for customer info, need to ask in Slack, escalation needed, call scheduled, etc.}

**Need from Customer:**
{What specific information or action is required from the customer before we can proceed. Be explicit — list numbered items if multiple things are needed.}
```

### Writing guidelines:
- Be factual — only include what's actually in the ticket
- Include actual error messages and log excerpts when present
- Reference screenshots/attachments by their filename when mentioned
- Reference links with actual URLs (KB, docs, Slack, etc.)
- Note if a call was done and summarize outcomes
- Keep it concise but complete — someone reading this should understand the full state
- If a section has nothing relevant, write "N/A" instead of making things up

## Step 5: Write the output file

Write ALL TLDRs to `investigations/TLDR-all.md` with this header:

```markdown
# Ticket TLDR — Generated {CURRENT_DATE}

> {X} tickets summarized / {Y} skipped (no response yet)

---
```

Then append each ticket TLDR separated by `---`.

## Step 6: Display summary

After writing the file, display a brief table:

| Ticket | Subject | Status | TLDR |
|--------|---------|--------|------|
| #ID | subject | open/pending/hold | generated |
| #ID | subject | open | skipped (no response) |

## Single ticket mode

If the user asks for a TLDR of a specific ticket (e.g., "tldr ticket #1234567"):
1. Read just that ticket: `~/.cursor/skills/_shared/zd-api.sh read {TICKET_ID} 0`
2. Generate the TLDR (no filter — always generate even if not responded)
3. Display inline (don't write to file unless asked)
