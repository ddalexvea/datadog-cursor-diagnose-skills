# Datadog Cursor Diagnose Skills

A collection of Cursor IDE Agent Skills for streamlining Datadog Technical Support workflows.

## Purpose

This repository contains reusable Agent Skills that teach Cursor's AI assistant how to perform specialized TSE tasks: checking ticket queues, recording screens, managing text shortcuts, and more.

Skills live **both locally** (`~/.cursor/skills/`) and in this GitHub repo for versioning and sharing.

## Structure

```
zendesk-ticket-pool/
└── SKILL.md                        # Zendesk ticket pool checker via Glean MCP

snagit-screen-record/
├── SKILL.md                        # Snagit video capture from Cursor
└── scripts/
    ├── setup.sh                    # Verify Snagit prerequisites
    └── record.sh                   # Trigger Snagit capture via AppleScript

text-shortcut-manager/
├── SKILL.md                        # Detect recurring phrases + manage espanso shortcuts
└── scripts/
    ├── scan.py                     # Scan transcripts for repeated phrases
    └── manage.py                   # Add/list/remove espanso shortcuts
```

## Available Skills

| Skill | Description | Trigger | Prerequisites |
|-------|-------------|---------|---------------|
| `zendesk-ticket-pool` | Check assigned Zendesk tickets (open/pending) with priority, follow-up detection, stale ticket alerts | "check my tickets", "ticket pool" | Glean MCP |
| `snagit-screen-record` | Start Snagit video capture via text or voice command | "start recording", "record screen" | Snagit 2024, Accessibility permissions |
| `text-shortcut-manager` | Scan Cursor transcripts for recurring phrases, create espanso text shortcuts automatically | "scan my patterns", "add shortcut" | espanso (`brew install espanso`) |

## Installation

### Local Setup

Clone into your personal Cursor skills directory:

```bash
git clone https://github.com/ddalexvea/datadog-cursor-diagnose-skills.git ~/.cursor/skills
```

Cursor automatically discovers skills from `~/.cursor/skills/*/SKILL.md`.

### Prerequisites

- **Cursor IDE** with Agent mode enabled
- **macOS** (skills use AppleScript and macOS-specific paths)
- **Glean MCP** configured in Cursor (for `zendesk-ticket-pool`)
- **espanso** (`brew install espanso`) for `text-shortcut-manager`
- **Snagit 2024** for `snagit-screen-record`

## How Skills Work

Skills are markdown instruction files that the AI agent reads when it determines they're relevant. They provide:

1. **Step-by-step workflows** - What tools to call, in what order
2. **Data extraction patterns** - How to parse results
3. **Output formatting** - Consistent, actionable presentation
4. **Domain knowledge** - TSE-specific context the AI wouldn't know

## Syncing Local <-> GitHub

Since skills live in `~/.cursor/skills/`, sync changes with:

```bash
cd ~/.cursor/skills
git add -A && git commit -m "Update skills" && git push
```

## Related Projects

- [datadog-cursor-diagnose-rules](https://github.com/ddalexvea/datadog-cursor-diagnose-rules) - Diagnostic rules for flare analysis and troubleshooting

## Maintainer

Alexandre VEA
Datadog Technical Support
