---
name: support-admin-apm-trace-get
description: Get a full APM trace by trace ID from a customer org via support-admin Chrome JS. Use when asked to get trace details, show trace, inspect trace, view trace waterfall, or debug a specific trace.
kanban: true
kanban_columns: investigation
---

# APM Trace Get (via Support Admin)

## ℹ️ Implementation Note

Support-admin has no direct trace-by-ID endpoint. This command searches for
spans matching `trace_id:<id>` via the spans search API with progressive
time windows (15min → 1h → 24h). If the trace is older than 24h or has
expired from retention, it won't be found.

## Prerequisites

- **macOS** with `osascript`
- **Google Chrome** running with **"Allow JavaScript from Apple Events"** enabled
- **Two tabs open in Chrome:**
  1. `datadog.zendesk.com` (any page — for AI opt-out check)
  2. `support-admin.us1.prod.dog` (authenticated, switched to the correct customer org)

## When This Skill is Activated

Triggers on: "get trace", "show trace", "trace details", "inspect trace", "trace waterfall", "get trace by ID", "view trace"

## Execution Flow

### Phase 0: AI Compliance Check (MANDATORY — DO NOT SKIP)

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

Check the output for `ai_optout:true`. If found:
> **STOP IMMEDIATELY.** This org has opted out of AI assistance. Do NOT proceed. Inform the user.

### Phase 1: Verify Support Admin Session

```bash
~/.cursor/skills/_shared/support-admin-api.sh auth
```

- `OK` → proceed
- `AUTH_REQUIRED` → ask user to log in at https://support-admin.us1.prod.dog

### Phase 2: Confirm Org Context

```bash
~/.cursor/skills/_shared/support-admin-api.sh org
```

Confirm the org matches the customer before pulling trace data.

### Phase 3: Get Trace

```bash
~/.cursor/skills/_shared/support-admin-api.sh trace <trace_id>
```

**Trace ID format**: 32 lowercase hex characters (e.g., `0123456789abcdef0123456789abcdef`) or decimal digits.

**Output format** matches Datadog MCP `get_datadog_trace`:

```
<METADATA>
  <trace_id>abc123</trace_id>
  <span_count>15</span_count>
</METADATA>
<YAML_DATA>
- span_id: def456
  parent_id: ""
  service: web-store
  name: http.request
  resource: GET /api/orders
  type: web
  duration: 245000000
  start: 2026-03-11T10:00:00Z
  status: error
  meta:
    http.method: GET
    http.url: /api/orders
    http.status_code: 500
    error.message: Connection timeout
  metrics:
    _sample_rate: 1
    _top_level: 1
- span_id: ghi789
  parent_id: def456
  service: order-db
  ...
</YAML_DATA>
```

### Phase 4: Analyze & Present

1. Identify the **root span** (no `parent_id`)
2. Build a **service call chain** from parent-child relationships
3. Highlight **error spans** and their error messages
4. Note **slow spans** (highest duration relative to total trace)
5. Present as a structured summary to the user

## Example

```bash
~/.cursor/skills/_shared/support-admin-api.sh trace 0123456789abcdef0123456789abcdef
```
