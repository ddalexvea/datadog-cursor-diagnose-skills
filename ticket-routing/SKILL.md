---
name: ticket-routing
description: Identify which TS specialization and engineering team owns a ticket topic. Use when the user asks about ticket routing, spec ownership, which team handles a topic, who owns a product area, which spec a ticket belongs to, or wants to know the right Slack channel for a ticket. Also triggers on patterns like "which spec {ticket_id}", "route ticket {id}", or when the user shares a Zendesk ticket URL.
---

# Ticket Routing Intelligence

Given a Zendesk ticket (URL, ID, or description), identify the owning TS specialization,
engineering team, relevant Slack channels, and CODEOWNERS paths.

## Step 1: Gather ticket context

**If given a Zendesk ticket URL or ID:**
```
Tool: user-glean_default-read_document
urls: ["https://datadog.zendesk.com/agent/tickets/{TICKET_ID}"]
```

Extract: subject, product type tag (`pt_product_type:*`), customer description, error messages,
and any technical keywords (product names, integrations, features mentioned).

**If given a free-text description:** extract keywords directly.

## Step 2: Fetch the live Specialization Cheatsheet

Always fetch the authoritative source — never rely on cached or static data:

```
Tool: user-glean_default-read_document
urls: ["https://datadoghq.atlassian.net/wiki/spaces/TS/pages/2296021921"]
```

This page is titled **"Specialization Cheatsheet"** and contains all TS spec definitions
organized by product family:

### Product Families and their Specs

| Product Family | Specs |
|----------------|-------|
| Infrastructure | Agent, Cloud Integrations, Containers, Database Monitoring, Serverless |
| Daily Usage | AAA (Web Platform), Graphing (Web Platform), Metrics, Monitors |
| SIEM | Logs, Security |
| User Journey | APM, ML Observability, RUM, Synthetics |
| Service Management | Service Management |
| Other | New and Miscellaneous |

### How to parse the cheatsheet

Each spec section has this structure:
1. **Header**: `# {Spec Name} Spec` (e.g., `# Agent Spec`)
2. **Slack channel**: Listed right after (e.g., `#support-agent`)
3. **Exclusions / redirects**: Items listed with `→ {Other Spec}` mean they do NOT belong
   to this spec — route to the indicated spec instead
4. **Inclusions**: Items listed without a redirect arrow belong to this spec

### Critical routing exceptions to surface

Many items have redirect rules. When presenting results, always check and surface these.
Common patterns:
- "Cloud integrations such as AWS, GCP, Azure crawler metrics → Cloud" (not Agent)
- "Datadog Agents Installations on Container Platforms → Containers" (not Agent)
- "Database Integrations/DBM → DBM" (not Agent)
- "OpenTelemetry traces → APM" but "OpenTelemetry infra/host → Agent"
- "Non-relational databases (Redis, Cassandra, ClickHouse) → Agent" (not DBM)
- "Agent log collection issues → Agent or Containers" (not Logs)
- "Log Monitor evaluation → Logs" (not Monitors)
- "Error Tracking (APM source) → APM" but "Error Tracking (RUM source) → RUM"
  and "Error Tracking (Logs source) → Logs"

## Step 3: Fetch CODEOWNERS for engineering team

Based on the identified product area, fetch the relevant CODEOWNERS file:

```
Tool: user-github-get_file_contents
owner: DataDog
repo: {relevant_repo}
path: .github/CODEOWNERS
```

**Repo selection based on product:**

| Product Area | Primary Repo |
|-------------|-------------|
| Agent, Containers, NDM, CNM, DBM, Logs Agent, System Probe | `datadog-agent` |
| APM Java | `dd-trace-java` |
| APM Python | `dd-trace-py` |
| APM Go | `dd-trace-go` |
| APM .NET | `dd-trace-dotnet` |
| APM Ruby | `dd-trace-rb` |
| APM Node.js | `dd-trace-js` |
| APM PHP | `dd-trace-php` |
| Helm Charts | `helm-charts` |
| Datadog Operator | `datadog-operator` |
| Serverless | `datadog-serverless-functions` |
| Cloud Integrations | `datadog-cloudformation-resources` |
| Observability Pipelines | `vector` |

Use the `user-github-get_file_contents` tool (not `user-github-2-*`) as it has access
to private Datadog repos.

From CODEOWNERS, find lines matching the product keywords and extract the `@DataDog/{team}` owners.

## Step 4: Present results

Format the output as:

```markdown
## Ticket Routing: {Subject}

### TS Specialization
- **Spec**: {Spec Name}
- **Slack Channel**: {#support-channel}
- **Confluence**: [{Spec Name}]({confluence_url})

### Engineering Team
- **Team**: @DataDog/{team-name}
- **Repo**: [DataDog/{repo}](https://github.com/DataDog/{repo})
- **Code Paths**:
  - [{path}](https://github.com/DataDog/{repo}/tree/main{path})
- **CODEOWNERS**: [View](https://github.com/DataDog/{repo}/blob/main/.github/CODEOWNERS)

### Routing Notes
- {Any exception rules that apply}
- {Ambiguity warnings if the ticket could span multiple specs}

### Confidence
- **High**: Clear match to a single spec with matching product type tag
- **Medium**: Matches a spec but could be ambiguous (explain why)
- **Low**: Could belong to multiple specs (list all candidates with reasoning)
```

### Handling ambiguity

When a ticket could belong to multiple specs:
1. List ALL matching specs ranked by likelihood
2. Explain WHY each spec could apply
3. Reference the specific cheatsheet rules that apply
4. Suggest which Slack channel to ask for clarification

### Example

For a ticket about "OTel traces not showing in APM on EKS":
- **Primary**: APM Spec (OTel traces collection → APM)
- **Secondary**: Containers Spec (agent on EKS → Containers)
- **Note**: "If the issue is trace collection/instrumentation → APM.
  If the issue is agent deployment on EKS → Containers."

Engineering team output example:

```
### Engineering Team
- **Team**: @DataDog/database-monitoring
- **Repo**: [DataDog/datadog-agent](https://github.com/DataDog/datadog-agent)
- **Code Paths**:
  - [/pkg/databasemonitoring](https://github.com/DataDog/datadog-agent/tree/main/pkg/databasemonitoring)
  - [/cmd/agent/dist/conf.d/oracle-dbm.d/](https://github.com/DataDog/datadog-agent/tree/main/cmd/agent/dist/conf.d/oracle-dbm.d/)
- **CODEOWNERS**: [View](https://github.com/DataDog/datadog-agent/blob/main/.github/CODEOWNERS)
```
