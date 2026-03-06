# Slack Question Formatter Prompt

You are formatting an investigation or reproduction finding into a Slack message for the owning spec team.

## Input
- Zendesk ticket ID: {ID}
- Investigation file: `investigations/ZD-{ID}.md`

## Task

1. Read `investigations/ZD-{ID}.md` completely
2. Determine the issue type:
   - **Root cause unclear?** → Format as "validation" question
   - **Bug confirmed in sandbox?** → Format as "bug confirmation" question
   - **Investigation timeout (45+ min)?** → Format as "escalation" question
3. Get the Slack channel (call `routing` skill if not provided)
4. Extract key sections:
   - **Customer info:** First name, org ID, tier, plan (from investigation)
   - **Context:** What led to this (background, previous steps)
   - **Issue:** What the customer is experiencing
   - **Investigation:** What you verified/tested/ruled out
   - **Findings:** Current hypothesis or confirmed bug
5. Format the message following the Slack template structure
6. Output **plain text only** — no markdown, no code blocks

## Message Structure

```
Hi team! 👋
{Customer Name} | Org ID: {org_id} | Tier: {tier} | Plan: {plan} | [Zendesk Ticket: {ID}](https://datadog.zendesk.com/agent/tickets/{ID})

Context:
{2-3 sentences of background and what led to this ticket}

Issue/concern:
{What the customer is experiencing - error messages, unexpected behavior, etc.}

Investigation:
- {What you verified - permissions, configurations, versions}
- {What you checked - feature flags, settings, logs}
- {What you observed - error codes, API responses, metrics}
- {Current hypothesis or confirmed bug behavior}

Questions:
{1-3 specific questions for the spec team}
```

## Key Rules

1. **Be specific:** Reference actual config values, version numbers, error messages
2. **Show your work:** Explain what you already checked and ruled out
3. **Ask clear questions:** Not "is this broken?" but "when relations param is missing, should DBM still collect schema metadata?"
4. **One message, one issue:** If multiple questions, keep them related
5. **Professional tone:** Direct, technical, no fluff

## Examples

### Example 1: Root Cause Validation

```
Hi team! 👋
Acme Corp | Org ID: 1234567 | Tier: Enterprise | Plan: Pro | [Zendesk Ticket: 2517041](https://datadog.zendesk.com/agent/tickets/2517041)

Context:
Customer enabled DBM for Postgres on RDS and can see structural metadata (index definitions) in the DBM Indexes tab, but no runtime metrics are appearing (postgresql.index_scans, postgresql.index_rows_read, etc.).

Issue/concern:
Runtime index metrics missing from DBM Indexes tab despite collect_schemas being enabled and permissions verified correct.

Investigation:
- Confirmed collect_schemas: enabled: true is set in postgres.d/conf.yaml
- Verified datadog user has SELECT on pg_stat_user_indexes and pg_statio_user_indexes
- Found no permission errors or query failures in agent logs
- Suspected the relations parameter may control runtime metric collection independently

Questions:
1. Is the relations parameter required to collect runtime index metrics when collect_schemas is enabled?
2. Would missing relations cause metadata-only collection (which is what we're seeing)?
3. Is this documented in the DBM setup guide for RDS?
```

### Example 2: Bug Confirmation

```
Hi team! 👋
TechCorp | Org ID: 2345678 | Tier: Pro | Plan: Standard | [Zendesk Ticket: 2516890](https://datadog.zendesk.com/agent/tickets/2516890)

Context:
Customer is running Agent 7.52 on EKS with the Mongo integration. They upgraded from 7.48 last week and now checks are failing intermittently.

Issue/concern:
Mongo check fails with "unable to parse connection string" even though the connection string hasn't changed and worked in 7.48.

Investigation:
- Reproduced in sandbox: EKS 1.27 + Agent 7.52 + Mongo 5.0 RDS
- Verified connection string format is valid (mongodb+srv://user:pass@host/?authSource=admin)
- Downgraded to 7.48 → check passes immediately
- Found error in agent logs: "deprecated URI scheme detected"
- Searched integrations-core repo, found related PR merged in 7.50

Questions:
1. Is this a known breaking change in 7.52 for Mongo URI handling?
2. What's the recommended migration path for customers still using non-SRV URIs?
3. ETA on a fix or does this require code changes?
```

## Output

Print the formatted Slack message only. User will copy it and paste into Slack manually.

Format: Plain text, no markdown conversion needed.
