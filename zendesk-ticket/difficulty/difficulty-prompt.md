Estimate the difficulty of Zendesk ticket #{{TICKET_ID}} on a 1-10 scale.

## Step 0: AI Compliance Check (MANDATORY)

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {{TICKET_ID}}
```

If the output contains `ai_optout:true`, **STOP NOW**. Tell the user: "Ticket #{{TICKET_ID}}: AI processing is blocked — this customer has opted out of GenAI (oai_opted_out). Handle manually without AI." Do NOT proceed to any further steps.

## Step 1: Read the ticket

### Primary: Chrome JS (real-time)

```bash
~/.cursor/skills/_shared/zd-api.sh read {{TICKET_ID}}
```

Returns metadata (filtered tags including complexity, product, impact) + comments (500 chars each — enough for difficulty assessment).

### Fallback: Glean MCP
```
Tool: user-glean_ai-code-read_document
urls: ["https://datadog.zendesk.com/agent/tickets/{{TICKET_ID}}"]
```

Note:
- What is the issue? (bug, config, question, feature request)
- Which products/integrations are involved?
- How complex is the customer's environment?
- Has the customer provided diagnostic info (flare, logs, screenshots)?
- Is there any sign this might be a bug vs config issue?

## Step 2: Score each factor

Start at a base score of 3 (average ticket), then adjust:

```
Issue type:
  question / how-to         → +0 (base stays)
  config issue               → +0
  unclear behavior           → +1
  suspected bug              → +3

Products involved:
  single integration         → +0
  2 products                 → +1
  3+ products or cross-stack → +2

Environment complexity:
  single host / simple       → +0
  Kubernetes / containerized → +1
  multi-cloud / custom infra → +2

Reproduction needed:
  not needed                 → +0
  likely needed              → +2

Info availability:
  flare or logs provided     → +0
  no diagnostics yet         → +1

Escalation likelihood:
  unlikely                   → +0
  possible                   → +1
  very likely (bug)          → +2

Docs coverage:
  well-documented area       → -1
  standard coverage          → +0
  edge case / undocumented   → +1
```

Cap the final score at 10.

## Step 3: Generate the output

```markdown
## Difficulty: ZD-{{TICKET_ID}}

**Score:** {N}/10 — {Trivial/Easy/Medium/Hard/Expert}

| Factor | Value | Impact |
|--------|-------|--------|
| Issue type | {type} | +{N} |
| Products involved | {list} | +{N} |
| Environment | {desc} | +{N} |
| Reproduction | {needed/not needed} | +{N} |
| Info available | {desc} | +{N} |
| Escalation | {likely/unlikely} | +{N} |
| Docs coverage | {good/standard/poor} | {+/-N} |

**Key factor:** {the single biggest contributor}
```

## Label mapping

- 1-2: Trivial
- 3-4: Easy
- 5-6: Medium
- 7-8: Hard
- 9-10: Expert

## Rules

- Be objective — score the ticket, not your feelings about it
- If the investigator or repro-needed skill already ran, use those findings
- When run after ticket-pool, output a compact table (one row per ticket) instead of full breakdowns
- Compact format for batch mode:

```markdown
## Queue Difficulty

| Ticket | Score | Label | Key Factor |
|--------|-------|-------|------------|
| ZD-{ID} | {N}/10 | {label} | {reason} |
```
