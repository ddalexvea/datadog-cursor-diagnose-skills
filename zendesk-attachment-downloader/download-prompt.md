# Zendesk Attachment Downloader — Execution Prompt

Follow these steps exactly. Use the Shell tool with `required_permissions: ["all"]` for all osascript commands.

## Step 1: Extract ticket ID

Extract the Zendesk ticket ID from the user's message. It may appear as:
- `#2515683`, `ZD-2515683`, `2515683`
- A URL like `https://datadog.zendesk.com/agent/tickets/2515683`

Store the ticket ID for use in subsequent steps.

## Step 2: Find the Zendesk tab in Chrome

Run this osascript to locate a Chrome tab logged into Zendesk:

```bash
osascript << 'APPLESCRIPT'
tell application "Google Chrome"
    set foundTab to -1
    repeat with i from 1 to (count of tabs of window 1)
        if URL of tab i of window 1 contains "zendesk.com" then
            set foundTab to i
            exit repeat
        end if
    end repeat
    if foundTab is -1 then
        return "ERROR: No Zendesk tab found in Chrome. Please open https://datadog.zendesk.com in Chrome."
    end if
    return "OK:" & foundTab
end tell
APPLESCRIPT
```

If the result starts with `ERROR:`, stop and tell the user to open Zendesk in Chrome.

Extract the tab index number from the result (after `OK:`).

## Step 3: List attachments on the ticket

Write an AppleScript file to `/tmp/zd_list_attachments.scpt` that calls the Zendesk API via synchronous XMLHttpRequest. Replace `{TICKET_ID}` with the actual ticket ID:

```bash
cat > /tmp/zd_list_attachments.scpt << 'APPLESCRIPT'
tell application "Google Chrome"
    tell tab {TAB_INDEX} of window 1
        set jsCode to "var xhr = new XMLHttpRequest(); xhr.open('GET', '/api/v2/tickets/{TICKET_ID}/comments.json', false); xhr.send(); if (xhr.status === 200) { var data = JSON.parse(xhr.responseText); var attachments = []; data.comments.forEach(function(c) { if (c.attachments) { c.attachments.forEach(function(a) { attachments.push(a.file_name + ' | ' + Math.round(a.size/1024/1024*100)/100 + ' MB | ' + a.content_type + ' | ' + a.content_url); }); } }); attachments.length > 0 ? attachments.join('\\n') : 'NO_ATTACHMENTS'; } else { 'ERROR: HTTP ' + xhr.status; }"
        return (execute javascript jsCode)
    end tell
end tell
APPLESCRIPT

osascript /tmp/zd_list_attachments.scpt
```

**Important:** Replace `{TAB_INDEX}` with the actual tab index from Step 2, and `{TICKET_ID}` with the actual ticket ID.

Parse the output. Each line has format: `filename | size MB | content_type | content_url`

If the result is `NO_ATTACHMENTS`, tell the user there are no attachments on this ticket.
If the result starts with `ERROR:`, report the error.

## Step 4: Display attachment list

Show the user a table of attachments found:

```
| # | File | Size | Type |
|---|------|------|------|
| 1 | flare-2024-hostname.zip | 52.3 MB | application/zip |
| 2 | screenshot.png | 0.5 MB | image/png |
```

## Step 5: Download attachments

For each attachment to download, write an AppleScript file that creates a download link and clicks it:

```bash
cat > /tmp/zd_download.scpt << 'APPLESCRIPT'
tell application "Google Chrome"
    tell tab {TAB_INDEX} of window 1
        return (execute javascript "var a=document.createElement('a');a.href='{CONTENT_URL}';a.download='{FILENAME}';document.body.appendChild(a);a.click();document.body.removeChild(a);'Download triggered: {FILENAME}'")
    end tell
end tell
APPLESCRIPT

osascript /tmp/zd_download.scpt
```

**Important:** Replace `{TAB_INDEX}`, `{CONTENT_URL}`, and `{FILENAME}` with actual values.

If there are multiple attachments to download, download them sequentially with a 2-second delay between each.

## Step 6: Verify downloads

Wait 3 seconds, then check that files appeared in `~/Downloads/`:

```bash
ls -la ~/Downloads/{FILENAME}
```

Report success or failure for each file.

## Step 7: Handle agent flares

If any downloaded file matches the pattern `datadog-agent-*.zip`:

1. Create an extraction directory:
   ```bash
   mkdir -p ~/Downloads/flare-extracted-{TICKET_ID}
   ```

2. Extract the flare:
   ```bash
   unzip -o ~/Downloads/{FLARE_FILENAME} -d ~/Downloads/flare-extracted-{TICKET_ID}/
   ```

3. Find the flare root (the directory containing `status.log`):
   ```bash
   find ~/Downloads/flare-extracted-{TICKET_ID} -name "status.log" -maxdepth 3
   ```

4. Tell the user the flare is extracted and offer to run analysis:
   - "Run flare-network-analysis on this flare?"
   - "Run flare-profiling-analysis on this flare?"

## Step 8: Summary

Display a summary of what was downloaded:

```
## Download Summary — Ticket #{TICKET_ID}

| File | Size | Status | Location |
|------|------|--------|----------|
| flare-2024-hostname.zip | 52.3 MB | Downloaded + Extracted | ~/Downloads/flare-extracted-{TICKET_ID}/ |
| screenshot.png | 0.5 MB | Downloaded | ~/Downloads/screenshot.png |
```

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| "No Zendesk tab found" | Chrome not open or no Zendesk tab | Ask user to open `datadog.zendesk.com` in Chrome |
| "Executing JavaScript through AppleScript is turned off" | Chrome setting not enabled | Guide user: View → Developer → Allow JavaScript from Apple Events |
| "ERROR: HTTP 404" | Ticket not found or no access | Verify ticket ID and Zendesk permissions |
| "ERROR: HTTP 401/403" | Session expired | Ask user to log into Zendesk in Chrome |
| Download file not found | Download blocked or failed | Check Chrome download settings, try direct `curl` with content_url |

## Cleanup

After analysis is complete, the temporary script files can be removed:
```bash
rm -f /tmp/zd_list_attachments.scpt /tmp/zd_download.scpt
```
