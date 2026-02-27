---
name: zendesk-ticket-repro-needed
description: Evaluate whether a Zendesk ticket needs reproduction. Reads the ticket, checks if the answer is already available from docs/past tickets, and if reproduction is needed, suggests the environment type. Use when the user mentions reproduce, repro needed, should I reproduce, need reproduction, or after a ticket investigation.
---

# Evaluate Need of Reproduction

Decides whether a ticket requires hands-on reproduction or if the issue can be resolved from existing knowledge (docs, past tickets, flare analysis).

**Different from other ticket skills:**
- **Investigator** = deep research (similar tickets, docs, code, customer context)
- **Info Needed** = what to ask the customer next
- **Repro Needed** (this skill) = should I spin up an environment to test this?

## How to Use

Just say: **"should I reproduce #1234567"** or **"repro needed for ZD-1234567?"**

Also runs automatically after `zendesk-ticket-investigator` when the investigation report is written.

## When This Skill is Activated

Triggers on:
- "should I reproduce #XYZ"
- "repro needed for ZD-XYZ"
- "do I need to reproduce #XYZ"
- "need reproduction for #XYZ"
- Called by `zendesk-ticket-investigator` as a follow-up step

Then:
1. Extract the ticket ID
2. Follow the steps in `repro-needed-prompt.md`
3. Return verdict + reasoning

## Decision Logic

### Reproduction IS needed when:
- Suspected bug -- need to confirm behavior before escalating to engineering
- Need to test a config parameter to validate the expected outcome
- Need to prove documentation steps work as described
- Customer's description is unclear and you need to see the behavior firsthand
- Need to be 100% sure of your answer before responding

### Reproduction is NOT needed when:
- Similar resolved tickets already provide a working solution/workaround
- The answer is clearly documented in public docs or GitHub source code
- It's a config issue and the flare/config already shows the root cause
- It's a question (not a bug) -- just needs guidance
- Known issue already tracked in JIRA with a documented workaround

## Environment Mapping

| Issue Type | Suggested Environment |
|-----------|----------------------|
| Agent integration (SNMP, OpenMetrics, HTTP check, etc.) | minikube with integration simulator |
| Kubernetes / Helm / Operator | minikube |
| Docker agent issues | Local Docker / docker-compose |
| Log collection / pipelines | minikube or docker-compose with log generator |
| APM / tracing | minikube with sample app |
| Cloud integrations (AWS, Azure, GCP) | Cloud sandbox account |
| OpenTelemetry | minikube with OTel collector |
| Agent core (startup, config, flare) | docker-compose or local install |

## Output Format

Concise verdict -- NOT an investigation.

```markdown
## Reproduction: ZD-{TICKET_ID}

**Verdict:** {YES / NO}
**Reason:** {one sentence}

### {If YES: Suggested Environment}
- **Type:** {minikube / docker-compose / cloud sandbox / local install}
- **What to test:** {specific behavior to reproduce}
- **What to verify:** {expected vs actual outcome to confirm}

### {If NO: Alternative}
- {What to do instead -- cite the doc, past ticket, or config fix}
```

## Integration with Other Skills

- **After `zendesk-ticket-investigator`**: auto-evaluates if reproduction is needed based on findings
- **Feeds `zendesk-ticket-info-needed`**: if repro shows a bug, we know exactly what to ask the customer
- **References**: [datadog-sandboxes-by-ai](https://github.com/ddalexvea/datadog-sandboxes-by-ai) for existing sandbox templates

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file -- skill definition |
| `repro-needed-prompt.md` | Step-by-step prompt for the agent to follow |
