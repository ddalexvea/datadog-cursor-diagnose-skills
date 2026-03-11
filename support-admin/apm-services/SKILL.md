---
name: support-admin-apm-services
description: List and search APM services in a customer org via support-admin Chrome JS. Use when asked to list services, find services, check service catalog, or investigate service dependencies.
kanban: true
kanban_columns: investigation
---

# APM Services (via Support Admin)

## Prerequisites

- **macOS** with `osascript`
- **Google Chrome** running with **"Allow JavaScript from Apple Events"** enabled
- **Two tabs open in Chrome:**
  1. `datadog.zendesk.com` (any page — for AI opt-out check)
  2. `support-admin.us1.prod.dog` (authenticated, switched to the correct customer org)

## When This Skill is Activated

Triggers on: "list services", "find services", "service catalog", "what services", "show services", "service list"

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

### Phase 3: List/Search Services

```bash
# List all services
~/.cursor/skills/_shared/support-admin-api.sh services

# Search by name
~/.cursor/skills/_shared/support-admin-api.sh services "web-store"
```

**Output format** matches Datadog MCP `search_datadog_services`:

```
<METADATA>
  <count>25</count>
</METADATA>
<TSV_DATA>
service	type	team	description
web-store	web	frontend	Main e-commerce frontend
order-api	web	backend	Order processing API
payment-service	web	payments	Payment gateway integration
</TSV_DATA>
```

### Phase 4: Present Results

Format the TSV as a readable list or table for the user.
