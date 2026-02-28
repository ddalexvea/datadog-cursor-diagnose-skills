---
name: zendesk-ticket-investigator
description: Investigate a Zendesk ticket by reading its content, searching for similar past tickets, checking internal docs, and gathering customer context. Use when the user mentions investigate ticket, look into ticket, ticket investigation, analyze ticket, or provides a Zendesk ticket number to investigate.
---

# Ticket Investigator

Deep investigation skill for a specific Zendesk ticket. Reads the ticket, searches for similar past cases, checks internal documentation, gathers customer context, and writes a structured investigation report.

Can be used standalone or called by the `zendesk-ticket-watcher` skill when new tickets are detected.

## How to Use

Just say: **"investigate ticket #1234567"** or **"look into ZD-1234567"**

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
- Called as a subagent by `zendesk-ticket-watcher`

Then:
1. Extract the ticket ID from the message
2. **Run the AI Compliance Check below FIRST**
3. Follow the steps in `investigate-prompt.md` in this folder
4. Write the report to `investigations/ZD-{TICKET_ID}.md`

## AI Compliance Check (MANDATORY — FIRST STEP)

**Before processing ANY ticket data**, check for the `oai_opted_out` tag:

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

If the output contains `ai_optout:true`:
1. **STOP IMMEDIATELY** — do NOT process ticket data through the LLM
2. Do NOT generate any analysis, investigation, or report
3. Tell the user: **"Ticket #{TICKET_ID}: AI processing is blocked — this customer has opted out of GenAI (oai_opted_out). Handle manually without AI."**
4. Exit the skill

This is a legal/compliance requirement. No exceptions.

## Investigation Steps

1. **Read ticket** — Full content via Chrome JS (real-time) or Glean fallback (`user-glean_ai-code-read_document`)
2. **Download attachments** — List and download attachments via `zendesk-attachment-downloader` (flares, logs, screenshots). If a flare is found, extract and run appropriate analysis skills.
3. **Similar tickets** — Search Zendesk for resolved tickets with matching symptoms
4. **Internal docs** — Search Confluence for runbooks, troubleshooting guides, known issues
5. **Public docs** — Search docs.datadoghq.com for relevant product documentation
6. **GitHub code** — Search DataDog GitHub repos for config parameters, error messages, source code
7. **Customer context** — Search Salesforce for org tier, MRR, top75, recent escalations
8. **Write report** — Structured markdown report with links to all sources, including flare analysis findings

## Reference Sources

### Public Documentation
- https://docs.datadoghq.com — Main doc site (agent, logs, APM, infra, containers, etc.)

### Key GitHub Repositories
| Repo | What |
|------|------|
| [datadog-agent](https://github.com/DataDog/datadog-agent) | Core agent, config parameters, checks |
| [integrations-core](https://github.com/DataDog/integrations-core) | Official integration checks |
| [integrations-extras](https://github.com/DataDog/integrations-extras) | Community integrations |
| [helm-charts](https://github.com/DataDog/helm-charts) | Kubernetes Helm charts |
| [datadog-operator](https://github.com/DataDog/datadog-operator) | Kubernetes operator |
| [documentation](https://github.com/DataDog/documentation) | Source for docs.datadoghq.com |

### APM Tracers
| Language | Repo |
|----------|------|
| Python | [dd-trace-py](https://github.com/DataDog/dd-trace-py) |
| Java | [dd-trace-java](https://github.com/DataDog/dd-trace-java) |
| Node.js | [dd-trace-js](https://github.com/DataDog/dd-trace-js) |
| Go | [dd-trace-go](https://github.com/DataDog/dd-trace-go) |
| .NET | [dd-trace-dotnet](https://github.com/DataDog/dd-trace-dotnet) |
| Ruby | [dd-trace-rb](https://github.com/DataDog/dd-trace-rb) |

### Agent Config Parameters
Key files for parameter lookup in `datadog-agent`:
- `pkg/config/setup/config.go` — All config parameters with defaults
- `cmd/agent/dist/datadog.yaml` — Default config template
- `comp/core/config/` — Config component

### Internal Documentation
- Confluence — Runbooks, troubleshooting guides, known issues
- Salesforce — Customer tier, MRR, top75, escalation history

## Output

Reports are saved to `investigations/ZD-{TICKET_ID}.md` using a **timeline format**:

**Fixed header** (created once, updated if status changes):
- Ticket Summary table (customer, priority, status, product, tier, MRR, complexity, type, created date)

**Timeline entries** (appended on each investigation):
- Timestamped sections: `### YYYY-MM-DD HH:MM — Initial Investigation (Source)`
- Each entry contains: problem summary, key details, attachments, similar tickets, docs, assessment
- Re-investigations append new entries without overwriting previous ones
- Full history is visible in one file, in chronological order

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

## Attachment Downloads

Attachments (agent flares, logs, screenshots) are downloaded automatically using the `zendesk-attachment-downloader` skill, which uses `osascript` + Chrome JS execution to call the Zendesk API through the user's authenticated Chrome session.

**Prerequisites:** Chrome must be running with a Zendesk tab open and "Allow JavaScript from Apple Events" enabled (one-time setup — see `zendesk-attachment-downloader/SKILL.md`).

When a flare `.zip` is found among attachments, the investigator will:
1. Download it via `zendesk-attachment-downloader`
2. Extract it locally
3. Run `flare-network-analysis` and/or `flare-profiling-analysis` as appropriate
4. Include flare findings in the investigation report

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `investigate-prompt.md` | Step-by-step investigation prompt template |
