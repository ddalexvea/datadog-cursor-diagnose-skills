---
name: logs-investigator
description: Search Datadog HQ (Org 2) logs to investigate customer issues using the official Datadog MCP server. Covers login failures, SAML errors, password resets, email delivery, audit history, monitor alert delivery, AWS/GCP/Azure integration errors, Synthetics, and log archive issues. Use when the user asks to search HQ logs, check org 2 logs, investigate a login issue, why an alert wasn't sent, email not received, audit history, integration errors, or any query that requires looking at internal Datadog platform logs.
---

## Parameters
Customer Org ID: `{{ORG_ID}}`


# Logs Investigator

Search Datadog HQ (Org 2) logs to diagnose customer issues using a curated library of 30+ internal log queries, organised by topic.

## When This Skill is Activated

Triggers: "search HQ logs", "check org 2 logs", "look in HQ logs", "investigate login issue", "why wasn't the alert sent", "email not received", "audit history for org", "AWS integration errors", "Synthetics not triggering", "log archive errors", "SAML login failure", "password reset not working"

## Prerequisites

- **Datadog Cursor Extension** installed and signed in to the **HQ (Org 2)** account
  - Install from the VS Code marketplace: search "Datadog" by Datadog Inc.
  - Sign in via OAuth — no API keys needed
  - Confirm in Cursor Settings (`Shift+Cmd+J`) > MCP tab that `search_datadog_logs` is listed
- **No VPN required**: The official Datadog MCP uses OAuth and is publicly accessible

## How to Use

Just describe the customer's issue:
- "Search HQ logs for login failures for user john@example.com in org 1234567"
- "Why didn't the monitor alert email get sent for org 9876543 yesterday around 3pm UTC?"
- "Check HQ logs for AWS integration errors for org 1234567"
- "Was a password reset email sent to jane@example.com?"

The agent reads `query-prompt.md`, selects the right query from the library, substitutes the customer's parameters, and runs it using the official Datadog MCP tools.

## MCP Server Setup (One-Time)

Run the setup script from this directory:

```bash
cd /path/to/this/skill
./setup.sh
```

This will:
1. Install the **Datadog Cursor extension** (`Datadog.datadog-vscode`) automatically via `cursor --install-extension`
2. Register the Datadog MCP HTTP endpoint in `~/.cursor/mcp.json` (you choose the region)
3. Guide you through signing in via OAuth

Then **restart Cursor** and confirm `search_datadog_logs` appears in the MCP tab.

> **New to this repo?** Cursor will also prompt you to install the Datadog extension automatically when you open this workspace — look for the "Install Recommended Extensions" notification.

## MCP Tools Used

| Tool | When used |
|------|-----------|
| `search_datadog_logs` | Fetch raw log events matching a query + index + time range |
| `analyze_datadog_logs` | Count/aggregate results (e.g. error counts, top services) |

Both tools come from the official **Datadog Cursor Extension** — no additional setup required once the extension is installed.

## Region Support

The extension authenticates against the Datadog site you are signed into. To query a different region's HQ org, switch the connected org in the extension (one-click org switcher in the Datadog extension sidebar).

| Region | Site |
|--------|------|
| US1 (HQ default) | `app.datadoghq.com` |
| EU1 | `app.datadoghq.eu` |
| US3 | `us3.datadoghq.com` |
| US5 | `us5.datadoghq.com` |
| AP1 | `ap1.datadoghq.com` |

## Query Groups

| Group | Use Case |
|-------|----------|
| Login & Auth | Login failures, SAML errors, password resets, org invites |
| Email | Missing reports, bounced emails, monitor alert emails |
| Audit History | API/App key usage, dashboard changes, log config changes |
| Monitor Alerts | Alert delivery, Slack/PagerDuty/webhook notifications |
| Integrations | AWS, GCP, Azure, web integration errors |
| Synthetics | Browser/API test runner logs, synthetics notifications |
| Log Archives | Archive write errors |

## Log Rehydration

If the logs you need are older than 15 days or were excluded from indexing, they require rehydration from archives. See `query-prompt.md` for the full rehydration checklist before requesting this.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `query-prompt.md` | Full query library and step-by-step investigation workflow |
| `setup.sh` | One-time setup: installs Datadog extension + registers MCP endpoint |
