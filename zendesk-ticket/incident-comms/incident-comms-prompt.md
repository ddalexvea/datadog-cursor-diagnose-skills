# Incident Comms Prompt

You are extracting incident communications from a Zendesk Golden Ticket so a TSE can forward them to their customer.

## Input

The TSE has provided a Zendesk ticket ID (e.g. `#2531965`). This ticket is linked to a Datadog incident.

---

## Step 1 — Get Ticket Metadata (MANDATORY FIRST)

RUN THIS COMMAND NOW:
```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

If output contains `ai_optout:true` → **STOP**. Output: `[AI BLOCKED — customer opted out of GenAI]`

---

## Step 2 — Detect the Incident Tag

Read the ticket output from Step 1. Look for:
- `incident:true` → confirms this is an incident ticket
- `incident_id:XXXXX` → extract the incident number (e.g. `incident_id:50999` → `50999`)

If neither is found → output:
```
❌ Ticket #{TICKET_ID} does not appear to be linked to a Datadog incident (no incident tag found).
```
And **STOP**.

---

## Step 3 — Find the Golden Ticket

RUN THIS COMMAND NOW:
```bash
~/.cursor/skills/_shared/zd-api.sh search "tags:incident_{INCIDENT_NUMBER} subject:golden"
```

The output will show tickets matching the search. Look for a ticket with "GOLDEN TICKET", "GOLD TICKET", or "INTERNAL" in the subject. It is typically the single coordination ticket created by the incident response team.

If the search returns `TOTAL:0` or no ticket with "GOLDEN" in the subject, try a broader search:
```bash
~/.cursor/skills/_shared/zd-api.sh search "tags:incident_{INCIDENT_NUMBER}"
```
Then manually inspect the subjects for the Golden Ticket.

If still no golden ticket found → output:
```
⚠️ No Golden Ticket found for incident_{INCIDENT_NUMBER}. Check the search results manually.
```
And **STOP**.

Extract the Golden Ticket ID from the first column of the matching row.

---

## Step 4 — Extract All Communications from the Golden Ticket

RUN THIS COMMAND NOW:
```bash
~/.cursor/skills/_shared/zd-api.sh comments {GOLDEN_TICKET_ID} 0
```

The `0` means no truncation — returns full comment bodies. The Golden Ticket is a **different ticket** from the customer ticket. Do NOT use the customer ticket ID here.

---

## Step 5 — Filter to Public/Outbound Comments Only

From the comments, keep only **public outbound** ones (the actual customer communications). Skip:
- Internal notes (marked as `public: false`, or content starts with `[Internal]`, contains only routing/SLA info, or is from automated bots)
- Auto-generated bot messages (author IDs matching known bot IDs like `-1`)

The real communications will be authored by a TSE (human author_id > 0) and contain actual incident update text like "We are currently investigating...", "We identified the cause...", "We can confirm...".

---

## Step 6 — Output

Print the following in chat, newest communication first:

```
🚨 INCIDENT #{INCIDENT_NUMBER} — Golden Ticket #{GOLDEN_TICKET_ID}
Subject: {golden ticket subject}
Status: {golden ticket status}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📢 CUSTOMER COMMUNICATIONS ({count} total)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[{N}] {timestamp UTC} — {label: INITIAL UPDATE / UPDATE / RESOLUTION}
──────────────────────────────────────
{full comment body}

[{N-1}] {timestamp UTC} — {label}
──────────────────────────────────────
{full comment body}

...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 LATEST COMMUNICATION TO REUSE:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{most recent communication body — ready to copy-paste}
```

Label each communication:
- First one → **INITIAL UPDATE**
- Middle ones → **UPDATE**
- Last one (if mentions "resolved", "confirmed", "working as expected", "backfilled") → **RESOLUTION**

---

## Step 7 — Write Triage Decision to Investigation File

After printing the output above, write the triage decision to the investigation file:

```
## Triage Decision
- Next: ready_to_review
- Reason: Incident communication extracted from Golden Ticket #{GOLDEN_TICKET_ID} for incident #{INCIDENT_NUMBER}
```

---

## Notes

- **DO NOT** use `chrome_exec_js`, `osascript`, or any browser automation. Only use `zd-api.sh` commands.
- Always show **all** communications, not just the latest (TSE picks which to use)
- The "LATEST COMMUNICATION TO REUSE" block at the bottom makes it easy to grab the most recent one
- If the incident is still ongoing (golden ticket status = `open`), add a banner: `⚠️ INCIDENT STILL ONGOING — no resolution communication yet`
