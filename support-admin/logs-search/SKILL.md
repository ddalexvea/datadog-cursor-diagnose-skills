---
name: support-admin-logs-search
description: Search logs in a customer org via support-admin Chrome JS. Use when asked to search logs, find log errors, check log entries, investigate log patterns, or query logs in a customer org.
kanban: true
kanban_columns: investigation
---

# Logs Search (via Support Admin)

## ⚠️ Known Limitation

Support-admin blocks the logs search API endpoints (returns HTTP 401 on both GET
and POST). The `logs` command will attempt the query but will likely return a
`NOT_AVAILABLE` message with a list of available log indexes.

**Workarounds:**
- Use the **Datadog MCP** `search_datadog_logs` tool instead (requires the org
  to be in the Datadog Demo account)
- Navigate to **Logs Explorer** in the support-admin UI manually
- Use the `logs` command output to confirm which log indexes exist for the org

## Prerequisites

- **macOS** with `osascript`
- **Google Chrome** running with **"Allow JavaScript from Apple Events"** enabled
- **Two tabs open in Chrome:**
  1. `datadog.zendesk.com` (any page — for AI opt-out check)
  2. `support-admin.us1.prod.dog` (authenticated, switched to the correct customer org)

## When This Skill is Activated

Triggers on: "search logs", "find logs", "log search", "check logs", "log errors", "query logs"

## Execution Flow

### Phase 0: AI Compliance Check (MANDATORY — DO NOT SKIP)

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

Check for `ai_optout:true` → STOP if found.

### Phase 1: Verify Support Admin Session

```bash
~/.cursor/skills/_shared/support-admin-api.sh auth
```

### Phase 2: Confirm Org Context

```bash
~/.cursor/skills/_shared/support-admin-api.sh org
```

### Phase 3: Search Logs

```bash
~/.cursor/skills/_shared/support-admin-api.sh logs "<query>" [from] [to]
```

**Query syntax** follows Datadog log search syntax:
- `service:nginx` — filter by service
- `status:error` — filter by log status
- `host:prod-web-01` — filter by host
- `@http.status_code:[400 TO 499]` — attribute ranges
- `service:nginx status:error` — combine filters (AND implicit)
- `"connection refused"` — exact phrase match
- `source:docker` — filter by log source
- `env:production` — filter by environment

**Time range** (optional):
- Default: last 1 hour
- Formats: `now-15m`, `now-1h`, `now-1d`, epoch seconds

**Output format** matches Datadog MCP `search_datadog_logs`:

```
<METADATA>
  <displayed_items>50</displayed_items>
  <count>50</count>
</METADATA>
<TSV_DATA>
timestamp	host	service	status	message
2026-03-11T10:00:00Z	prod-web-01	nginx	error	upstream timed out (110: Connection timed out)
2026-03-11T09:59:45Z	prod-web-01	nginx	error	connect() failed (111: Connection refused)
</TSV_DATA>
```

### Phase 4: Present Results

Format the TSV as a readable table for the user. Highlight patterns (recurring errors, specific hosts, time clusters).

## Examples

```bash
# Errors in nginx, last 15 minutes
~/.cursor/skills/_shared/support-admin-api.sh logs "service:nginx status:error" now-15m now

# All logs from a specific host, last hour
~/.cursor/skills/_shared/support-admin-api.sh logs "host:prod-web-01" now-1h now

# Logs containing a specific error message
~/.cursor/skills/_shared/support-admin-api.sh logs "\"connection refused\"" now-30m now

# Agent logs with specific source
~/.cursor/skills/_shared/support-admin-api.sh logs "source:agent status:error" now-1h now
```
