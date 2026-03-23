---
name: skill-name-in-lowercase-hyphens
description: >
  One sentence describing what the skill does and when to use it. Written in third person.
  Use when the user asks to "...". Max 1024 characters.
kanban: true
kanban_columns: triage,investigation
---

# Skill Title

Brief description — the problem this skill solves and what the agent does.

## Parameters

<!-- Add one line per user-supplied input using {{VAR_NAME}} syntax (uppercase, underscores).         -->
<!-- The Kanban extension auto-detects these and shows input fields before the Run button is enabled. -->
<!-- Example:                                                                                          -->
<!--   Ticket ID: `{{TICKET_ID}}`                                                                     -->
<!--   Org ID: `{{ORG_ID}}`                                                                           -->

_No parameters required._

## Prerequisites

<!-- List everything the agent needs before it can run. Be explicit — missing prereqs are the #1     -->
<!-- cause of skill failures.                                                                         -->

- macOS with `osascript`
<!-- - Google Chrome with a Zendesk tab open -->
<!-- - "Allow JavaScript from Apple Events" enabled (View > Developer > Allow JavaScript from Apple Events) -->
<!-- - Authenticated session on [target URL] -->
<!-- - Any CLI tool, API key, or MCP server required -->

## When This Skill is Activated

<!-- List natural-language trigger phrases. Cursor uses these to decide when to invoke the skill.     -->

Trigger phrases:
- "..."
- "..."

<!-- ─────────────────────────────────────────────────────────────────────────────────────────────── -->
<!-- Everything below is filled in by the AI (Cursor, Claude, etc.) based on the skill's purpose.   -->
<!-- The sections above (Parameters, Prerequisites, When Activated) are MANDATORY and must be kept.  -->
<!-- ─────────────────────────────────────────────────────────────────────────────────────────────── -->
