---
name: zendesk-ticket-pool
description: Check and display the current Zendesk ticket pool assigned to the user using Glean MCP. Use when the user asks about their ticket queue, open tickets, pending tickets, ticket pool, ticket status, workload, or wants to see what tickets need attention. This skill should be used proactively at the start of conversations when working in the TSE workspace.
---

# Zendesk Ticket Pool Checker

## Instructions

### Step 1: Fetch Assigned Tickets

Run **two parallel** Glean searches to get all active tickets assigned to the user:

**Search 1 - Open tickets:**
```
Tool: user-glean_ai-code-search
query: *
app: zendesk
dynamic_search_result_filters: assignee:Alexandre VEA|status:open
exhaustive: true
```

**Search 2 - Pending tickets:**
```
Tool: user-glean_ai-code-search
query: *
app: zendesk
dynamic_search_result_filters: assignee:Alexandre VEA|status:pending
exhaustive: true
```

### Step 2: Parse Ticket Data

From each result, extract:

| Field | Source |
|-------|--------|
| Ticket ID | URL path (e.g. `2511079` from URL) |
| Subject | `title` |
| Status | `matchingFilters.status[0]` |
| Priority | `matchingFilters.priority[0]` |
| Critical | `matchingFilters.critical[0]` |
| Customer | `matchingFilters.datadogorgname[0]` |
| Product | `matchingFilters.producttype[0]` (use readable name, not tag) |
| Complexity | `matchingFilters.ticketcomplexity` (use readable name) |
| Tier | `matchingFilters.tier` (use value like "0","1","2","3" or "N/A") |
| MRR | `matchingFilters.mrrbucket` (use readable name) |
| Top75 | `matchingFilters.top75org[0]` |
| Replies | Check `matchingFilters.label` for tags: `5_agent_replies`, `10_agent_replies`, `15_agent_replies`, `20_agent_replies`. Use the highest matching value. |
| Follow-up | Detect if ticket is a follow-up (see follow-up detection below) |
| Parent Ticket | If follow-up, extract the parent ticket ID |
| Created | `createTime` |
| Updated | `updateTime` |
| Wait Time | Compute elapsed time between `updateTime` and now |

### Follow-up Detection

A ticket is a **follow-up** when any of these are true:
1. Title starts with `Re:` (e.g. "Re: SCS-Datadog-EMEA asked for support!")
2. Snippets contain `follow-up to your previous request #XXXXXX`
3. Snippets contain `This is a follow-up to your previous request`

When a follow-up is detected:
- Extract the **parent ticket ID** from the text (e.g. `#2386180` -> `2386180`)
- Mark the ticket with a "Follow-up" indicator in the table
- Note that **reply counts on follow-ups reflect the cumulative history** across all linked tickets, not just the current one
- Link the parent ticket in the output: `[#parentID](https://datadog.zendesk.com/agent/tickets/parentID)`

### Step 3: Present Results

#### Summary

```
## Ticket Pool - [Date]

**Open:** X | **Pending:** Y | **Total: X+Y**
```

#### Table (sorted by priority score desc, then last update)

| # | Ticket | Subject | Status | Priority | Customer | Product | Replies | Tier | Updated | Notes |
|---|--------|---------|--------|----------|----------|---------|---------|------|---------|-------|

- Link ticket IDs: `[#ID](https://datadog.zendesk.com/agent/tickets/ID)`
- Truncate subjects to ~50 chars
- Show relative time for Updated (e.g. "2h ago", "1d ago")
- Flag critical tickets with an indicator
- In the Notes column, show:
  - "Follow-up from [#parentID](link)" if it's a follow-up
  - "Critical" if critical:true
  - Leave empty otherwise

#### Attention Required

After the main table, if any tickets match BOTH conditions below, display them in a separate highlighted section:
- **Waiting > 24h** (elapsed time since `updateTime` exceeds 24 hours)
- **10+ back-and-forth** (label contains `10_agent_replies`, `15_agent_replies`, or `20_agent_replies`)

Format:

```
### Attention Required - Stale & High-Touch Tickets

These tickets have been waiting over 24h AND have 10+ exchanges:

| Ticket | Subject | Status | Customer | Replies | Waiting Since |
|--------|---------|--------|----------|---------|---------------|
```

If no tickets match both conditions, skip this section entirely.

#### Action Items

After the table, list:
1. **Needs Response** - Open tickets waiting for agent reply
2. **SLA Risk** - Critical or high-priority tickets with stale updates
3. **Pending Bump** - Pending tickets that may need customer follow-up
4. **High-Touch Stale** - Tickets with 10+ replies AND waiting > 24h (from the Attention Required section above)

### Deep Dive

If asked about a specific ticket, use `user-glean_ai-code-read_document` with the ticket URL.

## Filtering

Combine filters with `|` in `dynamic_search_result_filters`:
- Priority: `priority:high`
- Critical: `critical:true`
- Product: `producttype:Agent`
- Customer: `customer:<name>`
- Top 75: `top75org:true`
