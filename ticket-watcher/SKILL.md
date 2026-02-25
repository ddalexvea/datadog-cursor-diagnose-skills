---
name: ticket-watcher
description: Background ticket watcher that monitors Zendesk for new assignments, investigates them with parallel subagents, and sends macOS notifications. Use when the user mentions ticket watcher, background investigation, auto-investigate, or ticket monitoring.
---

# Ticket Watcher

Autonomous background watcher that runs in a dedicated Cursor chat, checking Zendesk for new ticket assignments via Glean MCP. When new tickets are found, it sends macOS notifications and can launch parallel subagents to investigate each ticket.

## Architecture

```
Dedicated Agent Chat (looping) → Glean MCP → detect new tickets
                                           → macOS notification
                                           → parallel subagents → investigation reports
```

No cron, no launchd, no extensions. Just an agent following instructions in its own chat.

## How to Start

1. **Open a new agent chat** (Cmd+L → "+" icon)
2. Type: **"start the ticket watcher"**
3. The agent reads this skill, follows `watcher-prompt.md`, and loops automatically

To stop: just type "stop" in the watcher chat, or close it.

## When This Skill is Activated

If an agent receives a message like "start the ticket watcher", "watch my tickets", or "ticket monitoring":
1. Read `watcher-prompt.md` from this skill folder (`~/.cursor/skills/ticket-watcher/watcher-prompt.md`)
2. Follow every step in that file exactly
3. Loop forever until the user says stop

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `watcher-prompt.md` | The looping prompt for the dedicated watcher chat |

For ticket investigation, this skill uses the standalone `ticket-investigator` skill (`~/.cursor/skills/ticket-investigator/`).

## Output (in workspace `investigations/`)

| File | Purpose |
|------|---------|
| `_processed.log` | Tracks already-seen ticket IDs (prevents duplicates) |
| `_alert.md` | Summary table of newly detected tickets |
| `_last_run.log` | Timestamp of last check (when no new tickets) |
| `ZD-{id}.md` | Individual investigation report per ticket |

## Behavior

### Detection Mode (default)
Every 5 minutes:
1. Search Zendesk via Glean for open + pending tickets assigned to the user
2. Compare against `_processed.log`
3. If new tickets → macOS notification + update `_alert.md`
4. If no new tickets → update `_last_run.log`
5. Sleep 5 minutes → repeat

### Investigation Mode (when new tickets found)
When new tickets are detected, the watcher launches **parallel subagents** (up to 4 at a time) using the `ticket-investigator` skill. Each subagent reads the ticket, searches for similar cases, checks docs, and writes a report to `investigations/ZD-{id}.md`.

### Manual Trigger
If the user asks to check tickets in an existing chat, follow the same steps from `watcher-prompt.md` but without the loop (single pass).

## When Used from Another Chat

If the agent in a regular chat reads this skill, it should:
1. **If asked to "start the watcher"** → Tell the user to open a new chat and type "start the ticket watcher"
2. **If asked to "check for new tickets" (one-time)** → Run steps 1-4 from `watcher-prompt.md` without looping
3. **If asked to "investigate ticket #XYZ"** → Use the `ticket-investigator` skill instead
