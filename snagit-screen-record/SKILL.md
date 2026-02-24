---
name: snagit-screen-record
description: Start and stop Snagit screen recordings via voice or text commands. Use when the user says "start recording", "stop recording", "screen record", "capture video", or mentions Snagit recording.
---

# Snagit Screen Record

Control Snagit 2024 video capture from Cursor via AppleScript automation.

## Prerequisites

- Snagit 2024 installed at `/Applications/Snagit 2024.app`
- SnagitHelper2024 running (launches with Snagit)
- Cursor has Accessibility permissions (System Settings > Privacy & Security > Accessibility)

Run setup check: `bash ~/.cursor/skills/snagit-screen-record/scripts/setup.sh`

## Commands

### Start Recording

When the user says **"start recording"**, **"record screen"**, or **"capture video"**:

```bash
bash ~/.cursor/skills/snagit-screen-record/scripts/record.sh start
```

This activates Snagit, ensures video capture mode, and triggers the capture hotkey. The user then selects the screen region and clicks "Record".

### Stop Recording

When the user says **"stop recording"** or **"stop capture"**:

```bash
bash ~/.cursor/skills/snagit-screen-record/scripts/record.sh stop
```

This triggers the stop shortcut. The recording opens in Snagit Editor for review/saving.

### Toggle (Start/Stop)

When the user says just **"recording"** or **"toggle recording"**:

```bash
bash ~/.cursor/skills/snagit-screen-record/scripts/record.sh toggle
```

## Workflow

1. User says "start recording"
2. Agent runs the start script
3. Snagit capture overlay appears -- user selects region and clicks Record
4. User does their work
5. User says "stop recording"
6. Agent runs the stop script
7. Recording opens in Snagit Editor

## Troubleshooting

- **Nothing happens**: Check Accessibility permissions and run `setup.sh`
- **Wrong capture mode**: Script auto-switches to video mode if needed
- **Snagit not running**: Script auto-launches Snagit
