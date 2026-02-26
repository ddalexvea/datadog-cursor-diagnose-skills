---
name: zendesk-ticket-eta
description: Estimate time of resolution for a Zendesk ticket. Provides active work time, calendar time, and time to next response — with blockers flagged separately and confidence level. Uses difficulty score + lifecycle phase + similar resolved tickets for calibration. Use when the user mentions ETA, how long, time to resolve, resolution time, or after ticket-pool for queue planning.
---

# Estimate Time of Resolution

Estimates how long a ticket will take to resolve, broken into active work time, calendar time, and time to next meaningful response. Accounts for the current lifecycle phase (remaining time, not total).

**This is inherently uncertain.** The skill flags blockers and confidence so you know how much to trust the estimate.

**Different from other ticket skills:**
- **Difficulty** = how hard (1-10 score)
- **ETA** (this skill) = how long (time ranges + blockers)

## How to Use

Just say: **"ETA for #2513411"** or **"how long for ZD-2513411?"**

Also runs after `zendesk-ticket-pool` to produce a queue timeline sorted by resolution time.

## When This Skill is Activated

Triggers on:
- "ETA for #XYZ"
- "how long for #XYZ"
- "time to resolve ZD-XYZ"
- "resolution time for #XYZ"
- Called by `zendesk-ticket-pool` as a follow-up step

Then:
1. Extract the ticket ID
2. Follow the steps in `eta-prompt.md`
3. Return estimate card

## Three Time Metrics

| Metric | What it measures | Example |
|--------|------------------|---------|
| **Active work** | Your hands-on time (investigation, reproduction, writing) | "2-3 hours" |
| **Calendar time** | Wall-clock time including wait periods | "3-5 business days" |
| **Next response** | When you can send the next meaningful reply | "Today if flare arrives" |

## Lifecycle Phases

The estimate depends on WHERE the ticket currently is:

| Phase | Description | Remaining work typically |
|-------|-------------|------------------------|
| New | Just received, not yet investigated | Full estimate applies |
| Investigating | Reading ticket, searching docs/KB | Slightly less than full |
| Waiting on customer | Asked for info, no response yet | Blocked — work resumes on reply |
| Waiting on escalation | Escalated to TEE or engineering | Blocked — 1-2 business days typical |
| Reproducing | Active reproduction in sandbox | Work in progress |
| Response ready | Writing the customer response | Almost done — 30min-1h |
| Follow-up | Back-and-forth in progress | Depends on remaining exchanges |

## Time Buckets

| Bucket | Active work | Calendar time | Typical ticket |
|--------|-------------|---------------|----------------|
| Quick fix | 15-30 min | Same day | Answer in docs, known FAQ |
| Standard | 30min-2h | 1-2 days | Config issue, single integration |
| Deep dive | 2-4h | 2-5 days | Multi-product, flare analysis |
| Complex | 4h-1 day | 1-2 weeks | Reproduction + escalation |
| Escalation-dependent | Unknown | Unknown | Blocked on engineering |

## Blocker Types

Blockers are flagged separately — they pause the clock:

| Blocker | Typical wait | Impact |
|---------|-------------|--------|
| Waiting for flare/logs | 1 business day | Can't diagnose without it |
| Waiting for customer response | 1 business day | Need info to proceed |
| Reproduction setup | 2-4 hours | Adds active work |
| TEE/engineering escalation | 1-2 business days | Out of your control |
| Customer goes silent | Days to weeks | Unpredictable |
| Scope change mid-ticket | Resets estimate | New issues discovered |

## Confidence Levels

| Confidence | When | Trust level |
|------------|------|-------------|
| High | Simple issue, good info, well-documented, similar tickets found | Estimate is reliable |
| Medium | Standard troubleshooting, some unknowns | Estimate is a reasonable guess |
| Low | Suspected bug, unclear scope, missing info, no similar tickets | Treat as very rough |

## Output Format

Small card — concise but complete.

```markdown
## ETA: ZD-{TICKET_ID}

**Phase:** {current lifecycle phase}
**Difficulty:** {N}/10
**Bucket:** {Quick fix / Standard / Deep dive / Complex / Escalation-dependent}

| Metric | Estimate | Confidence |
|--------|----------|------------|
| Active work | {range} | {High/Med/Low} |
| Calendar time | {range} | {High/Med/Low} |
| Next response | {when} | {High/Med/Low} |

**Blockers:**
- {blocker + typical wait}

**Calibration:** {heuristic / similar ticket ZD-XYZ resolved in N days}
```

### Batch Format (after ticket-pool)

Sorted by calendar time (shortest first):

```markdown
## Queue ETA

| Ticket | Score | Phase | Work | Calendar | Blockers | Conf. |
|--------|-------|-------|------|----------|----------|-------|
| ZD-X | 3/10 | New | 30min | Same day | None | High |
| ZD-Y | 6/10 | Wait cust. | 2-3h | 2-3 days | Flare needed | Med |
```

## Integration with Other Skills

- **Uses `zendesk-ticket-difficulty`**: difficulty score is a key input
- **Uses `zendesk-ticket-repro-needed`**: reproduction adds to active work time
- **Uses `zendesk-ticket-info-needed`**: missing info = blocker
- **After `zendesk-ticket-pool`**: produces queue timeline for standup/reporting

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `eta-prompt.md` | Step-by-step prompt for the agent to follow |
