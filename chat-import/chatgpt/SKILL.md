---
name: chatgpt-import
description: Import ChatGPT conversations to local markdown files for Cursor context. Uses Chrome JS to extract conversations from an open chatgpt.com tab. Use when the user mentions import chatgpt, chatgpt history, transfer chatgpt, chatgpt conversations, or bring chatgpt chats to cursor.
---

# ChatGPT Chat Importer

Extracts conversations from ChatGPT via the user's authenticated Chrome session and saves them as markdown files in `~/.cursor/knowledge/chatgpt-chats/`.

## Prerequisites

- **macOS** with `osascript`
- **Google Chrome** with a tab open on `chatgpt.com`
- **"Allow JavaScript from Apple Events"** enabled in Chrome

## Instructions

### Step 1: List Conversations

```bash
~/.cursor/skills/_shared/chatgpt-api.sh list
```

Output: `conversation_id | title` (one per line, from sidebar — up to ~30 recent)

Present as a numbered table:

| # | Title | ID |
|---|-------|----|

### Step 2: User Selects Conversations

Ask which conversations to import. Accept:
- Numbers: `1, 3, 5` or `1-5`
- `all` for everything listed
- A title keyword search

### Step 3: Import Selected

For each selected conversation:

```bash
~/.cursor/skills/_shared/chatgpt-api.sh save "<conversation_id>" ~/.cursor/knowledge/chatgpt-chats
```

Each save takes ~5 seconds (navigates to conversation, scrapes DOM, navigates back).

If importing multiple, run sequentially with output progress:
```
Importing 1/5: Cursor Skills for TSE... done
Importing 2/5: Windows 2012 Agent... done
```

### Step 4: Summary

```
## Import Summary

| # | Title | File | Status |
|---|-------|------|--------|
| 1 | ... | ~/.cursor/knowledge/chatgpt-chats/2026-03-01-... | Imported |

Total: X conversations imported to ~/.cursor/knowledge/chatgpt-chats/
Reference them in Cursor with: @~/.cursor/knowledge/chatgpt-chats/
```

## How It Works

1. Reads conversation list from the ChatGPT sidebar DOM (`nav a[href*="/c/"]`)
2. Navigates the tab to each conversation URL
3. Scrapes messages via `[data-message-author-role]` attributes
4. Converts to markdown with `## User` / `## Assistant` sections
5. Saves with filename: `{date}-{sanitized-title}.md`
6. Navigates back to original page

## Limitations

- Only conversations visible in the sidebar (~30 most recent)
- Navigates the active ChatGPT tab during extraction (visible to user)
- ~5 seconds per conversation
- Uses undocumented ChatGPT DOM structure (may break if UI changes)

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file |
| `~/.cursor/skills/_shared/chatgpt-api.sh` | Extraction script |
| `~/.cursor/knowledge/chatgpt-chats/` | Output directory |
