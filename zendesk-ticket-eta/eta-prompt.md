Estimate the time of resolution for Zendesk ticket #{{TICKET_ID}}.

## Step 1: Read the full ticket

```
Tool: user-glean_ai-code-read_document
urls: ["https://datadog.zendesk.com/agent/tickets/{{TICKET_ID}}"]
```

Read ALL comments. Determine:
- What is the issue? (bug, config, question)
- Which products/integrations are involved?
- What phase is the ticket in? (see phase detection below)
- What info has the customer already provided?
- What info is still missing?
- Has escalation happened or is it likely?
- How many back-and-forth exchanges so far?

## Step 2: Detect the lifecycle phase

Based on the comments, determine the current phase:

```
No agent response yet?
  → Phase: NEW

Agent responded, asked for info, customer hasn't replied?
  → Phase: WAITING ON CUSTOMER

Agent responded, customer replied, still troubleshooting?
  → Phase: FOLLOW-UP (count remaining expected exchanges)

Escalated to TEE or engineering, no response?
  → Phase: WAITING ON ESCALATION

Agent is actively investigating/reproducing?
  → Phase: INVESTIGATING / REPRODUCING

Root cause found, writing solution?
  → Phase: RESPONSE READY
```

## Step 3: Score difficulty (or reuse)

If the difficulty skill already ran for this ticket, reuse the score.
Otherwise, quickly assess:

```
Base: 3
+ Issue type:      question(+0) / config(+0) / unclear(+1) / bug(+3)
+ Products:        single(+0) / 2(+1) / 3+(+2)
+ Environment:     simple(+0) / K8s(+1) / multi-cloud(+2)
+ Reproduction:    no(+0) / yes(+2)
+ Info available:  good(+0) / sparse(+1)
+ Escalation:      unlikely(+0) / possible(+1) / likely(+2)
+ Docs:            good(-1) / standard(+0) / edge case(+1)
Cap at 10.
```

## Step 4: Search for similar resolved tickets

```
Tool: user-glean_ai-code-search
query: {product area + key symptom/error}
app: zendesk
```

Look for RESOLVED tickets with similar symptoms. If found, note:
- How many exchanges did they need?
- How long from creation to resolution?
- Was escalation involved?

Use this to calibrate the estimate. If no similar tickets, rely on heuristics.

## Step 5: Compute the estimate

### Active work time (your hands-on time)

Based on difficulty score AND current phase:

```
Difficulty 1-2 (Trivial):
  NEW → 15-30 min
  Any other phase → 5-15 min remaining

Difficulty 3-4 (Easy):
  NEW → 30min-1h
  INVESTIGATING → 20-40 min remaining
  WAITING ON CUSTOMER → 15-30 min after reply
  FOLLOW-UP → 15 min per remaining exchange

Difficulty 5-6 (Medium):
  NEW → 1-3h
  INVESTIGATING → 1-2h remaining
  WAITING ON CUSTOMER → 30min-1h after reply
  FOLLOW-UP → 30 min per remaining exchange

Difficulty 7-8 (Hard):
  NEW → 3-6h (half-day to full-day)
  INVESTIGATING → 2-4h remaining
  REPRODUCING → 2-4h remaining
  WAITING ON CUSTOMER → 1-2h after reply
  FOLLOW-UP → 30min-1h per remaining exchange

Difficulty 9-10 (Expert):
  NEW → 6h+ (multi-day)
  Any phase → multi-day active work
```

Adjustments:
- Reproduction needed? Add 2-4h
- Multiple back-and-forths expected? Add 30 min per exchange
- Calibration from similar ticket? Adjust toward that data point

### Calendar time (wall-clock including waits)

```
Calendar = Active work + Sum of wait blocks

Wait blocks:
  Waiting on customer response:    +1 business day per exchange
  Waiting on escalation (TEE):     +1-2 business days
  Waiting on engineering:          +3-5 business days
  Customer has gone silent:        +unknown (flag as blocker)
```

### Time to next response

```
Phase NEW/INVESTIGATING:  Active work time for first pass
Phase WAITING ON CUSTOMER: "When customer replies" + processing time
Phase WAITING ON ESCALATION: "When engineering responds"
Phase FOLLOW-UP:           Time for next exchange
Phase RESPONSE READY:      "Today — 30min to write response"
```

## Step 6: Assess confidence

```
High confidence when:
  - Simple issue (difficulty 1-4)
  - Good info available
  - Well-documented area
  - Similar resolved ticket found
  - Clear lifecycle phase

Medium confidence when:
  - Standard troubleshooting (difficulty 5-6)
  - Some unknowns but manageable
  - No similar tickets but clear pattern

Low confidence when:
  - Suspected bug (difficulty 7+)
  - Missing critical info
  - Unclear scope or potential scope change
  - No similar tickets
  - Multiple possible root causes
```

## Step 7: Generate the output

```markdown
## ETA: ZD-{{TICKET_ID}}

**Phase:** {phase}
**Difficulty:** {N}/10
**Bucket:** {Quick fix / Standard / Deep dive / Complex / Escalation-dependent}

| Metric | Estimate | Confidence |
|--------|----------|------------|
| Active work | {range} | {High/Med/Low} |
| Calendar time | {range} | {High/Med/Low} |
| Next response | {when} | {High/Med/Low} |

**Blockers:**
- {blocker + typical wait, or "None"}

**Calibration:** {heuristic / "Similar to ZD-XYZ (resolved in N days)"}
```

## Rules

- Estimate REMAINING time, not total time from ticket creation
- Always flag blockers — they're the main source of uncertainty
- If confidence is Low, say so clearly — don't pretend to know
- Similar tickets are the best calibration source — always search
- When run in batch after ticket-pool, use compact table sorted by calendar time
- Never promise exact times — always use ranges
- Business days only for calendar estimates (exclude weekends)
