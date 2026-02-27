---
name: glean-mcp-recovery
description: Healthcheck and auto-recovery for Glean MCP (glean_ai-code). Use when Glean tools fail, timeout, or are unavailable. Also used as a prerequisite by all Glean-dependent skills to verify connectivity before proceeding.
---

# Glean MCP Recovery

Prerequisite check for all skills that depend on `glean_ai-code` MCP tools.

## Glean Prerequisite Check (run before any Glean call)

### Step 1: Test Glean connectivity

Run a minimal search to verify Glean is responding:

```
Tool: user-glean_ai-code-search
query: *
app: zendesk
head_limit: 1
```

### Step 2: Evaluate result

**If the call succeeds** (returns results or empty results without error):
- Glean is working. Proceed with the parent skill.

**If the call fails** (error, timeout, tool not found, connection refused):
- Tell the user: "Glean MCP is down. Auto-recovering now..."
- Run the **Auto-Recovery Procedure** below.

## Auto-Recovery Procedure

This toggles the MCP off and back on by editing `~/.cursor/mcp.json`.

### Step 1: Disable glean_ai-code

Read `~/.cursor/mcp.json`, then edit the `glean_ai-code` entry to add `"disabled": true`:

```json
"glean_ai-code": {
  "disabled": true,
  "type": "http",
  "url": "https://datadog-be.glean.com/mcp/ai-code",
  "headers": {}
}
```

Use `StrReplace` on `~/.cursor/mcp.json` to add the `"disabled": true` line inside the `glean_ai-code` block.

### Step 2: Wait for Cursor to pick up the change

```
Shell: sleep 5
```

### Step 3: Re-enable glean_ai-code

Use `StrReplace` on `~/.cursor/mcp.json` to remove the `"disabled": true,` line (revert to original).

The entry should be back to:
```json
"glean_ai-code": {
  "type": "http",
  "url": "https://datadog-be.glean.com/mcp/ai-code",
  "headers": {}
}
```

### Step 4: Wait for reconnection

```
Shell: sleep 8
```

### Step 5: Verify recovery

Try the healthcheck again:

```
Tool: user-glean_ai-code-search
query: *
app: zendesk
head_limit: 1
```

**If it works:** Tell the user "Glean MCP recovered." and proceed with the original skill.

**If it still fails:** Tell the user:

```
Auto-recovery didn't work. Manual fix needed:

1. Cmd+Shift+P → "Cursor Settings"
2. Go to "Tools & MCP"
3. Find "glean_ai-code" → toggle OFF, wait 3s, toggle ON
4. Wait for green indicator, then ask me again
```

Then **stop**. Do NOT retry further. Do NOT loop.

## When This Skill is Activated Directly

Triggers: "fix glean", "glean not working", "glean mcp down", "reset glean", "glean broken"

When triggered directly (not as a prerequisite), run the healthcheck and auto-recovery if needed.

## Tool Reference

All Glean-dependent skills must use these `glean_ai-code` tool names:

| Operation | Tool |
|-----------|------|
| Search Zendesk/Confluence/Salesforce | `user-glean_ai-code-search` |
| Read a URL (ticket, doc, page) | `user-glean_ai-code-read_document` |
| Search internal code repos | `user-glean_ai-code-code_search` |
| AI-powered question answering | `user-glean_ai-code-code-chat` |
| Find employees | `user-glean_ai-code-employee_search` |
| Search Gmail | `user-glean_ai-code-gmail_search` |
| Search meetings/transcripts | `user-glean_ai-code-meeting_lookup` |
| Get user activity | `user-glean_ai-code-user_activity` |
