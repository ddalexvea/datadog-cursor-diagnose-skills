---
name: glean-chat-import
description: Import Glean Chat conversations to local markdown files for Cursor context. Uses Chrome JS DOM scraping from an open app.glean.com/chat tab. Use when the user mentions import glean chat, glean history, transfer glean conversations, or bring glean chats to cursor.
---

# Glean Chat Importer

Extracts conversations from Glean Chat via the user's authenticated Chrome session and saves them as markdown files in `~/.cursor/knowledge/glean-chats/`.

## Prerequisites

- **macOS** with `osascript`
- **Google Chrome** with a tab open on `app.glean.com/chat`
- **"Allow JavaScript from Apple Events"** enabled in Chrome

## Instructions

### Step 1: List Conversations

```bash
~/.cursor/skills/_shared/glean-chat-api.sh list
```

Output: `chat_id | title` (from the sidebar, limited to visible/loaded chats)

Present as a numbered table:

| # | Title | ID |
|---|-------|----|

### Step 2: User Selects Conversations

Ask which conversations to import. Accept:
- Numbers: `1, 3` or `all`
- A title keyword

### Step 3: Import Selected

For each selected conversation:

```bash
~/.cursor/skills/_shared/glean-chat-api.sh save "<chat_id>" ~/.cursor/knowledge/glean-chats
```

If the chat is not currently displayed, the script navigates to it first (~3-5s).

### Step 4: Summary

```
## Import Summary

| # | Title | File | Status |
|---|-------|------|--------|
| 1 | ... | ~/.cursor/knowledge/glean-chats/2026-03-01-... | Imported |

Total: X conversations imported to ~/.cursor/knowledge/glean-chats/
Reference them in Cursor with: @~/.cursor/knowledge/glean-chats/
```

## How It Works

1. Reads chat list from the Glean sidebar DOM (virtualized scroll container)
2. Navigates to selected chat if not current
3. Extracts message turns from `.wgjulhk` elements:
   - User queries from `.wehdmg1` / `pre`
   - AI responses from `._1bdmgj40`
   - Source references from `._745pmg0`
4. Converts to markdown with `## User` / `## Assistant` sections + **Sources:** lists
5. Saves with filename: `{date}-{sanitized-title}.md`

## Limitations

- Glean retains chats for 30 days only
- Only chats loaded in sidebar are listable (no API access due to CORS)
- Uses DOM class selectors (obfuscated names — may break on Glean UI updates)
- AI responses that were "stopped" will show "Stopped generating a response."

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file |
| `~/.cursor/skills/_shared/glean-chat-api.sh` | Extraction script |
| `~/.cursor/knowledge/glean-chats/` | Output directory |
