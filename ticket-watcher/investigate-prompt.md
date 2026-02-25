Investigate Zendesk ticket #{{TICKET_ID}} (Subject: {{SUBJECT}}).

## Step 1: Read the ticket
Use Glean to read the full ticket content:
- Tool: user-glean_ai-code-read_document
- urls: ["https://datadog.zendesk.com/agent/tickets/{{TICKET_ID}}"]

Extract: customer name, org, priority, full problem description, any error messages or logs shared.

## Step 2: Search for similar past tickets
- Tool: user-glean_ai-code-search
- query: keywords from the ticket subject/description
- app: zendesk

Look for resolved tickets with similar symptoms. Note ticket IDs and solutions.

## Step 3: Search internal documentation
- Tool: user-glean_ai-code-search
- query: relevant product/feature keywords
- app: confluence

Look for runbooks, troubleshooting guides, known issues.

## Step 4: Customer context
- Tool: user-glean_ai-code-search
- query: customer org name
- app: salescloud

Check for customer tier, MRR, top75 status, recent escalations.

## Step 5: Write investigation report
Write the report to `investigations/ZD-{{TICKET_ID}}.md` with this structure:

```markdown
# ZD-{{TICKET_ID}}: {{SUBJECT}}

## Customer
- **Org:** 
- **Tier/MRR:** 
- **Top75:** Yes/No

## Problem Summary
(2-3 sentences describing the issue)

## Key Details
- Error messages, logs, config snippets from the ticket

## Similar Past Tickets
| Ticket | Subject | Resolution |
|--------|---------|------------|
| #ID | subject | how it was resolved |

## Relevant Documentation
- [Doc title](url) - brief description

## Initial Assessment
- **Category:** (agent, logs, APM, infra, etc.)
- **Likely cause:** 
- **Suggested first steps:**
  1. ...
  2. ...
  3. ...

## Reproduction (if applicable)
<!-- FUTURE: Auto-detect topic and suggest environment -->
<!-- Kubernetes → minikube -->
<!-- AWS → localstack or real AWS -->
<!-- Azure → az CLI -->
<!-- Docker → docker-compose -->
**Topic detected:** (auto-filled by watcher)
**Suggested environment:** (auto-filled)
**Reproduction steps:** TODO - manual for now
```

## Rules
- Keep it factual — only include what you found, don't speculate
- If no similar tickets found, say so
- If no docs found, say so
- Be concise but thorough
