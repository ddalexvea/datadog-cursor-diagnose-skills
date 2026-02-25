Classify Zendesk ticket #{{TICKET_ID}}.

## Step 1: Read the ticket
- Tool: user-glean_ai-code-read_document
- urls: ["https://datadog.zendesk.com/agent/tickets/{{TICKET_ID}}"]

Extract: subject, first customer message, any error messages, logs, config snippets, urgency indicators.

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
