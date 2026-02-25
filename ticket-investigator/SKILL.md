---
name: ticket-investigator
description: Investigate a Zendesk ticket by reading its content, searching for similar past tickets, checking internal docs, and gathering customer context. Use when the user mentions investigate ticket, look into ticket, ticket investigation, analyze ticket, or provides a Zendesk ticket number to investigate.
---

# Ticket Investigator

Deep investigation skill for a specific Zendesk ticket. Reads the ticket, searches for similar past cases, checks internal documentation, gathers customer context, and writes a structured investigation report.

Can be used standalone or called by the `ticket-watcher` skill when new tickets are detected.

## How to Use

Just say: **"investigate ticket #2513411"** or **"look into ZD-2513411"**

The agent will:
1. Read the ticket from Zendesk via Glean
2. Search for similar resolved tickets
3. Search internal docs (Confluence)
4. Look up customer context (Salesforce)
5. Write a report to `investigations/ZD-{id}.md`

## When This Skill is Activated

If an agent receives a message matching any of these patterns:
- "investigate ticket #XYZ"
- "look into ticket XYZ"
- "analyze ZD-XYZ"
- "what's ticket #XYZ about?"
- Called as a subagent by `ticket-watcher`

Then:
1. Extract the ticket ID from the message
2. Follow the steps in `investigate-prompt.md` in this folder
3. Write the report to `investigations/ZD-{TICKET_ID}.md`

## Investigation Steps

1. **Read ticket** — Full content from Zendesk via Glean (`user-glean_ai-code-read_document`)
2. **Similar tickets** — Search Zendesk for resolved tickets with matching symptoms
3. **Internal docs** — Search Confluence for runbooks, troubleshooting guides, known issues
4. **Customer context** — Search Salesforce for org tier, MRR, top75, recent escalations
5. **Write report** — Structured markdown report to `investigations/ZD-{id}.md`

## Output

Reports are saved to `investigations/ZD-{TICKET_ID}.md` with sections:
- Customer info (org, tier, MRR, top75)
- Problem summary
- Key details (errors, logs, config)
- Similar past tickets with resolutions
- Relevant documentation links
- Initial assessment with suggested first steps
- Reproduction section (future: auto-detect environment)

## Reproduction Environments (Future)

The investigation can be extended to spin up reproduction environments based on the ticket topic:

| Topic | Environment | How |
|-------|-------------|-----|
| Kubernetes / containers | minikube sandbox | `minikube start` + apply manifests |
| AWS integrations | LocalStack or real AWS | Docker localstack or `aws` CLI |
| Azure integrations | Azure CLI sandbox | `az` CLI with test subscription |
| Docker / containers | Local Docker | `docker-compose` with agent config |
| Linux agent | Vagrant / Docker | Spin up a test VM or container |

The `investigate-prompt.md` has a placeholder section for this that can be activated per-topic.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `investigate-prompt.md` | Step-by-step investigation prompt template |
