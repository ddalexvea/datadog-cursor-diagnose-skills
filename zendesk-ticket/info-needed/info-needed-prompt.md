Estimate what customer info is needed for Zendesk ticket #{{TICKET_ID}}.

## Step 0: AI Compliance Check (MANDATORY)

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {{TICKET_ID}}
```

If the output contains `ai_optout:true`, **STOP NOW**. Tell the user: "Ticket #{{TICKET_ID}}: AI processing is blocked — this customer has opted out of GenAI (oai_opted_out). Handle manually without AI." Do NOT proceed to any further steps.

## Step 1: Read the full ticket

### Primary: Chrome JS (real-time)

```bash
~/.cursor/skills/_shared/zd-api.sh read {{TICKET_ID}} 0
```

Returns metadata (filtered tags) + all comments (full body with `0`). Full body needed to detect what info was already provided or asked.

### Fallback: Glean MCP
```
Tool: user-glean_ai-code-read_document
urls: ["https://datadog.zendesk.com/agent/tickets/{{TICKET_ID}}"]
```

Read ALL comments. Note: product area, OS/environment, what's already provided, what's already been asked.

## Step 2: Search Confluence for troubleshooting guide

```
Tool: user-glean_ai-code-search
query: {product_area} troubleshooting guide
app: confluence
```

If no clear result, try: `{product_area} runbook`, `{integration_name} troubleshooting`.
Read the guide to extract required diagnostic info and commands.

## Step 3: Generate the output

Keep it SHORT. This is NOT an investigation — just a gap analysis.

Output format:

```markdown
## Info Needed: ZD-{{TICKET_ID}}

**Product:** {spec} — {feature/integration}
**OS:** {detected OS or "unknown"}
**Status:** {pending/open} — {waiting on customer / waiting on us}

### Already Provided
- [x] {item}
- [x] {item}

### Already Asked (waiting on customer)
- [ ] {item}

### Still Missing

🔴 **Critical**
1. {what} — {why, one sentence}
2. ...

🟡 **Helpful**
1. {what} — {why, one sentence}

---

### 📋 Customer Message

{copy-paste ready message with:
- numbered items to provide
- OS-appropriate commands
- public doc links (never Confluence)
- brief explanation of WHY each item helps}
```

## Rules

- Keep output CONCISE — no conversation summaries, no estimated back-and-forths, no source citations
- This skill answers ONE question: "what info is missing?"
- Do NOT reproduce investigation details (similar tickets, customer context, code refs) — that's the investigator skill
- Read ALL comments — don't re-ask what the customer already provided
- Don't re-ask what a previous agent already asked UNLESS the customer didn't respond
- Detect OS from ticket content — provide commands for the right OS (if unknown, give both Linux and Windows)
- Customer message: NEVER mention Confluence, phrase everything as your own knowledge
- Customer message: include exact commands and public doc links
