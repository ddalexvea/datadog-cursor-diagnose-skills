# Datadog Cursor Diagnose Skills

A collection of Cursor IDE Agent Skills for streamlining Datadog Technical Support workflows.

## Purpose

This repository contains reusable Agent Skills that teach Cursor's AI assistant how to perform specialized TSE tasks: checking ticket queues, analyzing flares, querying customer data, and more.

Skills live **both locally** (`~/.cursor/skills/`) and in this GitHub repo for versioning and sharing.

## Structure

```
zendesk-ticket-pool/
└── SKILL.md              # Zendesk ticket pool checker via Glean MCP
```

## Available Skills

| Skill | Description | Trigger |
|-------|-------------|--------|
| `zendesk-ticket-pool` | Check assigned Zendesk tickets (open/pending) with priority, follow-up detection, stale ticket alerts | "check my tickets", "ticket pool", conversation start |

## Installation

### Local Setup

Clone into your personal Cursor skills directory:

```bash
git clone https://github.com/ddalexvea/datadog-cursor-diagnose-skills.git ~/.cursor/skills
```

Cursor automatically discovers skills from `~/.cursor/skills/*/SKILL.md`.

### Prerequisites

- **Glean MCP** configured in Cursor (for Zendesk access via Glean)
- **Cursor IDE** with Agent mode enabled

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
