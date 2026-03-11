---
name: support-admin-hosts-list
description: List and search hosts in a customer org via support-admin Chrome JS. Use when asked to list hosts, find hosts, check host inventory, count hosts, or investigate infrastructure in a customer org.
kanban: true
kanban_columns: investigation
---

# Hosts List (via Support Admin)

## Prerequisites

- **macOS** with `osascript`
- **Google Chrome** running with **"Allow JavaScript from Apple Events"** enabled
- **Two tabs open in Chrome:**
  1. `datadog.zendesk.com` (any page — for AI opt-out check)
  2. `support-admin.us1.prod.dog` (authenticated, switched to the correct customer org)

## When This Skill is Activated

Triggers on: "list hosts", "find hosts", "host inventory", "count hosts", "show hosts", "infrastructure list", "what hosts"

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

### Phase 3: List Hosts

```bash
# List all hosts (up to 100)
~/.cursor/skills/_shared/support-admin-api.sh hosts

# Filter by hostname pattern
~/.cursor/skills/_shared/support-admin-api.sh hosts "prod-web"
```

**Output format** matches Datadog MCP `search_datadog_hosts`:

```
<METADATA>
  <displayed_rows>5</displayed_rows>
  <total_rows>42</total_rows>
</METADATA>
<TSV_DATA>
hostname	cloud_provider	os	instance_type	agent_version
prod-web-01	aws	GNU/Linux	m5.xlarge	7.75.0
prod-web-02	aws	GNU/Linux	m5.xlarge	7.75.0
prod-db-01	aws	GNU/Linux	r5.2xlarge	7.74.1
staging-01	gcp	GNU/Linux	n1-standard-4	7.73.0
dev-local	 	macOS	 	7.75.0
</TSV_DATA>
```

### Phase 4: Present Results

Format the TSV as a readable table. Highlight:
- Outdated agent versions
- Mixed cloud providers
- Missing agent versions (unmonitored hosts)
- OS distribution

## Examples

```bash
# All hosts
~/.cursor/skills/_shared/support-admin-api.sh hosts

# Filter to production hosts
~/.cursor/skills/_shared/support-admin-api.sh hosts "prod"

# Filter to specific cloud
~/.cursor/skills/_shared/support-admin-api.sh hosts "aws"
```
