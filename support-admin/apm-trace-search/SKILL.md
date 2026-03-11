---
name: support-admin-apm-trace-search
description: Search APM traces and spans in a customer org via support-admin Chrome JS. Use when asked to search traces, search spans, find APM errors, list slow requests, or investigate APM issues in a customer org.
kanban: true
kanban_columns: investigation
---

# APM Trace Search (via Support Admin)

## Prerequisites

- **macOS** with `osascript`
- **Google Chrome** running with **"Allow JavaScript from Apple Events"** enabled
- **Two tabs open in Chrome:**
  1. `datadog.zendesk.com` (any page — for AI opt-out check)
  2. `support-admin.us1.prod.dog` (authenticated, switched to the correct customer org)

## When This Skill is Activated

Triggers on: "search traces", "search spans", "find traces", "APM search", "span search", "find slow requests", "find errors in APM", "trace search in customer org"

## Execution Flow

### Phase 0: AI Compliance Check (MANDATORY — DO NOT SKIP)

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

Check the output for `ai_optout:true`. If found:
> **STOP IMMEDIATELY.** This org has opted out of AI assistance. Do NOT proceed with any data query. Inform the user: "This org has opted out of AI tooling. Cannot run APM queries."

If no ticket ID is available, ask the user to provide one before proceeding.

### Phase 1: Verify Support Admin Session

```bash
~/.cursor/skills/_shared/support-admin-api.sh auth
```

- If `OK` → proceed
- If `AUTH_REQUIRED` → tell user: "Please open https://support-admin.us1.prod.dog in Chrome, log in, and switch to the correct customer org, then re-run."
- If `ERROR:` → report the error

### Phase 2: Confirm Org Context

```bash
~/.cursor/skills/_shared/support-admin-api.sh org
```

Report the org to the user and confirm it matches the expected customer before querying data.

### Phase 3: Search Spans

```bash
~/.cursor/skills/_shared/support-admin-api.sh spans "<query>" [from] [to]
```

**Query syntax** follows Datadog search syntax:
- `service:web-store` — filter by service
- `resource_name:GET /api/orders` — filter by resource
- `status:error` — only errors
- `env:production` — filter by environment
- `@http.status_code:[400 TO 499]` — attribute ranges
- `service:web-store status:error` — combine filters (AND is implicit)
- `service:(web OR api)` — OR syntax
- `@duration:>5000000000` — duration > 5s (in nanoseconds)

**Time range** (optional):
- Default: last 1 hour
- Formats: `now-15m`, `now-1h`, `now-1d`, epoch seconds

**Output format** matches Datadog MCP `search_datadog_spans`:

```
<METADATA>
  <count>N</count>
</METADATA>
<YAML_DATA>
- trace_id: abc123
  span_id: def456
  service: web-store
  resource_name: GET /api/orders
  name: http.request
  type: web
  duration: 245000000
  start: 2026-03-11T10:00:00Z
  status: error
  meta:
    http.status_code: 500
    error.type: TimeoutError
    ...
</YAML_DATA>
```

### Phase 4: Present Results

Format the results for the user. If the user needs more detail on a specific trace, use the `support-admin-apm-trace-get` skill with the `trace_id`.

## Examples

```bash
# Errors in web-store service, last 15 minutes
~/.cursor/skills/_shared/support-admin-api.sh spans "service:web-store status:error" now-15m now

# Slow requests (>5s) in production
~/.cursor/skills/_shared/support-admin-api.sh spans "env:production @duration:>5000000000" now-1h now

# All spans for a specific resource
~/.cursor/skills/_shared/support-admin-api.sh spans "resource_name:POST /api/checkout" now-30m now
```
