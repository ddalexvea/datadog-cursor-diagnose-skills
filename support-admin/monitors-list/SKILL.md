---
name: support-admin-monitors-list
description: List and search monitors in a customer org via support-admin Chrome JS. Use when asked to list monitors, check monitor status, find alerting monitors, or investigate monitor configuration.
kanban: true
kanban_columns: investigation
---

# Monitors List (via Support Admin)

## Prerequisites

- **macOS** with `osascript`
- **Google Chrome** running with **"Allow JavaScript from Apple Events"** enabled
- **Two tabs open in Chrome:**
  1. `datadog.zendesk.com` (any page — for AI opt-out check)
  2. `support-admin.us1.prod.dog` (authenticated, switched to the correct customer org)

## When This Skill is Activated

Triggers on: "list monitors", "check monitors", "find alerting monitors", "monitor status", "show monitors"

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

### Phase 3: List/Search Monitors

```bash
# List all monitors
~/.cursor/skills/_shared/support-admin-api.sh monitors

# Search by query
~/.cursor/skills/_shared/support-admin-api.sh monitors "status:alert"
```

**Output format** matches Datadog MCP `search_datadog_monitors` — a JSON array:

```json
[
  {
    "id": 12345,
    "name": "High CPU on prod hosts",
    "message": "CPU usage > 90% for 5 minutes...",
    "type": "query alert",
    "status": "Alert",
    "query": "avg(last_5m):avg:system.cpu.user{env:prod} by {host} > 90",
    "creator": "John Doe",
    "created_at": "2026-01-15T10:00:00Z"
  }
]
```

### Phase 4: Present Results

Format as a summary table. Highlight:
- Monitors in **Alert** or **Warn** state
- Monitor types and their queries
- Recently created or modified monitors
