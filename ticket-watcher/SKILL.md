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
| `watcher-prompt.md` | The looping prompt to paste into a dedicated chat |
| `investigate-prompt.md` | Subagent prompt template for deep ticket investigation |

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
When new tickets are detected, the watcher can launch **parallel subagents** (up to 4 at a time) to investigate each ticket:
1. Read ticket details from Zendesk via Glean
2. Search for similar past tickets
3. Search internal knowledge base / documentation
4. Identify customer context (org, tier)
5. Write structured report to `investigations/ZD-{id}.md`

### Manual Trigger
If the user asks to check tickets in an existing chat, follow the same steps from `watcher-prompt.md` but without the loop (single pass).

## Reproduction Environments (Future)

The investigation subagent can be extended to spin up reproduction environments based on the ticket topic:

| Topic | Environment | How |
|-------|-------------|-----|
| Kubernetes / containers | minikube sandbox | `minikube start` + apply manifests |
| AWS integrations | LocalStack or real AWS | Docker localstack or `aws` CLI |
| Azure integrations | Azure CLI sandbox | `az` CLI with test subscription |
| Docker / containers | Local Docker | `docker-compose` with agent config |
| Linux agent | Vagrant / Docker | Spin up a test VM or container |

This is a **planned extension** — the `investigate-prompt.md` has a placeholder section for reproduction steps that can be activated per-topic.

## When Used from Another Chat

If the agent in a regular chat reads this skill, it should:
1. **If asked to "start the watcher"** → Tell the user to open a new chat and paste `watcher-prompt.md`
2. **If asked to "check for new tickets" (one-time)** → Run steps 1-4 from `watcher-prompt.md` without looping
3. **If asked to "investigate ticket #XYZ"** → Use `investigate-prompt.md` as a template
