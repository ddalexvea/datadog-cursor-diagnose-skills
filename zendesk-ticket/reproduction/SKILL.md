---
name: zendesk-ticket-reproduction
description: Reproduce a Zendesk ticket issue in a sandbox environment. Picks the simplest tier (CLI/curl, local process, Docker, or minikube), sets up the environment, reproduces the behavior, tests workarounds, and documents findings in investigations/ZD-{id}.md. Use when the user mentions reproduce, create sandbox, build sandbox, test this issue, or when triggered by Kanban Reproduction column.
kanban: true
kanban_columns: reproduction
---

# Reproduce Ticket Issue

Hands-on reproduction of a Zendesk ticket issue in a sandbox environment. Picks the cheapest path to reproduce, executes it, tests workarounds, and documents everything.

**Different from other ticket skills:**
- **Repro Needed** = decides IF reproduction is needed (yes/no verdict)
- **Reproduction** (this skill) = actually DOES the reproduction

## How to Use

Say: **"reproduce #1234567"** or **"create sandbox for ZD-1234567"**

Also runs automatically when a Kanban card is moved to the Reproduction column.

## When This Skill is Activated

Triggers on:
- "reproduce #XYZ"
- "create sandbox for #XYZ"
- "build sandbox for ZD-XYZ"
- "test this issue #XYZ"
- Auto-triggered by Kanban when card moves to Reproduction column

Then:
1. Extract the ticket ID
2. **Run the AI Compliance Check below FIRST**
3. Follow the steps in `reproduction-prompt.md`
4. Document findings in `investigations/ZD-{TICKET_ID}.md`

## AI Compliance Check (MANDATORY — FIRST STEP)

**Before processing ANY ticket data**, check for the `oai_opted_out` tag:

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {TICKET_ID}
```

If the output contains `ai_optout:true`:
1. **STOP IMMEDIATELY** — do NOT process ticket data through the LLM
2. Do NOT generate any reproduction
3. Tell the user: **"Ticket #{TICKET_ID}: AI processing is blocked — this customer has opted out of GenAI (oai_opted_out). Handle manually without AI."**
4. Exit the skill

This is a legal/compliance requirement. No exceptions.

## Reproduction Tier Decision Tree (CRITICAL)

Pick the **simplest possible tier**. Never use minikube when curl suffices.

**Step 1**: Is this reproducible at all?
- NO (auth/login/SSO/billing/org-level) → Status: blocked, suggest escalation

**Step 2**: Can I reproduce with just curl/API calls?
- YES → **Tier 1 (CLI/curl)** — log pipeline parsing, dashboard widget query, cloud integration config, Terraform DD provider

**Step 3**: Do I just need a local process or simple tool?
- YES → **Tier 2 (python/local)** — OpenMetrics (python http.server), DogStatsD (python UDP), system check, ddev

**Step 4**: Do I need agent + service, but no k8s features?
- YES → **Tier 3 (Docker)** — agent log params, Postgres/Redis integration, RHEL install, Ansible role

**Step 5**: Does it require k8s features?
- YES → **Tier 4 (minikube)** — Autodiscovery, Cluster Agent, Operator, pod labels/tags, Helm values

### Not Reproducible (detect and block immediately)
- Login/SSO/SAML/MFA issues
- Billing/plan/quota issues
- Org-level admin settings requiring customer's org access
- Cloud-specific runtimes (ECS Fargate, Lambda) — future phase
- Infrastructure provisioning (Terraform creating cloud resources) — review config offline

## Environment Capabilities by Tier

### Tier 1 — CLI/curl (cost: ~0, time: seconds)

| Tool | Use Case |
|------|----------|
| curl + Datadog API | Log pipeline testing (POST logs, check parsing), dashboard queries, metric queries |
| terraform | Datadog provider resource testing (monitors, dashboards, SLOs) |

### Tier 2 — Local process (cost: low, time: minutes)

| Tool | Use Case |
|------|----------|
| python http.server / prometheus_client | OpenMetrics endpoint simulation |
| python socket (UDP) | DogStatsD custom metrics |
| local datadog-agent | System integration checks (cpu, disk, network, process) |
| ddev | Integration-specific testing (datadoghq.dev/integrations-core/ddev/about/) |

### Tier 3 — Docker (cost: medium, time: 5-10 min)

| Tool | Use Case |
|------|----------|
| docker / docker-compose | Agent + service (postgres, redis, nginx, etc.) |
| docker + RHEL/Ubuntu image | OS-specific install testing, Ansible role testing |
| docker + agent config | Log collection params, container_collect_all, processing rules |

### Tier 4 — Kubernetes (cost: high, time: 10-20 min)

| Tool | Use Case |
|------|----------|
| minikube + kubectl + helm | Autodiscovery, Cluster Agent, Operator, pod annotations |
| minikube + Helm values | Tag/label mapping, RBAC, namespace configs |
| minikube + Operator | Datadog Operator-specific issues |

## Issue Category → Tier Mapping

| Category | Typical Tier | Examples |
|----------|-------------|----------|
| Log pipeline | Tier 1 | Grok parser, remapper, category processor |
| Dashboard/widget | Tier 1 | Widget query, metric formula, template variables |
| Cloud integration | Tier 1 | AWS/Azure/GCP integration config |
| Terraform DD provider | Tier 1-2 | Monitor/dashboard resource config |
| OpenMetrics | Tier 2 | Custom metrics endpoint, scraping config |
| DogStatsD | Tier 2 | Custom metrics, tagging, aggregation |
| System check | Tier 2-3 | CPU, disk, network, process config |
| Agent install | Tier 3 | RHEL, Ubuntu, install script failures |
| Ansible role | Tier 3 | datadog.datadog role config |
| Agent log config | Tier 3 | container_collect_all, processing rules |
| Integration check | Tier 3-4 | Postgres, Redis, nginx, JMX, SNMP |
| Autodiscovery | Tier 4 | Pod annotations, ConfigMap, cluster checks |
| Cluster Agent | Tier 4 | DCA, external metrics, HPA |
| Tag/label mapping | Tier 4 | podLabelsAsTags, unified tagging |
| Helm/Operator | Tier 4 | values.yaml, DatadogAgent CRD |
| APM/tracing | Tier 3-4 | Trace propagation, sampling |
| DBM | Tier 3-4 | DB monitoring + APM correlation |
| Login/auth | N/A | Not reproducible — block + escalate |

## Datadog Sandbox Safety Rules

- **Site**: Always `datadoghq.com`
- **Organization**: ALWAYS verify the org is the sandbox org, NEVER the "Datadog" production org
- **Credentials**: Always from kubectl secret `datadog-secret` in `default` namespace (`api-key` + `app-key`), never hardcoded
- **Cleanup**: Document cleanup commands but NEVER execute them automatically — TSE may want to inspect
- **Helm vs Operator**: Match what the customer uses. Default to Helm

## Integration with Other Skills

- **`zendesk-attachment-downloader`**: Downloads customer config files, manifests, and agent flares from the ticket before reproducing. Uses Chrome session via osascript.
- **After `zendesk-ticket-repro-needed`**: if verdict is YES, this skill executes the reproduction
- **After `zendesk-ticket-investigator`**: if Investigation Decision says `Next: reproduction`, this runs next
- **References**: [datadog-sandboxes-by-ai](https://github.com/ddalexvea/datadog-sandboxes-by-ai) for existing sandbox templates
- **Template**: [datadog-sandbox-readme-template](https://github.com/ddalexvea/datadog-sandbox-readme-template) for output format
- **API docs**: [docs.datadoghq.com/api/latest/](https://docs.datadoghq.com/api/latest/) for verification

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `reproduction-prompt.md` | Step-by-step prompt for the agent to follow |
