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

→ **STOP all classification. Do NOT run Steps 1–4. Execute the following steps in full:**

### Incident Comms — Step A: Extract the incident number
From the Step 0 output, read the `incident_id` value (e.g. `incident_id:50999` → incident number is `50999`).

### Incident Comms — Step B: Find the Golden Ticket

Run this command (replace `INCIDENT_NUMBER_HERE` with the actual number, e.g. `50999`):

```bash
source ~/.cursor/skills/_shared/chrome-helper.sh && TAB=$(chrome_find_tab "zendesk.com") && WIN=$(echo "$TAB" | cut -d: -f1) && TAB_IDX=$(echo "$TAB" | cut -d: -f2) && chrome_exec_js "$WIN" "$TAB_IDX" "var tag='incident_INCIDENT_NUMBER_HERE';var xhr=new XMLHttpRequest();xhr.open('GET','/api/v2/search.json?query=tags:'+tag+'&per_page=100',false);xhr.send();var d=JSON.parse(xhr.responseText);var out='TOTAL:'+d.count+'\n';for(var i=0;i<d.results.length;i++){var t=d.results[i];var g=t.subject.toLowerCase().indexOf('golden')>-1||t.subject.toLowerCase().indexOf('gold')>-1||t.subject.toLowerCase().indexOf('internal')>-1;out+=t.id+' | '+t.status+' | golden:'+g+' | '+t.subject+'\n';}out;"
```

From the results, identify the Golden Ticket (subject contains "GOLDEN TICKET", "GOLD TICKET", or "INTERNAL"). If no golden ticket found, use the most recent ticket tagged with the incident.

### Incident Comms — Step C: Extract all communications from the Golden Ticket
```bash
~/.cursor/skills/_shared/zd-api.sh comments GOLDEN_TICKET_ID 0
```
(Replace `GOLDEN_TICKET_ID` with the ID found in Step B.)

### Incident Comms — Step D: Output
Print in chat, newest first:
```
🚨 INCIDENT #INCIDENT_NUMBER — Golden Ticket #GOLDEN_TICKET_ID
Subject: {golden ticket subject}
Status: {golden ticket status}
Total tickets in this incident: {TOTAL}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📢 CUSTOMER COMMUNICATIONS ({count} total)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[N] {timestamp UTC} — {INITIAL UPDATE / UPDATE / RESOLUTION}
──────────────────────────────────────
{full comment body}

...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 LATEST COMMUNICATION TO REUSE:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{most recent public comment body — ready to copy-paste}
```

Keep only **public outbound** comments (skip internal notes marked `public: false`, bot messages, SLA triggers).
Label: first → **INITIAL UPDATE**, middle → **UPDATE**, last mentioning "resolved"/"confirmed"/"working" → **RESOLUTION**.
If golden ticket status is `open`: add banner `⚠️ INCIDENT STILL ONGOING`.

Then write to `investigations/ZD-{{TICKET_ID}}.md` (create if missing):

```markdown
## Triage Decision
- Next: ready_to_review
- Reason: Incident comms extracted from Golden Ticket #GOLDEN_TICKET_ID for incident_INCIDENT_NUMBER
```

**Do NOT write a standard classification. Do NOT proceed to Step 1.**

## Step 1: Read the ticket

### Primary: Chrome JS (real-time)

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
  Get the raw tags for the ticket:
  ```bash
  source ~/.cursor/skills/_shared/chrome-helper.sh
  # find tab first if needed: chrome_find_tab "zendesk.com"
  ```
  Then run:
  ```bash
  source ~/.cursor/skills/_shared/chrome-helper.sh && chrome_exec_js WIN TAB \
    "var xhr=new XMLHttpRequest();xhr.open('GET','/api/v2/tickets/{{TICKET_ID}}.json',false);xhr.send();JSON.parse(xhr.responseText).ticket.tags.join(', ');"
  ```
  If tags contain `incident` AND `incident_XXXXX`:
  → **Immediately run the `incident-comms` skill** for this ticket.
  This will find the Golden Ticket and extract all approved customer communications so the TSE can copy-paste the latest update directly.

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
