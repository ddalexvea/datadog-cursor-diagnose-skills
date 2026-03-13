Classify Zendesk ticket #{{TICKET_ID}}.

## Step 0: AI Compliance Check (MANDATORY)

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {{TICKET_ID}}
```

If the output contains `ai_optout:true`, **STOP NOW**. Tell the user: "Ticket #{{TICKET_ID}}: AI processing is blocked — this customer has opted out of GenAI (oai_opted_out). Handle manually without AI." Do NOT proceed to any further steps.

## Step 0b: Incident Tag Check (MANDATORY — check output from Step 0)

Look at the output of the `zd-api.sh ticket` command you just ran in Step 0.

**If no `incident_id:XXXXX` field is present:** proceed to Step 1 normally.

**If the output contains `incident:true` AND `incident_id:XXXXX` (e.g. `incident_id:50999`):**

→ **STOP all classification. Do NOT run Steps 1–4.**

This is an incident ticket. Follow the `incident-comms-prompt.md` workflow:

1. Run: `~/.cursor/skills/_shared/zd-api.sh search "tags:incident_XXXXX subject:golden"` (replace XXXXX with the incident number)
2. From the results, find the Golden Ticket (subject contains "GOLDEN", "GOLD", or "INTERNAL")
3. Run: `~/.cursor/skills/_shared/zd-api.sh comments GOLDEN_TICKET_ID 0` (the Golden Ticket is a DIFFERENT ticket — use its ID, not the customer ticket ID)
4. Extract public outbound communications and print them formatted for the TSE
5. Write `## Triage Decision` with `Next: ready_to_review`

**You MUST execute these commands. Do NOT hallucinate or assume the output. Do NOT skip any step.**

## Step 1: Read the ticket

### Primary: zd-api.sh (API)

```bash
~/.cursor/skills/_shared/zd-api.sh read {{TICKET_ID}}
```

Returns metadata (filtered tags including product, impact, complexity) + comments (500 chars each — enough for signal detection).

### Fallback: Glean MCP
- Tool: user-glean_ai-code-read_document
- urls: ["https://datadog.zendesk.com/agent/tickets/{{TICKET_ID}}"]

Extract: subject, first customer message, any error messages, logs, config snippets, urgency indicators.

## Step 1b: Check existing investigation file

```bash
ls investigations/ZD-{{TICKET_ID}}.md 2>/dev/null
```

If the file exists, read it. It may contain these sections that provide useful context:
- `## Ticket Summary` — metadata (customer, priority, product, type)
- `## Timeline` — timestamped investigation entries with findings
- `## Customer Response Draft` — AI-drafted response for TSE review
- `## Review History` — TSE feedback and agent revision history
- `## Session Context` — CLI agent session transcript
- `## Chat TLDR` — summary of interactive chat sessions
- `## Triage Decision` / `## Investigation Decision` — AI routing decisions

Use any existing data to inform your classification (e.g., product area, issue type from previous analysis). Do NOT re-investigate — just use what's already there.

## Step 2: Initial classification (signal words)

Scan the ticket content for these signal patterns:

**billing-question signals:** "invoice", "charge", "pricing", "plan", "subscription", "billing", "cost", "payment", "upgrade", "downgrade", "how much"
**billing-bug signals:** "charged twice", "wrong amount", "incorrect invoice", "billing error", "overcharged"
**technical-question signals:** "how to", "how do I", "is it possible", "best practice", "can I", "documentation", "what is the recommended"
**technical-bug signals:** "error", "crash", "failing", "broken", "not working", "regression", "500", "exception", "panic", "segfault", stack traces, log excerpts with ERROR/FATAL
**configuration-troubleshooting signals:** "install", "setup", "configure", "not sending", "not reporting", "connection refused", "permission denied", "just deployed", "first time", config file snippets (datadog.yaml, helm values)
**feature-request signals:** "feature request", "would be nice", "can you add", "enhancement", "suggestion", "wish", "it would be great if"
**incident signals:** "outage", "down", "all monitors", "production impact", "urgent", "P1", "SEV", "critical", "data loss", "service degradation"

Pick the **most likely category** based on signal density.

## Step 3: Confirmation checks (run in parallel where possible)

Based on the initial classification, run the appropriate confirmation checks:

### If billing-question or billing-bug:
- Tool: user-glean_ai-code-search
- query: customer org name
- app: salescloud
→ Check current plan, subscription, billing history

### If technical-question:
- Tool: user-glean_ai-code-search
- query: the topic the customer is asking about
- app: glean help docs
→ Does the answer exist in public docs? If yes → confirmed technical-question
→ If feature doesn't exist → reclassify as feature-request

### If technical-bug:
- Search GitHub issues for the error message:
  - Tool: user-github-search_code or user-github-2-search_code
  - q: "error message repo:DataDog/relevant-repo"
  → Known bug? Open issue?

- Search Zendesk for similar tickets:
  - Tool: user-glean_ai-code-search
  - query: error message keywords
  - app: zendesk
  → Multiple customers reporting = confirmed bug

- Check if config is actually wrong:
  → If config issue found → reclassify as configuration-troubleshooting

### If configuration-troubleshooting:
- Review any config shared in the ticket
- Compare against expected config in public docs:
  - Tool: user-glean_ai-code-search
  - query: product/integration name configuration
  - app: glean help docs

- If config looks correct but still fails → reclassify as technical-bug

### If feature-request:
- Check if feature actually exists:
  - Tool: user-glean_ai-code-search
  - query: feature description
  - app: glean help docs
  → If feature exists → reclassify as technical-question

- Search for existing feature requests:
  - Tool: user-glean_ai-code-search
  - query: feature description
  - app: jira
  → Link existing JIRA if found

### If incident:
- Check Datadog status page:
  - Tool: user-glean_ai-code-read_document
  - urls: ["https://status.datadoghq.com"]
  → Ongoing incident matching the symptoms?

- Search for similar tickets opened at the same time:
  - Tool: user-glean_ai-code-search
  - query: similar symptoms keywords
  - app: zendesk
  - sort_by_recency: true
  → Multiple tickets = platform incident. Single ticket = likely technical-bug

- **Check for incident tag and fetch Golden Ticket comms:**
  The `zd-api.sh ticket` output from Step 0 already shows `incident:true` and `incident_id:XXXXX` if this is an incident.
  If those fields are present, Step 0b should have already handled it. If you reach this point for an incident ticket, follow the `incident-comms-prompt.md` workflow now.
## Step 4: Output classification

Write the result in this format:

```markdown
## Classification: ZD-{{TICKET_ID}}

| Field | Value |
|-------|-------|
| **Category** | `{category}` |
| **Confidence** | High / Medium / Low |
| **Signals** | {key phrases found} |

### Evidence
- {signal 1 found in ticket}
- {signal 2 found in ticket}

### Confirmation Checks
- [x] {check performed} — {result}
- [x] {check performed} — {result}
- [ ] {check not performed} — {reason}

### Misclassification Risk
- Could also be `{other_category}` because: {reason}

### Suggested Actions
- For billing-question → Check Salesforce, respond with plan/pricing info
- For billing-bug → Escalate to billing team with evidence
- For technical-question → Point to relevant docs, provide guidance
- For technical-bug → Reproduce, check GitHub issues, escalate if confirmed
- For configuration-troubleshooting → Review config, provide correct setup steps
- For feature-request → Link existing JIRA or create new one, set expectations
- For incident → Check status page, escalate immediately, communicate impact
```

## Rules
- Always run at least ONE confirmation check before finalizing
- If confidence is Low, list all possible categories with reasoning
- Never skip the misclassification risk section
- Be concise — the classification should fit in a few lines, evidence supports it
