---
name: zendesk-ticket-classifier
description: Classify a Zendesk ticket by nature (bug, question, feature request, incident, etc.) with confirmation checks. Use when the user mentions classify ticket, ticket type, ticket nature, what kind of ticket, categorize ticket, or triage ticket.
---

# Ticket Classifier

Classifies a Zendesk ticket into one of 7 categories based on its content, with confirmation checks to avoid misclassification.

**Different from `zendesk-ticket-routing`:**
- **Classifier** (this skill) = **WHAT** type of ticket (bug? question? incident?)
- **Router** = **WHERE** to send it (which spec, which Slack channel, which team)

They complement each other. The classifier can feed into the router.

## How to Use

Just say: **"classify ticket #1234567"** or **"what type of ticket is ZD-1234567?"**

## When This Skill is Activated

Triggers on:
- "classify ticket #XYZ"
- "what kind of ticket is #XYZ"
- "categorize ZD-XYZ"
- "triage ticket #XYZ"
- Called by `zendesk-ticket-watcher` or `zendesk-ticket-investigator`

Then:
1. Extract the ticket ID
2. **Run the AI Compliance Check below FIRST**
3. Follow the steps in `classify-prompt.md`
4. Return the classification with confidence and evidence

## AI Compliance Check (MANDATORY — FIRST STEP)

**Before processing ANY ticket data**, check for the `oai_opted_out` tag:

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

If the output contains `ai_optout:true`:
1. **STOP IMMEDIATELY** — do NOT process ticket data through the LLM
2. Do NOT generate any classification or report
3. Tell the user: **"Ticket #{TICKET_ID}: AI processing is blocked — this customer has opted out of GenAI (oai_opted_out). Handle manually without AI."**
4. Exit the skill

This is a legal/compliance requirement. No exceptions.

## Categories

| Category | Description |
|----------|-------------|
| `billing-question` | Billing inquiry, pricing, plan changes, usage questions |
| `billing-bug` | Wrong charges, invoice errors, billing system issues |
| `technical-question` | How-to, configuration guidance, best practices, feature clarification |
| `technical-bug` | Errors, crashes, unexpected behavior, regressions |
| `configuration-troubleshooting` | Setup, installation, config issues — product works but setup is wrong |
| `feature-request` | Customer wants new functionality that doesn't exist |
| `incident` | Production outage, service degradation, multiple users affected |

## Decision Tree

```
Ticket comes in
  ├── Mentions billing/pricing/invoice?
  │     ├── Reports wrong charge/discrepancy → billing-bug
  │     └── Asks for info/clarification → billing-question
  ├── Asks "how to" / "is it possible" / "can I"?
  │     ├── Feature doesn't exist → feature-request
  │     └── Feature exists, needs guidance → technical-question
  ├── Reports error/crash/broken behavior?
  │     ├── Config looks wrong → configuration-troubleshooting
  │     └── Config looks correct → technical-bug
  ├── Just installed / setting up / first time?
  │     └── → configuration-troubleshooting
  └── Production impact / outage / urgent?
        ├── Multiple orgs or status page confirms → incident
        └── Single customer only → technical-bug
```

## Confirmation Checks per Category

### billing-question
- No error/bug reported in ticket
- Contains: "how much", "what plan", "upgrade", "pricing", "subscription"
- Product is working fine, customer just needs billing info
- **Verify:** Search Salesforce for customer's current plan
- **Risk:** Could be `feature-request` if asking about a feature on a higher plan

### billing-bug
- Customer reports incorrect amount, duplicate charge, wrong plan applied
- Evidence of discrepancy between expected and actual billing
- **Verify:** Check Salesforce for actual plan, invoice history
- **Verify:** Check org usage metrics (`datadog.estimated_usage.*`)
- **Risk:** Could be `billing-question` if customer misunderstands pricing model

### technical-question
- Contains questions, not complaints about broken behavior
- No logs, stack traces, or error messages
- Customer wants guidance, best practices, or clarification
- **Verify:** Check if the answer exists in public docs (docs.datadoghq.com)
- **Verify:** Search Confluence for existing guides on the topic
- **Risk:** Could be `configuration-troubleshooting` if they're asking "how to" because setup fails

### technical-bug
- Error message, logs, or stack traces present
- "It used to work", "it should do X but does Y", "regression"
- Customer's config looks correct but it still fails
- **Verify:** Search GitHub issues in DataDog repos for the same error
- **Verify:** Search Zendesk for similar tickets — many reports = likely real bug
- **Verify:** Check Confluence/release notes for known issues
- **Risk:** Could be `configuration-troubleshooting` if config is actually wrong

### configuration-troubleshooting
- "Just installed", "trying to configure", "first time", "setting up"
- Customer shares config (datadog.yaml, Helm values, Docker env vars)
- Likely misconfiguration: missing API key, wrong endpoint, permissions, wrong integration config
- **Verify:** Review shared config against docs' expected config
- **Verify:** Check agent status/flare for config validation errors
- **Verify:** Compare config against `datadog-agent` defaults
- **Risk:** Could be `technical-bug` if config is correct but still fails

### feature-request
- Customer asks for something not currently available
- No bug reported — product works as designed, customer wants more
- **Verify:** Search public docs — does the feature actually exist?
- **Verify:** Search JIRA for existing feature requests (same ask from others)
- **Risk:** Could be `technical-question` if the feature exists and customer doesn't know

### incident
- Production impact: "outage", "down", "all monitors firing", "data loss"
- Multiple users/systems affected, not just one dashboard
- Urgency language: "P1", "SEV", "urgent", "critical", "production"
- **Verify:** Check Datadog status page (https://status.datadoghq.com)
- **Verify:** Query org metrics for data gaps (`agent.running`, `datadog.agent.running`)
- **Verify:** Check if other customers opened similar tickets at same time
- **Risk:** Could be `technical-bug` if only one customer is affected

## Output Format

```markdown
## Classification: ZD-{TICKET_ID}

| Field | Value |
|-------|-------|
| **Category** | `{category}` |
| **Confidence** | High / Medium / Low |
| **Signals** | key phrases and evidence found |

### Evidence
- [list of specific signals found in the ticket]

### Confirmation Checks Performed
- [x] Check 1 — result
- [x] Check 2 — result
- [ ] Check 3 — could not verify (reason)

### Misclassification Risk
- Could also be `{other_category}` because: {reason}

### Suggested Actions
- {action based on category}
```

## Integration with Other Skills

- **`zendesk-ticket-watcher`** → calls classifier when new tickets detected → adds category to `_alert.md`
- **`zendesk-ticket-investigator`** → calls classifier as first step → includes category in report
- **`zendesk-ticket-routing`** → classifier feeds into router (billing → billing team, technical → relevant spec)

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `classify-prompt.md` | Step-by-step classification prompt |
