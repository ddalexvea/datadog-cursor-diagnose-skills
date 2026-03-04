---
name: zendesk-ticket-escalation-creator
description: Create Jira escalation tickets from investigation findings. Use when the user says "escalate ticket #XYZ", "create jira for #XYZ", "file bug for #XYZ", or when reproduction confirms a bug.
---

# Jira Escalation Creator

Converts investigation or reproduction findings into a ready-to-paste Jira bug or feature request ticket.

## Prerequisites

- Investigation file exists: `investigations/ZD-{ID}.md`
- Optional: classifier output (bug vs FR classification)

## How to Use

Just say: **"escalate ticket #1234567"** or **"create jira for bug in #1234567"**

The agent will:
1. Read the investigation file
2. Run the escalation readiness checklist
3. Detect issue type (bug or feature request)
4. Fill the appropriate template with investigation data
5. Output ready-to-paste Jira content

## When This Skill is Activated

If an agent receives a message matching any of these patterns:
- "escalate ticket #XYZ"
- "create jira for #XYZ"
- "file bug for #XYZ"
- "escalate as bug"
- "escalate as feature request"
- "create escalation for #XYZ"

Then:
1. Extract the ticket ID from the message
2. Run the AI Compliance Check below FIRST
3. Follow the steps in `escalate-prompt.md` in this folder
4. Output the filled template (user creates the Jira)

## AI Compliance Check (MANDATORY — FIRST STEP)

**Before processing ANY ticket data**, check for the `ai_opted_out` tag:

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

If the output contains `ai_optout:true`:
1. **STOP IMMEDIATELY** — do NOT process ticket data through the LLM
2. Do NOT generate any escalation analysis
3. Tell the user: **"Ticket #{TICKET_ID}: AI processing is blocked — this customer has opted out of GenAI (ai_optout). Handle manually without AI."**
4. Exit the skill

This is a legal/compliance requirement. No exceptions.

## Escalation Readiness Checklist

Before outputting a template, the agent checks:

- [ ] Root cause identified OR clearly explained why not possible
- [ ] Reproduction confirmed (for bugs) OR documented why not possible
- [ ] Searched existing Jira issues for duplicates
- [ ] Confirmed not user error / configuration issue
- [ ] Workaround documented (if exists)

If ANY items fail, the agent reports which are incomplete and asks for clarification before proceeding.

## Issue Type Detection

The agent detects:
- **Bug:** Confirmed defect in Agent/integration behavior, reproducible, customer expectations reasonable
- **Feature Request:** Customer asking for new capability, enhancement, or missing feature

## Template Structure

### Bug Report Template

```
Summary: [Component] - [Brief issue description]

Zendesk Ticket: ZD-XXXXXXX

Customer Impact:
- Number of customers affected: [1 or estimated]
- Severity: [Critical/High/Medium/Low]
- Workaround available: [Yes/No]

Environment:
- Agent Version: X.X.X
- OS: [Linux/Windows/macOS] [version]
- Platform: [Bare metal/Docker/Kubernetes/ECS/etc.]
- Datadog Site: [US1/EU1/US3/US5/AP1]

Description:
[Detailed description of the issue from investigation]

Steps to Reproduce:
1. [Step 1]
2. [Step 2]
3. [Step 3]

Expected Behavior:
[What should happen]

Actual Behavior:
[What actually happens]

Evidence:
- Flare: [link or location]
- Logs: [relevant excerpts]
- Screenshots: [if applicable]

Additional Context:
[Any other relevant information - workaround, related tickets, etc.]
```

### Feature Request Template

```
Summary: [FR] [Brief description of requested feature]

Zendesk Ticket: ZD-XXXXXXX

Customer Ask:
[What the customer is requesting]

Use Case:
[Why they need this feature]

Current Workaround:
[How they're handling it now, if at all]

Business Impact:
[Customer tier, ARR impact, strategic importance]

Proposed Solution:
[If you have ideas on implementation]
```

## Integration with Other Skills

- **Called by:** `investigator` (confirmed bug), `reproduction` (bug verified in sandbox), `workflow-tracker` (after internal consultation)
- **Calls:** Jira API (optional: can create the ticket directly or just output content)
- **Reads:** `investigations/ZD-{ID}.md` (source material)
- **Uses:** `classifier` output (bug vs FR) if available

## Output

The skill outputs:
1. **Readiness checklist status** — which items pass/fail
2. **Filled template** — ready to copy-paste into Jira OR create directly via Jira API

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `escalate-prompt.md` | Step-by-step Jira ticket creation prompt |
