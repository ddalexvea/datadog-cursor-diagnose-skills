---
name: zendesk-ticket-pool
description: Check and display the current Zendesk ticket pool assigned to the user. Uses Chrome JS execution (real-time, no delay) as primary method, with Glean MCP as fallback. Use when the user asks about their ticket queue, open tickets, pending tickets, ticket pool, ticket status, workload, or wants to see what tickets need attention. This skill should be used proactively at the start of conversations when working in the TSE workspace.
---

# Zendesk Ticket Pool Checker

## Prerequisites

- **macOS** with `osascript`
- **Google Chrome** running with a tab open on `zendesk.com`
- **"Allow JavaScript from Apple Events"** enabled in Chrome (View > Developer > Allow JavaScript from Apple Events) — one-time setup

## How It Works

Two methods available, tried in order:

1. **Chrome JS (primary)** — Real-time via `osascript` + Zendesk API through Chrome's authenticated session. No delay.
2. **Glean MCP (fallback)** — If Chrome is unavailable or the JS call fails. Has up to 30 minutes indexing latency.

## Instructions

### Step 1: Try Chrome JS (Real-Time)

#### 1a: Find the Zendesk tab in Chrome

```bash
osascript -e '
tell application "Google Chrome"
    set tabIndex to -1
    repeat with w in windows
        set tabCount to count of tabs of w
        repeat with i from 1 to tabCount
            if URL of tab i of w contains "zendesk.com" then
                set tabIndex to i
                exit repeat
            end if
        end repeat
        if tabIndex > -1 then exit repeat
    end repeat
    return tabIndex
end tell'
```

If `tabIndex` is `-1`, Chrome has no Zendesk tab open — skip to **Step 2 (Glean Fallback)**.

#### 1b: Get current user (dynamic, never hardcode)

```bash
cat > /tmp/zd_pool_user.scpt << 'APPLESCRIPT'
tell application "Google Chrome"
    tell tab {TAB_INDEX} of window 1
        set jsCode to "var xhr = new XMLHttpRequest(); xhr.open('GET', '/api/v2/users/me.json', false); xhr.send(); if (xhr.status === 200) { var u = JSON.parse(xhr.responseText).user; u.id + ' | ' + u.name + ' | ' + u.email; } else { 'ERROR: HTTP ' + xhr.status; }"
        return (execute javascript jsCode)
    end tell
end tell
APPLESCRIPT

osascript /tmp/zd_pool_user.scpt
```

If this returns an error (e.g., JS execution disabled), skip to **Step 2 (Glean Fallback)**.

#### 1c: Fetch all active tickets (new + open + pending)

Run **two commands in parallel** to get all ticket statuses:

**Search 1 — New/Open tickets:**
```bash
cat > /tmp/zd_pool_open.scpt << 'APPLESCRIPT'
tell application "Google Chrome"
    tell tab {TAB_INDEX} of window 1
        set jsCode to "var xhr = new XMLHttpRequest(); xhr.open('GET', '/api/v2/search.json?query=type:ticket+assignee:me+(status:new+OR+status:open)&sort_by=updated_at&sort_order=desc', false); xhr.send(); if (xhr.status === 200) { var data = JSON.parse(xhr.responseText); var result = 'TOTAL:' + data.count + '\\n'; data.results.forEach(function(t) { var tags = (t.tags || []).join(','); result += t.id + ' | ' + t.status + ' | ' + (t.priority || 'none') + ' | ' + t.updated_at + ' | ' + t.created_at + ' | ' + (t.subject || '') + ' | ' + tags + '\\n'; }); result; } else { 'ERROR: HTTP ' + xhr.status; }"
        return (execute javascript jsCode)
    end tell
end tell
APPLESCRIPT

osascript /tmp/zd_pool_open.scpt
```

**Search 2 — Pending tickets:**
```bash
cat > /tmp/zd_pool_pending.scpt << 'APPLESCRIPT'
tell application "Google Chrome"
    tell tab {TAB_INDEX} of window 1
        set jsCode to "var xhr = new XMLHttpRequest(); xhr.open('GET', '/api/v2/search.json?query=type:ticket+assignee:me+status:pending&sort_by=updated_at&sort_order=desc', false); xhr.send(); if (xhr.status === 200) { var data = JSON.parse(xhr.responseText); var result = 'TOTAL:' + data.count + '\\n'; data.results.forEach(function(t) { var tags = (t.tags || []).join(','); result += t.id + ' | ' + t.status + ' | ' + (t.priority || 'none') + ' | ' + t.updated_at + ' | ' + t.created_at + ' | ' + (t.subject || '') + ' | ' + tags + '\\n'; }); result; } else { 'ERROR: HTTP ' + xhr.status; }"
        return (execute javascript jsCode)
    end tell
end tell
APPLESCRIPT

osascript /tmp/zd_pool_pending.scpt
```

#### 1d: Optionally fetch the specific view/filter

If the user provides a view URL like `https://datadog.zendesk.com/agent/filters/{VIEW_ID}`, fetch that view directly:

```bash
cat > /tmp/zd_pool_view.scpt << 'APPLESCRIPT'
tell application "Google Chrome"
    tell tab {TAB_INDEX} of window 1
        set jsCode to "var xhr = new XMLHttpRequest(); xhr.open('GET', '/api/v2/views/{VIEW_ID}/execute.json?sort_by=created_at&sort_order=desc', false); xhr.send(); if (xhr.status === 200) { var data = JSON.parse(xhr.responseText); var result = 'VIEW_COUNT:' + data.count + '\\n'; if (data.rows) { data.rows.forEach(function(r) { result += r.ticket_id + ' | ' + r.status + ' | ' + r.priority + ' | ' + r.updated + ' | ' + r.created + ' | ' + r.subject + '\\n'; }); } result; } else { 'ERROR: HTTP ' + xhr.status; }"
        return (execute javascript jsCode)
    end tell
end tell
APPLESCRIPT

osascript /tmp/zd_pool_view.scpt
```

Then skip to **Step 3: Parse & Present**.

---

### Step 2: Glean Fallback

Use this only if Chrome JS is unavailable (no Zendesk tab, JS execution disabled, etc.).

Run **two parallel** Glean searches:

**Search 1 - Open tickets:**
```
Tool: user-glean_ai-code-search
query: *
app: zendesk
dynamic_search_result_filters: assignee:Alexandre VEA|status:open
exhaustive: true
```

**Search 2 - Pending tickets:**
```
Tool: user-glean_ai-code-search
query: *
app: zendesk
dynamic_search_result_filters: assignee:Alexandre VEA|status:pending
exhaustive: true
```

**Note:** Glean data may be up to 30 minutes stale. Mention this in the output header.

---

### Step 3: Parse Ticket Data

From each result, extract:

| Field | Chrome JS Source | Glean Source |
|-------|-----------------|--------------|
| Ticket ID | `t.id` | URL path |
| Subject | `t.subject` | `title` |
| Status | `t.status` | `matchingFilters.status[0]` |
| Priority | `t.priority` | `matchingFilters.priority[0]` |
| Critical | tags contain `critical` | `matchingFilters.critical[0]` |
| Customer | tags containing `org:` pattern | `matchingFilters.datadogorgname[0]` |
| Product | tags containing PPC tag | `matchingFilters.producttype[0]` |
| Tier | tags containing tier tag | `matchingFilters.tier` |
| Replies | tags: `5_agent_replies`, `10_agent_replies`, etc. | same via `matchingFilters.label` |
| Follow-up | subject starts with `Re:` | title starts with `Re:` |
| Parent Ticket | detected from subject/tags | snippets for `follow-up to your previous request #XXXXXX` |
| Created | `t.created_at` | `createTime` |
| Updated | `t.updated_at` | `updateTime` |
| Wait Time | elapsed since updated_at | elapsed since updateTime |

### Follow-up Detection

A ticket is a **follow-up** when:
1. Subject/title starts with `Re:`
2. Content contains `follow-up to your previous request #XXXXXX`
3. Content contains `This is a follow-up to your previous request`

When detected:
- Extract the **parent ticket ID** (e.g. `#2386180` -> `2386180`)
- Mark with "Follow-up" indicator
- Reply counts on follow-ups reflect cumulative history
- Link parent: `[#parentID](https://datadog.zendesk.com/agent/tickets/parentID)`

### Step 4: Present Results

#### Header

```
## Ticket Pool - [Date] [Time]

**Source:** Chrome JS (real-time) | OR | **Source:** Glean (may be up to 30min stale)

**New:** X | **Open:** Y | **Pending:** Z | **Total: X+Y+Z**
```

#### Table (sorted by priority desc, then last update)

| # | Ticket | Subject | Status | Priority | Customer | Product | Replies | Tier | Updated | Notes |
|---|--------|---------|--------|----------|----------|---------|---------|------|---------|-------|

- Link ticket IDs: `[#ID](https://datadog.zendesk.com/agent/tickets/ID)`
- Truncate subjects to ~50 chars
- Show relative time for Updated (e.g. "2h ago", "1d ago")
- Flag critical tickets with an indicator
- Notes column: "Follow-up from [#parentID](link)" or "Critical" or empty

#### Attention Required

If tickets match BOTH: **Waiting > 24h** AND **10+ replies** → show:

```
### Attention Required - Stale & High-Touch Tickets

| Ticket | Subject | Status | Customer | Replies | Waiting Since |
|--------|---------|--------|----------|---------|---------------|
```

Skip if none match.

#### Action Items

1. **Needs Response** - New/Open tickets waiting for agent reply
2. **SLA Risk** - Critical or high-priority tickets with stale updates
3. **Pending Bump** - Pending tickets that may need customer follow-up
4. **High-Touch Stale** - 10+ replies AND waiting > 24h

### Deep Dive

If asked about a specific ticket, use `user-glean_ai-code-read_document` with the ticket URL.

## Filtering

For Chrome JS, modify the search query parameter:
- By status: `status:open`, `status:pending`, `status:new`
- By priority: `priority:high`, `priority:urgent`
- Combined: `type:ticket assignee:me status:open priority:high`

For Glean fallback, combine filters with `|` in `dynamic_search_result_filters`:
- Priority: `priority:high`
- Critical: `critical:true`
- Product: `producttype:Agent`
- Customer: `customer:<name>`
- Top 75: `top75org:true`
