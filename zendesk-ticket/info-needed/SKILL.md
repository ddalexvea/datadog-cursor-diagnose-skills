---
name: zendesk-ticket-info-needed
description: Estimate what customer info is still needed to resolve a Zendesk ticket. Reads all ticket comments, identifies the product area, fetches relevant troubleshooting guides from Confluence, and produces an internal analysis plus a customer-ready message. Use when the user mentions info needed, what to ask, missing info, customer info, estimate info, what do I need from the customer, or provides a ticket to triage.
---

# Estimate Needed Customer Info

Analyzes a Zendesk ticket to determine what diagnostic information is still missing from the customer, based on the product area's troubleshooting guide in Confluence.

**Different from other ticket skills:**
- **Investigator** = deep research (similar tickets, docs, code, customer context)
- **Classifier** = WHAT type of ticket (bug, question, incident)
- **Router** = WHERE to send it (which spec, team, channel)
- **Info Needed** (this skill) = WHAT to ask the customer next

## How to Use

Just say: **"what info do I need for ticket #1234567"** or **"what to ask for ZD-1234567"**

## When This Skill is Activated

Triggers on:
- "what info do I need for #XYZ"
- "what to ask for ZD-XYZ"
- "missing info for ticket #XYZ"
- "estimate info needed for #XYZ"
- "what should I ask the customer for #XYZ"
- Called by `zendesk-ticket-investigator` as a follow-up step

Then:
1. Extract the ticket ID
2. **Run the AI Compliance Check below FIRST**
3. Follow the steps in `info-needed-prompt.md`
4. Return internal analysis + customer-ready message

## AI Compliance Check (MANDATORY — FIRST STEP)

**Before processing ANY ticket data**, check for the `oai_opted_out` tag:

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

If the output contains `ai_optout:true`:
1. **STOP IMMEDIATELY** — do NOT process ticket data through the LLM
2. Do NOT generate any analysis or customer message
3. Tell the user: **"Ticket #{TICKET_ID}: AI processing is blocked — this customer has opted out of GenAI (oai_opted_out). Handle manually without AI."**
4. Exit the skill

This is a legal/compliance requirement. No exceptions.

## Skill Logic

### Phase 1: Read the full ticket conversation
- Read ALL comments (not just the first message) via Glean
- Build a timeline of what happened, what was already asked, what was already provided

### Phase 2: Identify the product area
- Detect the product area from ticket content (agent, APM, logs, DBM, containers, cloud integrations, etc.)
- Detect the specific integration or feature if applicable

### Phase 3: Fetch troubleshooting guide from Confluence
- Search Confluence via Glean for the product area's troubleshooting guide
- Extract the diagnostic steps, required info, and commands from the guide
- This is the PRIMARY source of truth for what to ask

### Phase 4: Cross-reference provided vs needed
- Compare what the troubleshooting guide requires against what the customer already provided
- Mark each item as: provided, partially provided, or missing

### Phase 5: Generate output
- Internal analysis: what's missing, why, priority
- Customer-ready message: polite request with public doc links and exact commands

## Output Format

Concise gap analysis — NOT a full investigation. No conversation summaries, no source citations, no estimated back-and-forths.

```markdown
## Info Needed: ZD-{TICKET_ID}

**Product:** {spec} — {feature/integration}
**OS:** {detected OS or "unknown"}
**Status:** {pending/open} — {waiting on customer / waiting on us}

### Already Provided
- [x] {item}

### Already Asked (waiting on customer)
- [ ] {item}

### Still Missing

🔴 **Critical**
1. {what} — {why, one sentence}

🟡 **Helpful**
1. {what} — {why, one sentence}

---

### 📋 Customer Message

{copy-paste ready message with numbered items, OS-appropriate commands, and public doc links}
```

## Common Info Patterns (by product area)

These are starting points -- the skill ALWAYS fetches the live Confluence guide for the definitive checklist.

| Product Area | Typical First Ask |
|-------------|-------------------|
| Agent (integration issue) | Flare (`agent flare`) + manual check (`agent check <NAME> --log-level debug`) |
| Agent (install/startup) | Flare + OS details + install method |
| Containers (K8s) | Flare + Helm values / DaemonSet manifest + `kubectl describe pod` |
| Cloud Integrations | Doc steps followed + AWS/GCP/Azure console screenshots + IAM policy |
| DBM | Flare + DB version + DB user grants + `SHOW VARIABLES` / `pg_stat_statements` |
| APM | Flare + tracer version + startup logs + sample trace ID |
| Logs | Flare + pipeline config + sample log line + index/filter config |
| NPM / NDM | Flare + network topology + SNMP profile |
| Monitors | Monitor JSON export + evaluation graph screenshot |
| Synthetics | Test ID + results page link + HAR file |
| RUM | SDK version + init config + network tab screenshot |

## Integration with Other Skills

- **After `zendesk-ticket-investigator`**: automatically suggests what info to request based on the investigation findings
- **Feeds `zendesk-ticket-difficulty`** (future): missing info count impacts difficulty estimate
- **Feeds `zendesk-ticket-time-estimate`** (future): more missing info = more back-and-forths = longer resolution

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `info-needed-prompt.md` | Step-by-step prompt for the agent to follow |
