Investigate Zendesk ticket #{{TICKET_ID}} (Subject: {{SUBJECT}}).

## Step 1: Read the ticket
Use Glean to read the full ticket content:
- Tool: user-glean_ai-code-read_document
- urls: ["https://datadog.zendesk.com/agent/tickets/{{TICKET_ID}}"]

Extract: customer name, org, priority, full problem description, any error messages or logs shared.
Identify the **product area** (agent, logs, APM, infra, NDM, DBM, containers, etc.) for later searches.

## Step 2: Search for similar past tickets
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
