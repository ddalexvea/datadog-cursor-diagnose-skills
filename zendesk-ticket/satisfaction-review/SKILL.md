---
name: zendesk-ticket-satisfaction-review
description: Check satisfaction ratings on resolved tickets. Good ratings trigger celebration. Bad ratings generate a structured DSAT review with root cause analysis and rerating message. Use when the user mentions satisfaction, CSAT, DSAT, customer rating, review rating, or after a ticket is resolved and rated.
kanban: true
kanban_columns: resolved
---

## Parameters
Ticket ID: `{{TICKET_ID}}`


# Satisfaction Review

Checks Zendesk satisfaction ratings on resolved tickets and takes appropriate action:

- **Good rating (CSAT):** Celebration notification — shout out, motivation boost
- **Bad rating (DSAT):** AI-generated structured DSAT review with root cause analysis, improvement opportunities, and a ready-to-send rerating message

The DSAT review is appended to the existing `investigations/ZD-{id}.md` file as a `## Satisfaction Review` section.

**Different from other ticket skills:**
- **Retrospective** = agent performance analysis + RAG knowledge base entry
- **Satisfaction Review** (this skill) = customer satisfaction analysis + DSAT response template

They complement each other. The retrospective captures what the agent learned; the satisfaction review captures what the customer experienced.

## How to Use

Just say: **"check satisfaction for #1234567"** or **"DSAT review for ZD-1234567"**

Also runs automatically via the Supervisor Agent when resolved tickets receive satisfaction ratings.

## When This Skill is Activated

Triggers on:
- "check satisfaction for #XYZ"
- "satisfaction review #XYZ"
- "DSAT review for ZD-XYZ"
- "CSAT check #XYZ"
- "customer rating for #XYZ"
- Called by `supervisor-agent` when polling resolved tickets

Then:
1. Extract the ticket ID
2. **Run the AI Compliance Check below FIRST**
3. Fetch the satisfaction rating via `zd-api.sh satisfaction {id}`
4. If **good**: celebrate (notification + badge)
5. If **bad**: follow the steps in `satisfaction-prompt.md`
6. Return the review or celebration

## AI Compliance Check (MANDATORY -- FIRST STEP)

**Before processing ANY ticket data**, check for the `oai_opted_out` tag:

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

If the output contains `ai_optout:true`:
1. **STOP IMMEDIATELY** -- do NOT process ticket data through the LLM
2. Do NOT generate any review or analysis
3. Tell the user: **"Ticket #{TICKET_ID}: AI processing is blocked -- this customer has opted out of GenAI (oai_opted_out). Handle manually without AI."**
4. Exit the skill

This is a legal/compliance requirement. No exceptions.

## Satisfaction Data Source

The satisfaction rating lives on the Zendesk ticket object at `ticket.satisfaction_rating`:

```json
{
  "score": "good" | "bad",
  "comment": "customer feedback text (may be null)",
  "reason": "Support Rep Skills (category, may be null)",
  "reason_id": 9253161684379
}
```

Fetched via:
```bash
~/.cursor/skills/_shared/zd-api.sh satisfaction {TICKET_ID}
```

Returns: `SCORE|COMMENT|REASON` or `NONE` if no rating exists.

Zendesk search filters: `satisfaction:good`, `satisfaction:bad`, `satisfaction:good_with_comment`, `satisfaction:bad_with_comment`.

## Good Rating (CSAT) Flow

When `score === "good"`:
1. macOS notification: "Ticket #{id} rated GOOD by customer!"
2. If comment exists, include it in the notification
3. Add `CSAT_GOOD` badge to the card
4. Show celebration in the Supervisor Health tab
5. No AI analysis needed

## Bad Rating (DSAT) Flow

When `score === "bad"`:
1. macOS notification: "DSAT on #{id} -- review needed"
2. Add `DSAT` badge to the card
3. Spawn AI agent following `satisfaction-prompt.md`
4. Agent reads full conversation + investigation file
5. Generates structured DSAT review appended to `ZD-{id}.md`
6. Show warning alert in the Supervisor Health tab with "View Review" link

## DSAT Review Output Format

Appended to `investigations/ZD-{id}.md`:

```markdown
## Satisfaction Review

**Rating:** Bad
**Customer Comment:** {verbatim from Zendesk}
**Reason Category:** {reason from Zendesk}

### DSAT Content
{What the customer expressed dissatisfaction about}

### Opportunities for Improvement
{Specific actionable suggestions}

### Cause of this DSAT
{Root cause analysis from the customer's perspective}

### Opportunities for a Rerating
{Strategy + ready-to-send message}

#### Suggested Message
{Professional, empathetic customer-facing message}
```

## Integration with Other Skills

- **Supervisor Agent** calls this skill automatically for resolved tickets with new ratings
- **Retrospective** runs first (agent performance); satisfaction review runs when rating arrives (customer experience)
- **Investigator** output in `ZD-{id}.md` provides context for the DSAT analysis

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file -- skill definition |
| `satisfaction-prompt.md` | Step-by-step prompt for the DSAT review agent |
