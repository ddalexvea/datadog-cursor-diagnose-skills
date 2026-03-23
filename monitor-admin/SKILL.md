---
name: monitor-admin
description: Investigate monitor triggering issues using Datadog's internal Monitor Admin APIs. Use when the user asks why a monitor triggered, didn't trigger, how close it was to triggering, what the actual metric values were vs thresholds, or to analyze monitor state for an incident. Triggers on: investigate monitor, why did monitor trigger, monitor didn't trigger, monitor threshold analysis, monitor margin analysis, monitor admin.
---

## Parameters
Customer Org ID: `{{ORG_ID}}`
Monitor ID: `{{MONITOR_ID}}`


# Monitor Admin Investigation

Investigates monitor triggering issues using Datadog's internal Monitor Admin APIs. Answers questions like:
- Why did this monitor trigger at a specific time?
- Why didn't this monitor trigger when expected?
- How close was this monitor to triggering (margin analysis)?
- What were the actual metric values vs thresholds during an incident?

## When This Skill is Activated

Triggers: "why did monitor trigger", "monitor didn't fire", "investigate monitor", "monitor threshold", "monitor margin", "monitor admin", "analyze monitor", "why is monitor in alert"

## Prerequisites

- **Datadog VPN**: Monitor Admin APIs are VPN-gated (no authentication tokens needed)
- **MCP Server**: The `monitor-admin` MCP server must be running — set it up once with `setup.sh` (registers in `~/.cursor/mcp.json`)
- **Node.js >= 18**

## How to Use

1. Say: **"why did monitor 12345678 trigger for org 1234567890 around Feb 12, 11:25 AM UTC"**
2. Or paste a Monitor Admin URL directly:
   `https://monitor-admin.eu1.prod.dog/monitors/cluster/realtime/org/{org_id}/monitor/{monitor_id}?from_ts=...&to_ts=...`
3. The agent reads this skill, follows `investigate-prompt.md`, and provides a full root cause analysis

## MCP Server Setup (One-Time)

Run the setup script from this directory:

```bash
cd ~/path/to/this/skill
chmod +x setup.sh
./setup.sh
```

Then **restart Cursor** to load the MCP server.

## Available MCP Tools

| Tool | Purpose |
|------|---------|
| `monitor_get_state` | Get current monitor state and all group statuses |
| `monitor_get_results` | List all evaluations in a time range (typically 1/min) |
| `monitor_get_result_detail` | Per-group values, thresholds, margins, query, comparator |
| `monitor_get_group_payload` | Alert history (last triggered, resolved, notified timestamps) |
| `monitor_downtime_search` | Search for downtimes that may have silenced the monitor |

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `investigate-prompt.md` | Step-by-step investigation workflow |
| `setup.sh` | One-time MCP server installation script |
| `mcp-server/package.json` | MCP server Node.js dependencies |
| `mcp-server/index.mjs` | MCP server implementation |
