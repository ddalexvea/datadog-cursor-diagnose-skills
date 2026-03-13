# Incident Comms Prompt

You are extracting incident communications from a Zendesk Golden Ticket so a TSE can forward them to their customer.

## Input

The TSE has provided a Zendesk ticket ID (e.g. `#2531965`). This ticket is linked to a Datadog incident.

---

## Step 1 — AI Compliance Check (MANDATORY FIRST)

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

If output contains `ai_optout:true` → **STOP**. Output: `[AI BLOCKED — customer opted out of GenAI]`

---

## Step 2 — Detect the Incident Tag

Read the ticket tags (already retrieved in Step 1). Look for:
- `incident` → confirms this is an incident ticket
- `incident_XXXXX` → extract the incident number (e.g. `incident_50999` → `50999`)

If neither tag is found → output:
```
❌ Ticket #{TICKET_ID} does not appear to be linked to a Datadog incident (no incident_XXXXX tag found).
```
And stop.

---

## Step 3 — Find the Golden Ticket

Write this JS to `/tmp/zd_find_golden.js` and run it:

```bash
cat > /tmp/zd_find_golden.js << 'JSEOF'
var incidentTag = "incident_{INCIDENT_NUMBER}";
var xhr = new XMLHttpRequest();
xhr.open('GET', '/api/v2/search.json?query=tags:' + incidentTag + '&per_page=100', false);
xhr.send();
var data = JSON.parse(xhr.responseText);
var out = 'TOTAL:' + data.count + '\n';
for (var i = 0; i < data.results.length; i++) {
  var t = data.results[i];
  var isGolden = t.subject.toLowerCase().indexOf('golden') > -1 ||
                 t.subject.toLowerCase().indexOf('gold') > -1 ||
                 t.subject.toLowerCase().indexOf('internal') > -1;
  out += t.id + ' | ' + t.status + ' | golden:' + isGolden + ' | ' + t.subject + '\n';
}
out;
JSEOF
source ~/.cursor/skills/_shared/chrome-helper.sh && chrome_exec_js_file 1 2 /tmp/zd_find_golden.js
```

From the results, identify the Golden Ticket:
- Look for a ticket with "GOLDEN TICKET", "GOLD TICKET", or "INTERNAL" in the subject
- It is typically the single coordination ticket created by the incident response team
- If multiple candidates exist, pick the one with "GOLDEN" in the subject

If no golden ticket is found → output:
```
⚠️ No Golden Ticket found for incident_{INCIDENT_NUMBER}. There are {TOTAL} tickets tagged with this incident.
Here are all {TOTAL} tickets — check manually:
{list}
```

---

## Step 4 — Extract All Communications from the Golden Ticket

```bash
~/.cursor/skills/_shared/zd-api.sh comments {GOLDEN_TICKET_ID} 0
```

This returns all comments (full body, `0` = no truncation).

---

## Step 5 — Filter to Public/Outbound Comments Only

From the comments, keep only **public outbound** ones (the actual customer communications). Skip:
- Internal notes (they are marked as `public: false` in the API, but we can infer them by content: they typically start with brackets like `[Internal]`, contain only routing/SLA info, or are from automated bots like SLA triggers)
- Auto-generated bot messages (author IDs matching known bot IDs like `-1`)

The real communications will be authored by a TSE (human author_id > 0) and contain actual incident update text like "We are currently investigating...", "We identified the cause...", "We can confirm...".

---

## Step 6 — Output

Print the following in chat, newest communication first:

```
🚨 INCIDENT #{INCIDENT_NUMBER} — Golden Ticket #{{GOLDEN_TICKET_ID}}
Subject: {golden ticket subject}
Status: {golden ticket status}
Total tickets in this incident: {TOTAL}

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

## Notes

- Always show **all** communications, not just the latest (TSE picks which to use)
- The "LATEST COMMUNICATION TO REUSE" block at the bottom makes it easy to grab the most recent one
- If the incident is still ongoing (golden ticket status = `open`), add a banner: `⚠️ INCIDENT STILL ONGOING — no resolution communication yet`
