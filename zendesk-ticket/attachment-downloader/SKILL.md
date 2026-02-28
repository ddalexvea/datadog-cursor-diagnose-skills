---
name: zendesk-attachment-downloader
description: List and download Zendesk ticket attachments (agent flares, logs, screenshots) via Chrome JS execution using osascript. Use when the user asks to download attachments, download flare, get flare from ticket, list ticket files, or fetch ticket attachments.
---

# Zendesk Attachment Downloader

Downloads attachments from Zendesk tickets through the user's authenticated Chrome session using `osascript` + Chrome JavaScript execution. This bypasses the Glean MCP limitation where attachment download URLs are not available.

## Prerequisites

### macOS Only

This skill uses `osascript` (AppleScript) to control Google Chrome. It only works on macOS.

### One-Time Setup

**Enable JavaScript from Apple Events in Chrome:**

Option A — Via menu (immediate, no restart):
1. Open Google Chrome
2. Menu bar → **View** → **Developer** → check **"Allow JavaScript from Apple Events"**

Option B — Via terminal (requires Chrome restart):
```bash
defaults write com.google.Chrome AppleScriptEnabled -bool true
```
Then quit and reopen Chrome.

### Runtime Requirements

- **Google Chrome must be running**
- **At least one tab must be open on `datadog.zendesk.com`** (any page — ticket view, home, search — doesn't matter)
- The user must be logged into Zendesk in that Chrome session

## When This Skill is Activated

Triggers:
- "download attachments from ticket 1234567"
- "download flare from ZD-1234567"
- "list attachments on ticket #1234567"
- "get the agent flare from this ticket"
- "fetch ticket files"
- Called by `zendesk-ticket-investigator` during investigation

## AI Compliance Check (MANDATORY — FIRST STEP)

**Before processing ANY ticket data**, check for the `oai_opted_out` tag:

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

If the output contains `ai_optout:true`:
1. **STOP IMMEDIATELY** — do NOT process ticket data through the LLM
2. Do NOT download or analyze attachments (attachment content is customer data)
3. Tell the user: **"Ticket #{TICKET_ID}: AI processing is blocked — this customer has opted out of GenAI (oai_opted_out). Handle manually without AI."**
4. Exit the skill

This is a legal/compliance requirement. No exceptions.

## How to Use

Say: **"download attachments from ticket 1234567"**

The agent will:
1. Find the Zendesk tab in Chrome
2. **Run AI Compliance Check** (see above)
3. Call the Zendesk API to list all attachments on the ticket
4. Show you the list (name, size, type)
5. Download selected files to `~/Downloads/`
6. If an agent flare `.zip` is found, offer to extract and analyze it

## How It Works

1. `osascript` locates a Chrome tab on `zendesk.com`
2. Executes a synchronous `XMLHttpRequest` inside that tab to call `/api/v2/tickets/{id}/comments.json`
3. The request uses the browser's session cookies — no API token needed
4. Parses the response to extract attachment metadata (`file_name`, `content_url`, `size`, `content_type`)
5. Creates a temporary `<a download>` element in the DOM and clicks it to trigger Chrome's native download
6. Monitors `~/Downloads/` for the downloaded file

## Attachment Types Handled

| Type | Extension | Auto-Action |
|------|-----------|-------------|
| Agent flare | `.zip` (contains `datadog-agent-*`) | Extract + offer flare analysis |
| Log file | `.log`, `.txt` | Download to ~/Downloads/ |
| Screenshot | `.png`, `.jpg`, `.jpeg` | Download to ~/Downloads/ |
| Config file | `.yaml`, `.yml`, `.conf` | Download to ~/Downloads/ |
| HAR file | `.har` | Download to ~/Downloads/ |
| Other | any | Download to ~/Downloads/ |

## Integration with Other Skills

- **zendesk-ticket-investigator** — Calls this skill to download attachments during investigation
- **flare-network-analysis** — Run on extracted flare to analyze network issues
- **flare-profiling-analysis** — Run on extracted flare to analyze memory/CPU profiling data

## Security Notes

- No API tokens are stored or needed — uses the existing Chrome session
- JavaScript execution requires explicit user opt-in (Allow JavaScript from Apple Events)
- Only accessible on `localhost` — no remote access
- The `content_url` from Zendesk includes a signed token, valid for the session

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `download-prompt.md` | Step-by-step execution prompt with osascript commands |
