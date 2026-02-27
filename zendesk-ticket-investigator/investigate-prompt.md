Investigate Zendesk ticket #{{TICKET_ID}} (Subject: {{SUBJECT}}).

## Step 1: Read the ticket
Use Glean to read the full ticket content:
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

## Step 6: Customer context
- Tool: user-glean_ai-code-search
- query: customer org name
- app: salescloud

Check for customer tier, MRR, top75 status, recent escalations.

## Step 7: Write investigation report
Write the report to `investigations/ZD-{{TICKET_ID}}.md` with this structure:

```markdown
# ZD-{{TICKET_ID}}: {{SUBJECT}}

## Customer
- **Org:** 
- **Tier/MRR:** 
- **Top75:** Yes/No

## Problem Summary
(2-3 sentences describing the issue)

## Key Details
- Error messages, logs, config snippets from the ticket

## Similar Past Tickets
| Ticket | Subject | Resolution |
|--------|---------|------------|
| #ID | subject | how it was resolved |

## Relevant Documentation
### Public Docs
- [Doc title](https://docs.datadoghq.com/...) - brief description

### Internal Docs
- [Doc title](confluence_url) - brief description

### GitHub References
- [Code/Config](https://github.com/DataDog/repo/blob/main/path) - what it shows
- [Config parameter](https://github.com/DataDog/datadog-agent/blob/main/pkg/config/setup/config.go#LXXX) - default value, description

## Attachments
| File | Size | Type | Notes |
|------|------|------|-------|
| filename | size MB | type | downloaded / analyzed / skipped |

## Flare Analysis
<!-- Include if an agent flare was downloaded and analyzed -->
- **Flare hostname:** 
- **Agent version:** 
- **Key findings:** (from flare-network-analysis or flare-profiling-analysis)
- **Full report:** `investigations/flare-{analysis-type}-{hostname}.md`

## Initial Assessment
- **Category:** (agent, logs, APM, infra, etc.)
- **Likely cause:** 
- **Suggested first steps:**
  1. ...
  2. ...
  3. ...

## Reproduction (if applicable)
<!-- FUTURE: Auto-detect topic and suggest environment -->
<!-- Kubernetes -> minikube -->
<!-- AWS -> localstack or real AWS -->
<!-- Azure -> az CLI -->
<!-- Docker -> docker-compose -->
**Topic detected:** (auto-filled by watcher)
**Suggested environment:** (auto-filled)
**Reproduction steps:** TODO - manual for now
```

## Rules
- Keep it factual — only include what you found, don't speculate
- If no similar tickets found, say so
- If no docs found, say so
- ALWAYS include links to relevant public docs, internal docs, and GitHub code
- Be concise but thorough
