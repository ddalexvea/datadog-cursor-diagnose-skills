Generate a DSAT (customer dissatisfaction) review for Zendesk ticket #{{TICKET_ID}}.

## Step 0: AI Compliance Check (MANDATORY)

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {{TICKET_ID}}
```

If the output contains `ai_optout:true`, **STOP NOW**. Tell the user: "Ticket #{{TICKET_ID}}: AI processing is blocked — this customer has opted out of GenAI (oai_opted_out). Handle manually without AI." Do NOT proceed to any further steps.

## Step 1: Fetch the satisfaction rating

```bash
~/.cursor/skills/_shared/zd-api.sh satisfaction {{TICKET_ID}}
```

Parse the output: `SCORE|COMMENT|REASON`

- If `NONE`, tell the user: "No satisfaction rating found for ticket #{{TICKET_ID}}."
- If `good`, tell the user: "Ticket #{{TICKET_ID}} received a GOOD rating! No DSAT review needed." and stop.
- If `bad`, continue to Step 2.

Save the customer's verbatim comment and reason category for the review.

## Step 2: Read the full ticket conversation

```bash
~/.cursor/skills/_shared/zd-api.sh comments {{TICKET_ID}} 0
```

The `0` means no truncation — fetch all comments in full.

Analyze the conversation carefully:
- What did the customer ask for?
- How did the agent respond at each step?
- Were there delays between responses?
- Did the agent address the customer's actual need?
- Was there miscommunication or misunderstanding?
- Did the agent show expertise and confidence?
- Was a definitive answer provided, or was it vague?

## Step 3: Read the investigation file (if it exists)

```bash
cat investigations/ZD-{{TICKET_ID}}.md 2>/dev/null
```

If the file exists, use its context:
- `## Summary` — what was the issue about
- `## Investigation` — what research was done
- `## Customer Response Draft` — what was sent to the customer
- `## Review History` — any feedback rounds
- `## Retrospective` — agent performance analysis

This gives you the full picture of how the ticket was handled internally.

## Step 4: Generate the DSAT Review

Based on the customer's comment, the conversation, and the investigation context, write a thorough and honest review.

**Be specific, not generic.** Reference actual messages, timelines, and decisions from the conversation.

Write the following section and append it to `investigations/ZD-{{TICKET_ID}}.md`:

```markdown
## Satisfaction Review

**Rating:** Bad
**Customer Comment:** {paste the customer's verbatim comment from Step 1}
**Reason Category:** {reason from Step 1, or "Not specified"}

### DSAT Content
{Summarize what the customer expressed dissatisfaction about. Be specific — reference their exact words and the specific interaction points that caused frustration. Include timeline if relevant (e.g., "customer waited 5 days between first and second response").}

### Opportunities for Improvement
{List 2-4 specific, actionable improvements based on what actually happened in this conversation. Examples:
- Get confirmation that the customer understands a limitation before closing
- Even if a feature doesn't exist, offer to open a feature request
- Provide more context about internal research steps to show thoroughness
- Respond faster during critical back-and-forth phases}

### Cause of this DSAT
{Analyze the root cause honestly. Consider:
- Was the answer actually wrong, or did the customer disagree?
- Was there a communication gap (customer expected X, agent delivered Y)?
- Was there a timing issue (too slow to respond)?
- Was the customer's expectation unrealistic, or did the agent miss something?
- If unclear, say so explicitly — don't guess.}

### Opportunities for a Rerating
{Provide a strategy for re-engaging the customer and a ready-to-send message. The message should:
- Acknowledge the feedback without being defensive
- Explain what was done and why (show the internal work)
- Offer something actionable (feature request, follow-up, additional help)
- Be professional, empathetic, and concise}

#### Suggested Message
{Write a complete, ready-to-paste customer-facing message. Use the ticket context to make it specific — not a generic template. Address the customer by name if available. Reference the specific topic discussed.}

**Format (Zendesk customer response standard):**
- Plain text only — no markdown (no **, ##, bullets)
- Signature: `Best regards,\n{AGENT_NAME}\n{AGENT_TITLE} | Datadog` (use the assignee name/title from the ticket)
```

## Step 5: Append to the investigation file

Append the `## Satisfaction Review` section at the END of `investigations/ZD-{{TICKET_ID}}.md`.

If the file does not exist, create it with just the satisfaction review section.

**Do NOT overwrite or modify any existing sections in the file.**

## Rules

- Be honest and specific — generic reviews are useless
- Reference actual conversation content, not hypothetical scenarios
- The suggested message should be ready to paste into Zendesk — no placeholders
- If the DSAT seems unfair or the customer's expectations were unrealistic, say so in "Cause of this DSAT" — but still provide a rerating strategy
- Keep the tone professional and constructive — this is a learning tool, not a blame tool
- If the customer's comment is in a language other than English, provide the review in English but keep the original comment verbatim
