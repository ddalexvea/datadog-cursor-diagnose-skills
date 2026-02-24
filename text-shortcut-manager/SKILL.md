---
name: text-shortcut-manager
description: Detect recurring phrases from Cursor transcripts and manage espanso text shortcuts. Use when the user asks to scan patterns, add a text shortcut, list shortcuts, install espanso, or optimize their typing workflow.
---

# Text Shortcut Manager

Detects phrases you type repeatedly across Cursor conversations and manages espanso text shortcuts to save time. Works everywhere -- Chrome, Zendesk, Cursor, any app.

## Setup (run once)

### Step 1: Install espanso

Check if espanso is installed:

```bash
which espanso && espanso --version
```

If not installed:

```bash
brew install espanso
```

This requires sudo -- if running from Cursor terminal fails, tell the user to run `brew install espanso` in their regular Terminal.app.

### Step 2: Create config

```bash
mkdir -p ~/Library/Application\ Support/espanso/config
mkdir -p ~/Library/Application\ Support/espanso/match
```

Create `~/Library/Application Support/espanso/config/default.yml`:

```yaml
backend: Clipboard
```

Create `~/Library/Application Support/espanso/match/base.yml`:

```yaml
matches: []
```

### Step 3: Start espanso

```bash
open -a Espanso
```

Espanso will ask for **Accessibility permissions** on first launch. The user must grant it via System Settings > Privacy & Security > Accessibility > enable Espanso.

### Step 4: Verify

```bash
pgrep -f espanso > /dev/null && echo "Espanso is running" || echo "Not running"
```

## Usage

### Scan for recurring phrases

```bash
python3 ~/.cursor/skills/text-shortcut-manager/scripts/scan.py full
```

Incremental (only new transcripts since last scan):

```bash
python3 ~/.cursor/skills/text-shortcut-manager/scripts/scan.py incremental
```

### Add a shortcut

When the user says **"add shortcut"** or **"create shortcut ;name for [text]"**:

```bash
python3 ~/.cursor/skills/text-shortcut-manager/scripts/manage.py add ";trigger" "replacement text"
```

Espanso picks it up immediately -- no restart needed.

### List current shortcuts

```bash
python3 ~/.cursor/skills/text-shortcut-manager/scripts/manage.py list
```

### Remove a shortcut

```bash
python3 ~/.cursor/skills/text-shortcut-manager/scripts/manage.py remove ";trigger"
```

## How to use espanso

Once set up, type any trigger (e.g., `;hello`) in **any app** and espanso instantly replaces it with the full text. No special activation needed -- just type the trigger.

| Example trigger | What happens |
|----------------|-------------|
| `;hello` | Expands to your greeting template |
| `;sig` | Expands to your email signature |
| `;closing` | Expands to your ticket closing message |

Triggers use `;` prefix to avoid conflicts with normal typing.

## Workflow

### Pattern detection -> shortcut creation

1. Run scan to find repeated phrases
2. Present top suggestions to the user with recommended trigger names
3. If user approves, create the espanso shortcut via `manage.py add`
4. User can immediately use the new trigger anywhere

### Direct shortcut creation

User says "add a shortcut ;xyz for [some text]" -> run `manage.py add` directly.

## How detection works

1. Scans `~/.cursor/projects/*/agent-transcripts/*.txt` across all workspaces
2. Extracts user messages from `<user_query>` tags
3. Normalizes and deduplicates sentences
4. Filters noise (short phrases, URLs, commands)
5. Ranks by frequency and presents top results

## Configuration

Edit constants at the top of `scripts/scan.py`:

| Setting | Default | Description |
|---------|---------|-------------|
| `MIN_PHRASE_WORDS` | 5 | Minimum words to count as a phrase |
| `MIN_PHRASE_LENGTH` | 25 | Minimum characters |
| `MIN_OCCURRENCES` | 2 | Minimum times seen to be reported |
| `TOP_N` | 20 | Number of results to display |
