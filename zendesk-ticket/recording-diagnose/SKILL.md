---
name: zendesk-ticket-recording-diagnose
description: Analyze a session recording associated with a Zendesk ticket. Searches for recordings labeled with the ticket ID in ~/.kanban/recordings/. If found, reads screenshots, annotations, audio transcripts, and navigation events to extract diagnostic context. Use when the user mentions "check recording for ZD-XXXXXX", "analyze recording for ticket", "recording diagnose", or when the investigator skill wants recording context for a ticket.
kanban: true
kanban_columns: investigation
---

# Recording Diagnose

Analyzes session recordings captured via the Kanban extension for a specific Zendesk ticket. Recordings are labeled by the TSE with the ticket ID (e.g., "ZD-1234567") to link them to investigations.

## How to Use

Say: **"check recording for ZD-1234567"** or **"analyze recording for ticket 1234567"**

Or called automatically by the `zendesk-ticket-investigator` skill as Step 0 of its investigation.

## Step 1: Find Recordings for the Ticket

Search `~/.kanban/recordings/` for JSON files with a matching label:

```bash
TICKET_ID="{{TICKET_ID}}"

# Find all session JSON files
for f in ~/.kanban/recordings/*.json; do
  label=$(python3 -c "import json; d=json.load(open('$f')); print(d.get('label',''))" 2>/dev/null)
  if echo "$label" | grep -qi "$TICKET_ID"; then
    echo "$f | label=$label"
  fi
done
```

**If no recordings found:** Output `No recording found for ZD-{{TICKET_ID}}. Skipping recording analysis.` and stop — do NOT open any browser or app.

**If multiple recordings found:** Analyze all of them, noting each session's timestamp.

## Step 2: Parse the Recording

For each matching recording file, extract its events:

```bash
SESSION_FILE="~/.kanban/recordings/{{SESSION_ID}}.json"

python3 - <<'EOF'
import json, sys
from datetime import datetime

with open("$SESSION_FILE") as f:
    session = json.load(f)

started = datetime.fromtimestamp(session['startedAt'] / 1000).strftime('%Y-%m-%d %H:%M:%S')
label = session.get('label', 'unlabeled')
events = session.get('events', [])

print(f"SESSION: {session['id']}")
print(f"LABEL: {label}")
print(f"STARTED: {started}")
print(f"TOTAL_EVENTS: {len(events)}")
print()

# Collect by type
screenshots = [e for e in events if e['type'] == 'screenshot']
annotations = [e for e in events if e['type'] == 'annotation']
voice_events = [e for e in events if e['type'] == 'voice']
nav_events   = [e for e in events if e['type'] == 'navigation']
http_events  = [e for e in events if e['type'] == 'http']

print(f"SCREENSHOTS: {len(screenshots)}")
print(f"ANNOTATIONS: {len(annotations)}")
print(f"VOICE_SEGMENTS: {len(voice_events)}")
print(f"NAVIGATIONS: {len(nav_events)}")
print(f"HTTP_REQUESTS: {len(http_events)}")
print()

# Print voice transcript (chronological)
if voice_events:
    print("=== AUDIO TRANSCRIPT ===")
    for e in voice_events:
        t = e.get('detail', {}).get('transcript', '')
        if t and t.strip() not in ('[Motor]', ''):
            ms = e.get('offsetMs', 0)
            print(f"[{ms//1000}s] {t}")
    print()

# Print navigation timeline
if nav_events:
    print("=== NAVIGATION TIMELINE ===")
    for e in nav_events:
        ms = e.get('offsetMs', 0)
        detail = e.get('detail', {})
        url = e.get('url', '')
        title = detail.get('text', '') if isinstance(detail, dict) else ''
        print(f"[{ms//1000}s] {title} — {url[:80]}")
    print()

# Print annotation descriptions
if annotations:
    print("=== ANNOTATIONS ===")
    for i, e in enumerate(annotations):
        ms = e.get('offsetMs', 0)
        detail = e.get('detail', {}) if isinstance(e.get('detail'), dict) else {}
        atype = detail.get('annotationType', 'mark')
        label_text = detail.get('label', '')
        print(f"[{ms//1000}s] annotation-{i+1}: {atype}" + (f" — {label_text}" if label_text else ""))
    print()

# Print screenshot paths (for visual analysis)
if screenshots:
    print("=== SCREENSHOTS ===")
    for i, e in enumerate(screenshots):
        ms = e.get('offsetMs', 0)
        detail = e.get('detail', {}) if isinstance(e.get('detail'), dict) else {}
        path = detail.get('screenshotPath', '')
        print(f"[{ms//1000}s] screenshot-{i+1}: {path}")
    print()

# Print HTTP summary (method + URL only, no bodies)
if http_events:
    print("=== HTTP REQUESTS (summary) ===")
    for e in http_events[:30]:  # cap at 30
        ms = e.get('offsetMs', 0)
        detail = e.get('detail', {}) if isinstance(e.get('detail'), dict) else {}
        method = detail.get('method', '')
        url = detail.get('url', '')
        status = detail.get('status', '')
        if url:
            print(f"[{ms//1000}s] {method} {status} {url[:100]}")
    if len(http_events) > 30:
        print(f"... and {len(http_events) - 30} more HTTP events")

EOF
```

## Step 3: Analyze Screenshots

For each screenshot path returned in Step 2, use vision to read the screenshot:

- Tool: `Read` (file read tool) — read each screenshot image
- For each screenshot, note: what page is shown, any visible error messages, UI state, data displayed

If screenshot files don't exist (e.g., temp files were cleaned up): note "Screenshot files no longer available (temp files cleaned up)."

## Step 4: Correlate Annotations with Screenshots

Annotations mark regions of interest on screenshots. When an annotation appears at time `T`, it corresponds to the screenshot taken closest to time `T`.

For each annotation:
- Identify the corresponding screenshot (nearest in time)
- Note what the TSE was highlighting: the annotated region contains the area of interest
- If the annotation has a label, use it as the focus for that screenshot's analysis

## Step 5: Synthesize Recording Findings

Write a structured analysis section:

```markdown
## Recording Analysis — {{TICKET_ID}}

**Session:** {{SESSION_ID}} (recorded {{STARTED_AT}})
**Duration:** {{DURATION_SECONDS}}s
**Label:** {{LABEL}}

### TSE Audio Narration
(verbatim transcript, cleaned up — what the TSE described while recording)

### Navigation Flow
1. [0s] → Page/URL visited
2. [Xs] → Next page visited
...

### Visual Observations
- Screenshot 1 ([Xs]): What is visible, any errors, UI state
- Annotation at [Xs]: What the TSE circled/highlighted and why it seems relevant
...

### HTTP Activity (Notable Requests)
- [Xs] GET /api/v2/... → status — summary of what was being fetched

### Key Diagnostic Signals
- (most important observations from the recording relevant to the ticket investigation)
```

## Step 6: Return to Investigation

After completing the recording analysis, return the findings to the calling skill (`zendesk-ticket-investigator`) to be included in the investigation report under a `## Recording Analysis` section.

## Rules

- **Never open Chrome, a browser, or any URL** — recordings are local files only
- **If no recording is found**: output "No recording found for ZD-{{TICKET_ID}}. Skipping." and stop
- **If screenshot files are missing**: note it and continue — voice transcript and navigation are still valuable
- **Privacy**: Do not include raw HTTP request/response bodies in the report — only method, URL, and status code
- **Multiple sessions**: If multiple recordings exist for the same ticket, analyze all and merge findings chronologically
