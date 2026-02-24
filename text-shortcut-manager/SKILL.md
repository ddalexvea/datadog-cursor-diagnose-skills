---
name: text-shortcut-manager
description: Detect recurring phrases from Cursor transcripts and manage espanso text shortcuts. Use when the user asks to scan patterns, add a text shortcut, list shortcuts, or optimize their typing workflow.
---

# Text Shortcut Manager

Detects phrases you type repeatedly across Cursor conversations and manages espanso text shortcuts to save time. Works everywhere -- Chrome, Zendesk, Cursor, any app.

## Prerequisites

- **espanso** installed (`brew install espanso`) and running
- Espanso config at `~/Library/Application Support/espanso/match/base.yml`

## Commands

### 1. Scan for recurring phrases

```bash
python3 ~/.cursor/skills/text-shortcut-manager/scripts/scan.py full
```

Or incremental (only new transcripts):

```bash
python3 ~/.cursor/skills/text-shortcut-manager/scripts/scan.py incremental
```

### 2. Add a shortcut

When the user says **"add shortcut"** or **"create shortcut ;name for [text]"**:

```bash
python3 ~/.cursor/skills/text-shortcut-manager/scripts/manage.py add ";trigger" "replacement text"
```

### 3. List current shortcuts

```bash
python3 ~/.cursor/skills/text-shortcut-manager/scripts/manage.py list
```

### 4. Remove a shortcut

```bash
python3 ~/.cursor/skills/text-shortcut-manager/scripts/manage.py remove ";trigger"
```

## Workflow

### Pattern detection -> shortcut creation

1. Run scan to find repeated phrases
2. Present top suggestions to the user
3. If user approves, create the espanso shortcut automatically via `manage.py add`
4. Espanso picks it up immediately -- no restart needed

### Direct shortcut creation

User says "add a shortcut ;xyz for [some text]" -> run `manage.py add` directly.

## How detection works

1. Parses `.txt` transcripts from the agent-transcripts folder
2. Extracts user messages from `<user_query>` tags
3. Normalizes and deduplicates sentences
4. Filters noise (short phrases, URLs, commands)
5. Ranks by frequency

## Configuration

Edit constants at the top of `scripts/scan.py`:

| Setting | Default | Description |
|---------|---------|-------------|
| `MIN_PHRASE_WORDS` | 5 | Minimum words to count as a phrase |
| `MIN_PHRASE_LENGTH` | 25 | Minimum characters |
| `MIN_OCCURRENCES` | 2 | Minimum times seen to be reported |
| `TOP_N` | 20 | Number of results to display |
