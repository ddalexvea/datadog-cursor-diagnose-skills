Investigate Zendesk ticket #{{TICKET_ID}} (Subject: {{SUBJECT}}).

## Step 0: AI Compliance Check (MANDATORY)

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {{TICKET_ID}}
```

If the output contains `ai_optout:true`, **STOP NOW**. Tell the user: "Ticket #{{TICKET_ID}}: AI processing is blocked — this customer has opted out of GenAI (oai_opted_out). Handle manually without AI." Do NOT proceed to any further steps.

## Step 1: Read the ticket

### Primary: Chrome JS (real-time)

```bash
~/.cursor/skills/_shared/zd-api.sh read {{TICKET_ID}} 0
```

This returns ticket metadata (filtered tags) + all comments (full body with `0`). For triage-only, omit `0` to get 500-char truncated comments.

### Fallback: Glean MCP

If Chrome is unavailable (ERROR output):
- Tool: user-glean_ai-code-read_document
- urls: ["https://datadog.zendesk.com/agent/tickets/{{TICKET_ID}}"]

Extract: customer name, org, priority, full problem description, any error messages or logs shared.
Identify the **product area** (agent, logs, APM, infra, NDM, DBM, containers, etc.) for later searches.

## Step 2: Download and analyze attachments

Use the `zendesk-attachment-downloader` skill to list and download attachments from the ticket.

### 2a: Find the Zendesk tab in Chrome

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
        return "ERROR: No Zendesk tab found"
    end if
    return "OK:" & foundTab
end tell
APPLESCRIPT
```

If `ERROR`: Skip attachment download and note "Chrome not available for attachment download" in the report. Continue to Step 3.

### 2b: List attachments

Write and execute an AppleScript file (replace `{TAB_INDEX}` and `{{TICKET_ID}}`):

```bash
cat > /tmp/zd_list_attachments.scpt << 'APPLESCRIPT'
tell application "Google Chrome"
    tell tab {TAB_INDEX} of window 1
        set jsCode to "var xhr = new XMLHttpRequest(); xhr.open('GET', '/api/v2/tickets/{{TICKET_ID}}/comments.json', false); xhr.send(); if (xhr.status === 200) { var data = JSON.parse(xhr.responseText); var attachments = []; data.comments.forEach(function(c) { if (c.attachments) { c.attachments.forEach(function(a) { attachments.push(a.file_name + ' | ' + Math.round(a.size/1024/1024*100)/100 + ' MB | ' + a.content_type + ' | ' + a.content_url); }); } }); attachments.length > 0 ? attachments.join('\\n') : 'NO_ATTACHMENTS'; } else { 'ERROR: HTTP ' + xhr.status; }"
        return (execute javascript jsCode)
    end tell
end tell
APPLESCRIPT

osascript /tmp/zd_list_attachments.scpt
```

If `NO_ATTACHMENTS`: Note in the report. Continue to Step 3.

### 2c: Download agent flares

If any attachment filename matches `datadog-agent-*.zip`:

1. Download it:
```bash
cat > /tmp/zd_download.scpt << 'APPLESCRIPT'
tell application "Google Chrome"
    tell tab {TAB_INDEX} of window 1
        return (execute javascript "var a=document.createElement('a');a.href='{CONTENT_URL}';a.download='{FILENAME}';document.body.appendChild(a);a.click();document.body.removeChild(a);'Download triggered'")
    end tell
end tell
APPLESCRIPT

osascript /tmp/zd_download.scpt
```

2. Wait for download and extract:
```bash
sleep 3
mkdir -p ~/Downloads/flare-extracted-{{TICKET_ID}}
unzip -o ~/Downloads/{FLARE_FILENAME} -d ~/Downloads/flare-extracted-{{TICKET_ID}}/
```

3. Find the flare root:
```bash
find ~/Downloads/flare-extracted-{{TICKET_ID}} -name "status.log" -maxdepth 3
```

4. Run flare analysis skills as appropriate:
   - If the ticket mentions **network issues, connectivity, forwarder, packet loss** → run `flare-network-analysis`
   - If the ticket mentions **memory, CPU, high resource usage, performance** → run `flare-profiling-analysis`
   - For general issues → read `status.log` for quick context (agent version, running checks, errors)

5. Include flare findings in the investigation report under a "## Flare Analysis" section.

### 2d: Download other attachments (optional)

Download screenshots, log files, or config files if they appear relevant to the investigation. Note their filenames in the report.

Clean up temp files:
```bash
rm -f /tmp/zd_list_attachments.scpt /tmp/zd_download.scpt
```

## Step 3: Search for similar past tickets
- Tool: user-glean_ai-code-search
- query: keywords from the ticket subject/description
- app: zendesk

Look for resolved tickets with similar symptoms. Note ticket IDs and solutions.

## Step 3: Search internal documentation
- Tool: user-glean_ai-code-search
- query: relevant product/feature keywords
- app: confluence

Look for runbooks, troubleshooting guides, known issues, escalation paths.

## Step 4: Search public documentation
- Tool: user-glean_ai-code-search
- query: relevant product/feature keywords
- app: glean help docs

Also check the public docs site directly if needed:
- Tool: user-glean_ai-code-read_document
- urls: ["https://docs.datadoghq.com/RELEVANT_PATH"]

Key doc paths by product area:
| Product | Doc URL |
|---------|---------|
| Agent | https://docs.datadoghq.com/agent/ |
| Logs | https://docs.datadoghq.com/logs/ |
| APM / Tracing | https://docs.datadoghq.com/tracing/ |
| Infrastructure | https://docs.datadoghq.com/infrastructure/ |
| NDM / SNMP | https://docs.datadoghq.com/network_monitoring/devices/ |
| DBM | https://docs.datadoghq.com/database_monitoring/ |
| Containers | https://docs.datadoghq.com/containers/ |
| Cloud Integrations | https://docs.datadoghq.com/integrations/ |
| Metrics | https://docs.datadoghq.com/metrics/ |
| Monitors | https://docs.datadoghq.com/monitors/ |
| Security | https://docs.datadoghq.com/security/ |

## Step 5: Search GitHub code & config parameters
Search the Datadog GitHub repos for relevant code, config parameters, or error messages.

- Tool: user-glean_ai-code-search
- query: error message or config parameter name
- app: github

Key GitHub repositories:
| Repo | URL | What it contains |
|------|-----|-----------------|
| datadog-agent | https://github.com/DataDog/datadog-agent | Core agent code, config parameters, checks |
| integrations-core | https://github.com/DataDog/integrations-core | Official integration checks (Python) |
| integrations-extras | https://github.com/DataDog/integrations-extras | Community integrations |
| documentation | https://github.com/DataDog/documentation | Source for docs.datadoghq.com |
| datadog-api-client-go | https://github.com/DataDog/datadog-api-client-go | Go API client |
| datadog-api-client-python | https://github.com/DataDog/datadog-api-client-python | Python API client |
| helm-charts | https://github.com/DataDog/helm-charts | Helm charts for K8s deployment |
| datadog-operator | https://github.com/DataDog/datadog-operator | Kubernetes operator |
| dd-trace-py | https://github.com/DataDog/dd-trace-py | Python APM tracer |
| dd-trace-java | https://github.com/DataDog/dd-trace-java | Java APM tracer |
| dd-trace-js | https://github.com/DataDog/dd-trace-js | Node.js APM tracer |
| dd-trace-rb | https://github.com/DataDog/dd-trace-rb | Ruby APM tracer |
| dd-trace-go | https://github.com/DataDog/dd-trace-go | Go APM tracer |
| dd-trace-dotnet | https://github.com/DataDog/dd-trace-dotnet | .NET APM tracer |

For config parameter lookup, key files in datadog-agent:
| File | What it contains |
|------|-----------------|
| `pkg/config/setup/config.go` | All agent config parameters with defaults |
| `cmd/agent/dist/datadog.yaml` | Default config template |
| `comp/core/config/` | Config component code |
| `pkg/logs/` | Logs agent code |
| `pkg/collector/` | Check collector code |

To search a specific repo for a parameter or error:
- Tool: user-github-search_code or user-github-2-search_code
- q: "parameter_name repo:DataDog/datadog-agent"

**IMPORTANT — Always build full GitHub links:**
When you find relevant code files, ALWAYS construct a clickable GitHub URL in the report using this format:
```
https://github.com/DataDog/{REPO}/blob/main/{FILE_PATH}
```
Example: if you find `_get_replication_role()` in `integrations-core/postgres/datadog_checks/postgres/postgres.py`, write:
```markdown
- [`postgres.py → _get_replication_role()`](https://github.com/DataDog/integrations-core/blob/main/postgres/datadog_checks/postgres/postgres.py) — Determines replication role via `SELECT pg_is_in_recovery()`
```
NEVER reference code files as plain text without a link. The TSE needs to click through to read the actual source.

## Step 6: Customer context
- Tool: user-glean_ai-code-search
- query: customer org name
- app: salescloud

Check for customer tier, MRR, top75 status, recent escalations.

## Step 7: Write investigation report

The report file is `investigations/ZD-{{TICKET_ID}}.md`. It uses a **timeline format**: a fixed header with ticket metadata, followed by timestamped investigation entries appended over time.

### 7a: Check if the file already exists

```bash
ls investigations/ZD-{{TICKET_ID}}.md 2>/dev/null
```

### 7b: If the file does NOT exist — create it with the header + first entry

Write the full file with this structure:

```markdown
# ZD-{{TICKET_ID}} — {{SUBJECT}}

## Ticket Summary
| Field | Value |
|-------|-------|
| **Customer** | ORG_NAME |
| **Priority** | PRIORITY |
| **Status** | STATUS |
| **Product** | PRODUCT_AREA |
| **Tier** | TIER |
| **MRR** | MRR_RANGE |
| **Complexity** | COMPLEXITY |
| **Type** | ISSUE_TYPE |
| **Created** | CREATED_DATE |

---

## Timeline

### YYYY-MM-DD HH:MM — Initial Investigation (SOURCE)

**Problem Summary**
(2-3 sentences describing the issue)

**Key Details**
- Error messages, logs, config snippets from the ticket

**Attachments**
| File | Size | Type | Notes |
|------|------|------|-------|
| filename | size MB | type | downloaded / analyzed / skipped |

**Flare Analysis** _(if applicable)_
- Flare hostname:
- Agent version:
- Key findings: (from flare-network-analysis or flare-profiling-analysis)
- Full report: `investigations/flare-{analysis-type}-{hostname}.md`

**Similar Past Tickets**
| Ticket | Subject | Resolution |
|--------|---------|------------|
| #ID | subject | how it was resolved |

**Relevant Documentation**
- Public: [Doc title](https://docs.datadoghq.com/...) - brief description
- Internal: [Doc title](confluence_url) - brief description

**Relevant Code**
- [`file.py → function_name()`](https://github.com/DataDog/REPO/blob/main/path/to/file.py) — what this code does
- [`config.go → paramName`](https://github.com/DataDog/datadog-agent/blob/main/pkg/config/setup/config.go) — default value, what it controls

_(Every code reference MUST include a clickable GitHub link. Never write file names as plain text.)_

**Initial Assessment**
- Category: (agent, logs, APM, infra, etc.)
- Likely cause:
- Suggested first steps:
  1. ...
  2. ...
  3. ...
```

At the very end of the file (after the last timeline entry), ALWAYS include these two sections:

**1. Customer Response Draft** (if investigation is complete enough to draft a response):

```markdown

## Customer Response Draft
<plain text response the TSE can copy-paste to the customer>
```

The response draft must contain plain text only — NO markdown headers, bold, italic, code blocks, or bullet points inside the draft content. Start with a greeting using the customer's first name. Direct, professional tone — no hedging. Include specific commands and doc links as needed. End with: "Best regards,\nAlexandre VEA\nTechnical Support Engineer 2 | Datadog"

**2. Investigation Decision** (ALWAYS required):

```markdown

## Investigation Decision
- Next: <ready_to_review|waiting|reproduction|investigation>
- Reason: <one-line explanation of why this is the right next step>
```

Rules for Next:
- **"ready_to_review"** — investigation is complete and a response can be drafted for the customer
- **"waiting"** — need more info from the customer before proceeding
- **"reproduction"** — need to reproduce the issue in a test environment
- **"investigation"** — need more investigation time (e.g. waiting on internal research, flare analysis pending)

Replace `SOURCE` with `Watcher` if called from the watcher, or `Agent` if called manually.
Replace `YYYY-MM-DD HH:MM` with the current date and time.

### 7c: If the file ALREADY exists — append a new timeline entry

Read the existing file content. Pay attention to these sections that may already exist:
- `## Review History` — contains TSE feedback and prior agent revisions. **Read this carefully** — if the TSE requested changes, address them in your new entry.
- `## Session Context` — contains CLI agent session transcript. **Preserve as-is** — do not modify or remove.
- `## Chat TLDR` — contains summary of prior interactive chat sessions. **Preserve as-is** — do not modify or remove.

Then **append** a new timeline entry under `## Timeline`:

```markdown

### YYYY-MM-DD HH:MM — Re-investigation (SOURCE)

**Trigger:** (why this re-investigation happened: customer replied, TSE requested, moved to investigation column, etc.)

**New Findings**
- What changed since the last entry
- New information from the customer
- Updated analysis based on new data

**Updated Assessment**
- Likely cause: (updated if changed)
- Next steps:
  1. ...
  2. ...
```

Only include sections that have new information. Do NOT duplicate the header or Ticket Summary.

After appending the new entry, update the `## Customer Response Draft` and `## Investigation Decision` sections. The expected section order at the end of the file is:

1. `## Customer Response Draft` — updated response for the customer
2. `## Review History` — preserved (only the Kanban UI appends TSE feedback here)
3. `## Session Context` — preserved as-is
4. `## Chat TLDR` — preserved as-is
5. `## Investigation Decision` — updated routing decision (always last)

### 7d: Update the Ticket Summary status

If the ticket status has changed since the header was written (e.g. Open → Pending → Solved), update the `| **Status** |` row in the Ticket Summary table to reflect the current status.

## Rules
- Keep it factual — only include what you found, don't speculate
- If no similar tickets found, say so
- If no docs found, say so
- ALWAYS include links to relevant public docs, internal docs, and GitHub code
- NEVER reference code files without a clickable GitHub link (e.g. `https://github.com/DataDog/REPO/blob/main/path/to/file`)
- Be concise but thorough
- NEVER overwrite previous timeline entries — always append
- Use the current timestamp for each new entry
- NEVER delete or modify existing `## Review History`, `## Session Context`, or `## Chat TLDR` sections — these are managed by the Kanban extension and interactive chat sessions
- When updating the file, maintain the section order: Timeline → Customer Response Draft → Review History → Session Context → Chat TLDR → Investigation Decision