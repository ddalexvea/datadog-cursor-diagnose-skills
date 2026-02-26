Generate TLDR summaries for all active Zendesk tickets assigned to me.

## Step 1: Fetch all assigned tickets

Run BOTH searches in parallel:

Search 1 — Open tickets:
- Tool: user-glean_ai-code-search
- query: *
- app: zendesk
- dynamic_search_result_filters: assignee:Alexandre VEA|status:open
- exhaustive: true

Search 2 — Pending tickets:
- Tool: user-glean_ai-code-search
- query: *
- app: zendesk
- dynamic_search_result_filters: assignee:Alexandre VEA|status:pending
- exhaustive: true

## Step 2: Read ALL ticket contents in parallel

For ALL tickets found, read them in a single batch:
- Tool: user-glean_ai-code-read_document
- urls: ["https://datadog.zendesk.com/agent/tickets/ID_1", "https://datadog.zendesk.com/agent/tickets/ID_2", ...]

## Step 3: Filter — skip tickets where I haven't responded

For each ticket, scan the conversation for messages from "Alexandre" (case-insensitive).
- If NO message from Alexandre is found → **SKIP** this ticket (newly assigned, not yet answered)
- If at least one message from Alexandre is found → **INCLUDE** in TLDR

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
| #ID | subject | open/pending | ✅ generated |
| #ID | subject | open | ⏭️ skipped (no response) |

## Single ticket mode

If the user asks for a TLDR of a specific ticket (e.g., "tldr ticket #2514617"):
1. Read just that ticket via Glean
2. Generate the TLDR (no filter — always generate even if not responded)
3. Display inline (don't write to file unless asked)
