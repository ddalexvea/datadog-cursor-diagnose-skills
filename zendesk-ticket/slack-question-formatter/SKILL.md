---
name: zendesk-ticket-slack-question-formatter
description: Format investigation findings into a ready-to-paste Slack question for spec teams. Use when the user says "ask spec about #XYZ", "format slack question", "slack message for ticket", or after investigation/reproduction when you need internal guidance.
kanban: true
kanban_columns: triage,investigation
---

## Parameters
Ticket ID: `{{TICKET_ID}}`


# Slack Question Formatter

Converts investigation or reproduction findings into a well-formatted Slack message for the owning spec team.

## Prerequisites

- Investigation file exists: `investigations/ZD-{ID}.md`
- Optional: routing output (which channel to post in)

## How to Use

Just say: **"ask spec about #1234567"** or **"format slack question for #1234567"**

The agent will:
1. Read the investigation file
2. Determine the Slack channel (via `routing` skill)
3. Format a structured question
4. Output ready-to-paste Slack message

## When This Skill is Activated

If an agent receives a message matching any of these patterns:
- "ask spec about #XYZ"
- "format slack question"
- "slack message for ticket #XYZ"
- "ask team about #XYZ"
- "internal question for #XYZ"

Then:
1. Extract the ticket ID from the message
2. Run the AI Compliance Check below FIRST
3. Follow the steps in `slack-prompt.md` in this folder
4. Output the formatted Slack message (user copies to Slack manually)

## AI Compliance Check (MANDATORY — FIRST STEP)

**Before processing ANY ticket data**, check for the `ai_opted_out` tag:

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

If the output contains `ai_optout:true`:
1. **STOP IMMEDIATELY** — do NOT process ticket data through the LLM
2. Do NOT generate any Slack message
3. Tell the user: **"Ticket #{TICKET_ID}: AI processing is blocked — this customer has opted out of GenAI (ai_optout). Handle manually without AI."**
4. Exit the skill

This is a legal/compliance requirement. No exceptions.

## Question Types

### 1. Root Cause Validation
When investigation found a likely root cause but needs confirmation:
```
Hi team! 👋
[Customer | Org | Tier | Ticket Link]

Context: [Brief background]
Issue: [What customer is experiencing]
Investigation: [What I found so far]
Questions:
1. Does this match the known issue? 
2. Any edge cases?
3. What should I tell the customer?
```

### 2. Bug Confirmation
When reproduction confirmed a bug, need engineering validation:
```
Hi team! 👋
[Customer | Org | Tier | Ticket Link]

Context: [Setup/environment]
Issue: [Bug behavior]
Investigation: [What I verified]
Reproduction: [Steps to reproduce in sandbox]
Questions:
1. Is this a known issue or new bug?
2. Expected timeline for fix?
3. Workaround available?
```

### 3. Escalation Request
When investigation exceeded time threshold or scope:
```
Hi team! 👋
[Customer | Org | Tier | Ticket Link]

Context: [What we know]
Issue: [The problem]
Investigation: [What I've checked - ruled out X, Y, Z]
Questions:
1. [Specific technical question]
2. [Request for guidance/escalation]
```

## Output Format

The skill outputs **plain text** ready to copy-paste into Slack. No markdown formatting conversion needed.

## Integration with Other Skills

- **Called by:** `investigator` (root cause uncertain), `reproduction` (bug confirmed), `workflow-tracker` (45-min timer exceeded)
- **Calls:** `routing` skill (to get Slack channel)
- **Reads:** `investigations/ZD-{ID}.md` (source material)

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `slack-prompt.md` | Step-by-step Slack message formatting prompt |
