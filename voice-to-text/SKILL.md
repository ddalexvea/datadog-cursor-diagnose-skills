---
name: voice-to-text
description: Enable voice-to-text input in Cursor using macOS native Dictation. Use when the user wants to dictate, use voice input, start dictation, transcribe speech, or says "listen to me". Handles setup verification and dictation triggering.
---

# Voice-to-Text for Cursor

## Overview

Uses macOS native Dictation to enable continuous voice-to-text input in Cursor. The agent can trigger dictation programmatically via AppleScript, and the transcribed text appears directly in the active text field (chat input, editor, terminal).

## Setup (one-time)

Run the setup script to verify macOS Dictation is properly configured:

```bash
bash ~/.cursor/skills/voice-to-text/scripts/setup.sh
```

If setup reports issues, guide the user:
1. Open **System Settings > Keyboard > Dictation**
2. Toggle Dictation **ON**
3. Set shortcut to **Press Fn Key Twice** (default)
4. Choose language (default: system language)
5. Enable **Auto-punctuation** for cleaner transcriptions

## Usage

### Starting Dictation

Run the dictation trigger script:

```bash
bash ~/.cursor/skills/voice-to-text/scripts/dictate.sh
```

This simulates pressing Fn Fn via AppleScript, which activates macOS Dictation in the currently focused text field.

After triggering, inform the user:

```
Dictation is now active. Speak naturally -- your words will appear in the
active text field. Dictation stays on continuously until you:
- Press Fn again
- Press Escape
- Click the microphone icon
```

### How It Works in Cursor

1. **In chat input** -- Click the chat input field, then trigger dictation. Speak your message, then press Enter to send.
2. **In editor** -- Click where you want text inserted, trigger dictation, and speak. Text is inserted at the cursor position.
3. **In terminal** -- Focus the terminal, trigger dictation, speak a command.

### Voice Commands (built into macOS Dictation)

These work automatically when dictation is active:
- "new line" -- inserts a line break
- "new paragraph" -- inserts a paragraph break
- "period" / "comma" / "question mark" -- inserts punctuation
- "open bracket" / "close bracket" -- inserts brackets
- "select all" / "undo" / "redo" -- editing commands
- "caps on" / "caps off" -- toggle capitalization

### Workflow

1. Press **Fn Fn** to start dictation
2. Speak your message
3. Press **Fn** to stop dictation
4. Press **Return** to submit

## Limitations

- The agent cannot read what was dictated -- text goes directly into the UI field
- For the agent to process dictated text, dictate into the chat input and press Enter
- Dictation requires an internet connection (unless Enhanced Dictation / on-device is enabled)
- The osascript command requires Accessibility permissions for Cursor

## Troubleshooting

If dictation doesn't start after running the script:

1. **Check Accessibility permissions**: System Settings > Privacy & Security > Accessibility -- ensure Cursor is listed and enabled
2. **Check Dictation is enabled**: System Settings > Keyboard > Dictation
3. **Try manually**: Press Fn Fn in Cursor to verify dictation works at all
4. **Microphone access**: System Settings > Privacy & Security > Microphone -- ensure Cursor has access
