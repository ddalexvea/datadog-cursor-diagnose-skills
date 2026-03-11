---
name: support-admin-metrics-query
description: Query metrics timeseries in a customer org via support-admin Chrome JS. Use when asked to check metrics, query metric values, monitor CPU/memory/disk, count hosts running agent, or investigate metric patterns.
kanban: true
kanban_columns: investigation
---

# Metrics Query (via Support Admin)

## Prerequisites

- **macOS** with `osascript`
- **Google Chrome** running with **"Allow JavaScript from Apple Events"** enabled
- **Two tabs open in Chrome:**
  1. `datadog.zendesk.com` (any page — for AI opt-out check)
  2. `support-admin.us1.prod.dog` (authenticated, switched to the correct customer org)

## When This Skill is Activated

Triggers on: "query metrics", "check metric", "count hosts", "CPU usage", "memory usage", "disk usage", "metric value", "datadog.agent.running", "system.cpu", "system.mem", "system.disk"

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

### Phase 3: Query Metrics

```bash
~/.cursor/skills/_shared/support-admin-api.sh metrics "<query>" [from] [to]
```

**Query syntax** follows Datadog metrics query format:
- `avg:system.cpu.user{*}` — average CPU across all hosts
- `sum:datadog.agent.running{*}` — count of running agents
- `max:system.mem.used{host:prod-web-01}` — peak memory on specific host
- `avg:system.cpu.user{*} by {host}` — CPU grouped by host
- `avg:system.disk.in_use{*} by {device}` — disk usage by device
- `sum:trace.http.request.hits{service:web-store}.as_count()` — APM request count
- `p99:trace.http.request.duration{service:web-store}` — p99 latency

**Time range** (optional):
- Default: last 1 hour
- Formats: `now-15m`, `now-1h`, `now-1d`, epoch seconds

**Output format** matches Datadog MCP `get_datadog_metric`:

```
<METADATA>
  <series_count>1</series_count>
</METADATA>
<JSON_DATA>
[{"expression":"avg:system.cpu.user{*}","scope":"*","unit":"percent","time_range":["2026-03-11T09:00:00Z","2026-03-11T10:00:00Z"],"overall_stats":{"count":120,"min":0.5,"max":16.0,"avg":1.4,"sum":168.0},"pointlist_length":120,"last_value":1.2}]
</JSON_DATA>
```

### Phase 4: Present Results

Summarize the metric data: last value, average, min/max, and any notable spikes or trends.

## Examples

```bash
# Count of agents running
~/.cursor/skills/_shared/support-admin-api.sh metrics "sum:datadog.agent.running{*}"

# CPU usage last 4 hours
~/.cursor/skills/_shared/support-admin-api.sh metrics "avg:system.cpu.user{*}" now-4h now

# Memory by host, last hour
~/.cursor/skills/_shared/support-admin-api.sh metrics "avg:system.mem.used{*} by {host}" now-1h now

# APM request rate for a service
~/.cursor/skills/_shared/support-admin-api.sh metrics "sum:trace.http.request.hits{service:web-store}.as_count()" now-1h now
```

## Note

This skill supersedes the older `count-host-in-org` and `count-host-running-agent` skills, which used inline osascript. Prefer this skill for all metric queries.
