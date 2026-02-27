# Zendesk Attachment Downloader — Execution Prompt

Follow these steps exactly. Use the Shell tool with `required_permissions: ["all"]` for all commands.

## Step 1: Extract ticket ID

Extract the Zendesk ticket ID from the user's message. It may appear as:
- `#2515683`, `ZD-2515683`, `2515683`
- A URL like `https://datadog.zendesk.com/agent/tickets/2515683`

## Step 2: List attachments on the ticket

```bash
~/.cursor/skills/_shared/zd-api.sh attachments {TICKET_ID}
```

Output format: `filename | size MB | content_type | content_url`

If the result is `NO_ATTACHMENTS`, tell the user. If it starts with `ERROR:`, report the error.

## Step 3: Display attachment list

Show the user a table:

```
| # | File | Size | Type |
|---|------|------|------|
| 1 | flare-2024-hostname.zip | 52.3 MB | application/zip |
| 2 | screenshot.png | 0.5 MB | image/png |
```

## Step 4: Download attachments

For each attachment to download:

```bash
~/.cursor/skills/_shared/zd-api.sh download "{CONTENT_URL}" "{FILENAME}"
```

If there are multiple attachments, download them sequentially with a 2-second delay between each.

## Step 5: Verify downloads

Wait 3 seconds, then check that files appeared in `~/Downloads/`:

```bash
ls -la ~/Downloads/{FILENAME}
```

## Step 6: Handle agent flares

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

## Step 7: Summary

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
| "Executing JavaScript through AppleScript is turned off" | Chrome setting not enabled | Guide user: View > Developer > Allow JavaScript from Apple Events |
| "ERROR: HTTP 404" | Ticket not found or no access | Verify ticket ID and Zendesk permissions |
| "ERROR: HTTP 401/403" | Session expired | Ask user to log into Zendesk in Chrome |
| Download file not found | Download blocked or failed | Check Chrome download settings, try direct `curl` with content_url |
