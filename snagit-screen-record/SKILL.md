---
name: snagit-screen-record
description: Start a Snagit screen recording via voice or text commands. Use when the user says "start recording", "record screen", "capture video", or mentions Snagit recording.
---

# Snagit Screen Record

Control Snagit 2024 video capture from Cursor via AppleScript automation.

## Prerequisites

- Snagit 2024 installed at `/Applications/Snagit 2024.app`
- SnagitHelper2024 running (launches with Snagit)
- Cursor has Accessibility permissions (System Settings > Privacy & Security > Accessibility)
- **For voice commands**: the `voice-to-text` skill (macOS Dictation) must be set up first

Run setup check: `bash ~/.cursor/skills/snagit-screen-record/scripts/setup.sh`

## Usage

When the user types or dictates **"start recording"**, **"record screen"**, or **"capture video"**:

```bash
bash ~/.cursor/skills/snagit-screen-record/scripts/record.sh
```

### Text trigger
Type "start recording" in the chat.

### Voice trigger
Requires the `voice-to-text` skill. Press Fn Fn to activate Dictation, say "start recording", then Dictation sends the text to the chat and this skill picks it up.

## Workflow

1. User types or dictates "start recording"
2. Agent runs the script
3. Snagit capture overlay appears
4. User selects the recording area and clicks Record
5. User stops the recording via Snagit's floating stop button

## Troubleshooting

- **Nothing happens**: Check Accessibility permissions and run `setup.sh`
- **Snagit not running**: Script auto-launches Snagit
