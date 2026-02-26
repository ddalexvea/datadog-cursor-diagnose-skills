---
name: zendesk-ticket-difficulty
description: Estimate ticket difficulty on a 1-10 scale by analyzing the issue type, product area, environment complexity, and whether reproduction or escalation is likely needed. Use when the user mentions difficulty, how hard, ticket score, rate ticket, or after ticket-pool to rank the queue.
---

# Estimate Ticket Difficulty

Scores a ticket from 1 (trivial) to 10 (expert-level) based on objective factors. Designed to feed into time-of-resolution estimation and help prioritize the queue.

**Different from other ticket skills:**
- **Investigator** = deep research (similar tickets, docs, code)
- **Repro Needed** = should I spin up an environment?
- **Difficulty** (this skill) = how hard is this ticket, numerically?

## How to Use

Just say: **"difficulty for #2513411"** or **"rate ticket ZD-2513411"**

Also runs automatically after `zendesk-ticket-pool` to rank the queue by difficulty.

## When This Skill is Activated

Triggers on:
- "difficulty for #XYZ"
- "how hard is #XYZ"
- "rate ticket ZD-XYZ"
- "score ticket #XYZ"
- Called by `zendesk-ticket-pool` as a follow-up step

Then:
1. Extract the ticket ID
2. Follow the steps in `difficulty-prompt.md`
3. Return score + breakdown

## Scoring Rubric (1-10)

| Score | Label | Profile |
|-------|-------|---------|
| 1-2 | Trivial | Answer in docs, simple how-to, known FAQ |
| 3-4 | Easy | Common pattern, config fix visible from flare/logs |
| 5-6 | Medium | Standard troubleshooting, single integration, needs flare analysis |
| 7-8 | Hard | Multi-product, reproduction needed, complex environment |
| 9-10 | Expert | Suspected bug, escalation likely, unfamiliar area, complex reproduction |

## Difficulty Factors

Each factor adds to the score:

| Factor | Impact | Examples |
|--------|--------|----------|
| **Issue type** | Low for questions, high for bugs | How-to (+0) vs suspected bug (+3) |
| **Product count** | +1 per additional product | Postgres alone (+0) vs Postgres + SQL Server + secrets (+2) |
| **Environment complexity** | +1-2 for complex setups | Single host (+0) vs multi-cloud K8s (+2) |
| **Reproduction needed** | +2 if yes | Config fix (+0) vs needs sandbox (+2) |
| **Info availability** | +1 if sparse | Flare provided (+0) vs no diagnostics (+1) |
| **Escalation likelihood** | +2 if likely | Config issue (+0) vs potential agent bug (+2) |
| **Docs coverage** | -1 if well-documented | Undocumented edge case (+1) vs clear docs (-1) |

## Output Format

Concise score — NOT an investigation.

```markdown
## Difficulty: ZD-{TICKET_ID}

**Score:** {N}/10 — {Trivial/Easy/Medium/Hard/Expert}

| Factor | Value | Impact |
|--------|-------|--------|
| Issue type | {bug/config/question} | +{N} |
| Products involved | {list} | +{N} |
| Environment | {simple/complex} | +{N} |
| Reproduction | {needed/not needed} | +{N} |
| Info available | {sufficient/sparse} | +{N} |
| Escalation | {likely/unlikely} | +{N} |
| Docs coverage | {good/poor} | {+/-N} |

**Key factor:** {the single biggest contributor to the score}
```

## Integration with Other Skills

- **After `zendesk-ticket-pool`**: auto-scores all tickets to rank the queue
- **Feeds `estimate-time-of-resolution`** (future): difficulty is a key input for time estimation
- **Uses `zendesk-ticket-repro-needed`**: reproduction need is a difficulty factor

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `difficulty-prompt.md` | Step-by-step prompt for the agent to follow |
