---
name: zendesk-org-disable
description: Handle Datadog org disable requests end-to-end. Reads the ticket, determines account type and org structure, identifies CSM, generates a step-by-step workflow with copy-paste messages. Auto-triggers when ticket type is account_disable or when user says disable org, close account, delete org, decommission org.
---

# Org Disable Workflow

Handles Datadog organization disable requests from Zendesk tickets. Reads the ticket, researches the org structure, identifies the CSM, and generates a complete step-by-step workflow with copy-paste-ready Zendesk notes and customer messages.

**Different from other ticket skills:**
- **Investigator** = deep research (similar tickets, docs, code)
- **Org Disable** (this skill) = specific administrative workflow for disabling orgs

## When This Skill is Activated

Auto-detect from ticket investigation when:
- Ticket type tag contains `account_disable`
- Ticket subject contains "disable", "delete org", "close account", "decommission"
- Product type is `account_management` with category `disable_account`

Or manually via:
- "disable org for ticket #XYZ"
- "close account ZD-XYZ"
- "handle org disable for #XYZ"

Then:
1. Extract the ticket ID
2. Follow the steps in `disable-org-prompt.md`
3. Write the workflow to `investigations/ZD-{TICKET_ID}.md`

## Key Reference

- Internal KB: Close/Cancel/Disable Datadog Accounts (search Confluence for this title)
- Internal admin tool: Disable Org (Customer Request) documentation (search Confluence)

## Account Type Decision Tree

```
Is the org Free/Trial/Student?
├── YES → No CSM/AE approval needed (can disable directly)
│         └── If AE assigned: notify AE (no approval needed), wait 24h, then disable
│         └── If no AE: proceed directly via internal admin tool
└── NO (Paying customer) →
    ├── Is CSM assigned?
    │   ├── YES → Tag CSM on ticket, start admin tool workflow, CSM approves
    │   └── NO →
    │       ├── Enterprise? → Contact enterprise sales billing support for CSM assignment
    │       └── Not Enterprise? → Ask in internal CS channel for CSM assignment
    └── Wait for CSM approval → Automation confirms disable → Send closing message
```

## Org Structure Checks

| Check | How | Impact |
|-------|-----|--------|
| Parent with active children? | Internal admin tool / dashboard | Cannot disable parent without disabling children first, or re-parenting |
| Child org? | Search past tickets, internal admin tool | Parent admin of same company is sufficient to authorize |
| Azure region (us3)? | Org ID in 1.2b range, us3 subdomain | Customer must remove Azure SaaS resource first |
| GCP/US5? | us5 subdomain | Additional requirements |

## What the Agent Automates vs Manual Steps

### Agent automates
- Read ticket content and extract details
- Determine account type (free/trial/paying) from ticket tags
- Identify org structure (parent/child) from past tickets
- Find CSM from Zendesk ticket metadata
- Check Azure/GCP region from org URL and ID
- Generate full workflow checklist
- Draft all Zendesk internal notes (copy-paste ready)
- Draft all customer messages (copy-paste ready)
- Draft internal CS channel message if needed

### Manual steps (user must do in admin tool/Zendesk)
- Confirm requester is admin in internal admin tool
- Check for child orgs in internal admin tool/dashboard
- Screenshot host panel in internal admin tool
- Post internal notes in Zendesk
- Send customer messages in Zendesk
- Start admin tool disable workflow
- Set ticket status to Solved

## Output

The workflow is written to `investigations/ZD-{TICKET_ID}.md` and includes:
- Ticket summary table
- Research findings (org structure, CSM, region)
- Numbered step-by-step workflow with checkboxes
- Copy-paste-ready text blocks for every Zendesk action
- Clear labels: which steps are automated vs manual

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `disable-org-prompt.md` | Step-by-step prompt for the agent to follow |
