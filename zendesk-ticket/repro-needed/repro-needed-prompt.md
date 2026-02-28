Evaluate whether Zendesk ticket #{{TICKET_ID}} needs reproduction.

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

Returns metadata (filtered tags including product, complexity) + comments (500 chars — enough for repro assessment).

### Fallback: Glean MCP
```
Tool: user-glean_ai-code-read_document
urls: ["https://datadog.zendesk.com/agent/tickets/{{TICKET_ID}}"]
```

Note: What is the issue? Is it a bug report, config problem, or question? What product area?

## Step 2: Check if the answer already exists

Search for similar resolved tickets:

```
Tool: user-glean_ai-code-search
query: {key symptoms or error message from ticket}
app: zendesk
```

Search public docs:

```
Tool: user-glean_ai-code-search
query: {product area + feature}
app: glean help docs
```

If either returns a clear answer/workaround, reproduction is likely NOT needed.

## Step 3: Apply the decision tree

```
Is this a question (how-to, best practice)?
  └── YES → NO repro. Point to docs.

Is the root cause visible in the flare/config/logs already?
  └── YES → NO repro. Explain the fix.

Do similar resolved tickets provide a working solution?
  └── YES → NO repro. Cite the ticket.

Is there a known issue in Confluence/JIRA for this?
  └── YES → NO repro. Link the known issue.

Is this a suspected bug?
  └── YES → Need to confirm behavior before escalating → YES repro.

Do I need to test a parameter or validate documentation steps?
  └── YES → Need to be 100% sure → YES repro.

Is the customer's description unclear and I can't determine root cause?
  └── YES → Need to see the behavior → YES repro.
```

## Step 4: Generate the output

```markdown
## Reproduction: ZD-{{TICKET_ID}}

**Verdict:** {YES / NO}
**Reason:** {one sentence}

### {If YES: Suggested Environment}
- **Type:** {minikube / docker-compose / cloud sandbox / local install}
- **What to test:** {specific behavior to reproduce}
- **What to verify:** {expected vs actual outcome}

### {If NO: Alternative}
- {doc link, past ticket, config fix, or known issue to reference}
```

## Rules

- Keep it SHORT -- this is a yes/no decision, not an investigation
- If the investigator already ran, use its findings instead of re-searching
- Default to NO unless there's a clear reason to reproduce
- When suggesting environment, suggest the simplest option (minikube > cloud sandbox)
- Never suggest reproduction just because the ticket is complex -- only when seeing the behavior firsthand adds value
