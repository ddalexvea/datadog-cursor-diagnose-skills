Reproduce the issue from Zendesk ticket #{{TICKET_ID}} in a sandbox environment.

## Phase 0: AI Compliance Check (MANDATORY)

```bash
~/.cursor/skills/_shared/zd-api.sh ticket {{TICKET_ID}}
```

If the output contains `ai_optout:true`, **STOP NOW**. Tell the user: "Ticket #{{TICKET_ID}}: AI processing is blocked — this customer has opted out of GenAI (oai_opted_out). Handle manually without AI." Do NOT proceed to any further steps.

## Phase 1: Download Customer Attachments

Download config files, manifests, and flares that the customer attached to the ticket. These are critical for accurate reproduction.

### List attachments
```bash
osascript -e '
tell application "Google Chrome"
  set zenTab to missing value
  repeat with w in windows
    repeat with t in tabs of w
      if URL of t contains "zendesk.com" then
        set zenTab to t
        exit repeat
      end if
    end repeat
    if zenTab is not missing value then exit repeat
  end repeat
  if zenTab is missing value then return "ERROR: No Zendesk tab found in Chrome"
  execute zenTab javascript "
    (function() {
      var xhr = new XMLHttpRequest();
      xhr.open(\"GET\", \"/api/v2/tickets/{{TICKET_ID}}/comments.json?include=users\", false);
      xhr.send();
      if (xhr.status !== 200) return \"ERROR: \" + xhr.status;
      var data = JSON.parse(xhr.responseText);
      var atts = [];
      data.comments.forEach(function(c) {
        (c.attachments || []).forEach(function(a) {
          atts.push(a.file_name + \"|\" + a.size + \"|\" + a.content_type + \"|\" + a.content_url);
        });
      });
      return atts.length ? atts.join(\"\\n\") : \"NO_ATTACHMENTS\";
    })()
  "
end tell'
```

### Download relevant files
Focus on files that help reproduce the issue:
- **Config files**: `.yaml`, `.yml`, `.conf`, `.json`, `.toml` — customer's actual configuration
- **Manifests**: Kubernetes manifests, Helm values, docker-compose files
- **Agent flares**: `.zip` files containing `datadog-agent-*` — extract to get the real agent config
- **Log files**: `.log`, `.txt` — for understanding the actual error

Skip screenshots, images, and unrelated files.

For each relevant attachment, download it:
```bash
osascript -e '
tell application "Google Chrome"
  set zenTab to missing value
  repeat with w in windows
    repeat with t in tabs of w
      if URL of t contains "zendesk.com" then
        set zenTab to t
        exit repeat
      end if
    end repeat
    if zenTab is not missing value then exit repeat
  end repeat
  execute zenTab javascript "
    (function() {
      var a = document.createElement(\"a\");
      a.href = \"CONTENT_URL_HERE\";
      a.download = \"FILENAME_HERE\";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      return \"Download triggered: FILENAME_HERE\";
    })()
  "
end tell'
```

Wait for downloads to complete, then check:
```bash
ls -la ~/Downloads/FILENAME_HERE
```

### Extract agent flare (if downloaded)
If an agent flare `.zip` was downloaded:
```bash
mkdir -p /tmp/flare-zd-{{TICKET_ID}}
unzip -o ~/Downloads/FLARE_FILENAME.zip -d /tmp/flare-zd-{{TICKET_ID}}
```

Key files to extract from the flare for reproduction:
- `etc/datadog-agent/datadog.yaml` — main agent config
- `etc/datadog-agent/conf.d/` — integration configs (the ones relevant to the issue)
- `status.log` — agent status at time of flare
- `config-check.log` — active check configurations

Use these to replicate the customer's exact configuration in your sandbox.

If no relevant attachments are found, proceed without them — use the investigation report for context.

## Phase 2: Read Investigation Context

Read the investigation report to understand what needs reproducing:

```bash
cat investigations/ZD-{{TICKET_ID}}.md
```

Extract and note:
- The customer's issue description
- Product area and integration involved
- The `## Investigation Decision` — should indicate `Next: reproduction`
- Any specific config or behavior to reproduce
- Agent version the customer uses (if mentioned)
- Cross-reference with any downloaded attachments from Phase 1

If `## Reproduction Review History` exists and contains feedback, this is a re-run. Skip to Phase 12.

## Phase 3: Determine Reproduction Tier

Walk the decision tree from SKILL.md:

1. **Is this reproducible at all?**
   - Auth/login/SSO/billing/org-level → Status: blocked, write `## Reproduction Decision` with `Status: blocked` and `Blocker: Not reproducible in sandbox — <reason>`, then STOP.

2. **Can I reproduce with just curl/API calls?**
   - Log pipeline parsing, dashboard widget queries, cloud integration config, Terraform DD provider → **Tier 1**. Skip to Phase 3 (no environment setup needed beyond credentials).

3. **Do I just need a local process or simple tool?**
   - OpenMetrics endpoint (python http.server), DogStatsD (python UDP socket), system checks, ddev → **Tier 2**. Skip minikube phases.

4. **Do I need agent + service, but no k8s features?**
   - Agent log params, Postgres/Redis integration, RHEL install testing, Ansible role → **Tier 3 (Docker)**. Skip minikube phases.

5. **Does it require k8s features?**
   - Autodiscovery, Cluster Agent, Operator, pod labels/tags, Helm values → **Tier 4 (minikube)**.

## Phase 4: Search Existing Sandboxes

Look for similar setups to adapt rather than building from scratch:

### Local sandboxes repo
```bash
ls ~/Projects/datadog-sandboxes-by-ai/ 2>/dev/null || git clone https://github.com/ddalexvea/datadog-sandboxes-by-ai.git ~/Projects/datadog-sandboxes-by-ai
```

Search by category:
```bash
find ~/Projects/datadog-sandboxes-by-ai -name "*.md" | head -30
```

### Datadog official sandboxes
```
Tool: user-glean_ai-code-search
query: <product area> sandbox reproduce
app: github
```

### Confluence KB
```
Tool: user-glean_ai-code-search
query: <product area> reproduce sandbox
app: confluence
```

If a similar sandbox is found, adapt it. If not, generate a new one using the structure from [datadog-sandbox-readme-template](https://github.com/ddalexvea/datadog-sandbox-readme-template).

## Phase 5: Retrieve Credentials

For ALL tiers, get the Datadog credentials:

```bash
DD_API_KEY=$(kubectl get secret datadog-secret -n default -o jsonpath='{.data.api-key}' | base64 -d)
DD_APP_KEY=$(kubectl get secret datadog-secret -n default -o jsonpath='{.data.app-key}' | base64 -d)
```

**CRITICAL — Verify the organization is the sandbox org, NEVER the production "Datadog" org:**

```bash
curl -s "https://api.datadoghq.com/api/v1/org" \
  -H "DD-API-KEY: $DD_API_KEY" \
  -H "DD-APPLICATION-KEY: $DD_APP_KEY" | python3 -c "
import sys, json
data = json.load(sys.stdin)
org_name = data.get('org', {}).get('name', 'UNKNOWN')
print(f'Organization: {org_name}')
if 'sandbox' not in org_name.lower():
    print('WARNING: This does not look like a sandbox org! Aborting.')
    sys.exit(1)
print('OK — sandbox org confirmed')
"
```

If the org check fails, **STOP** and set `Status: blocked` with `Blocker: Credentials do not point to sandbox org`.

## Phase 6: Setup Environment (tier-specific)

### Tier 1 — CLI/curl
No environment setup needed. Proceed directly to Phase 7 using curl commands.

### Tier 2 — Local process

Example for OpenMetrics:
```bash
python3 -c "
from http.server import HTTPServer, BaseHTTPRequestHandler
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'# HELP example_metric Example\n# TYPE example_metric gauge\nexample_metric 42\n')
HTTPServer(('0.0.0.0', 9090), Handler).serve_forever()
" &
```

Example for DogStatsD:
```bash
python3 -c "
import socket
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(b'custom.metric:1|g|#env:sandbox', ('127.0.0.1', 8125))
"
```

### Tier 3 — Docker

```bash
mkdir -p /tmp/sandbox-zd-{{TICKET_ID}}
cd /tmp/sandbox-zd-{{TICKET_ID}}

# Create docker-compose.yml with the agent + service
cat > docker-compose.yml <<'COMPOSE'
version: "3.8"
services:
  datadog-agent:
    image: datadog/agent:7
    environment:
      - DD_API_KEY=${DD_API_KEY}
      - DD_SITE=datadoghq.com
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /proc/:/host/proc/:ro
      - /sys/fs/cgroup/:/host/sys/fs/cgroup:ro
  # Add service containers as needed
COMPOSE

docker-compose up -d
docker-compose ps
```

### Tier 4 — Kubernetes (minikube)

**IMPORTANT: NEVER `minikube delete`. The cluster has API/APP key secrets. Reuse the existing cluster.**

```bash
minikube status || minikube start --memory=4096 --cpus=2

# Create ticket-specific namespaces for isolation
kubectl create namespace sandbox-zd-{{TICKET_ID}} 2>/dev/null || true

# Deploy workload resources
kubectl apply -f - <<'MANIFEST'
---
# Generated resources in sandbox-zd-{{TICKET_ID}} namespace
# [Inline all manifests here — no separate YAML files]
MANIFEST

kubectl wait --for=condition=ready pod -l app=APP_NAME -n sandbox-zd-{{TICKET_ID}} --timeout=300s
```

## Phase 7: Deploy Datadog Agent

### Tier 1-2
For CLI/local tiers, use the API keys directly in curl commands or configure the local agent. No Helm needed.

### Tier 3 — Docker
Agent is deployed via docker-compose in Phase 5. Verify:
```bash
docker-compose exec datadog-agent agent status
```

### Tier 4 — Kubernetes

Always deploy a **fresh** Helm release per reproduction:

```bash
kubectl create namespace datadog-zd-{{TICKET_ID}} 2>/dev/null || true
kubectl create secret generic datadog-secret -n datadog-zd-{{TICKET_ID}} \
  --from-literal=api-key=$DD_API_KEY 2>/dev/null || true

helm repo add datadog https://helm.datadoghq.com 2>/dev/null || true
helm repo update
```

Create values.yaml matching the customer's setup:
```yaml
datadog:
  site: "datadoghq.com"
  apiKeyExistingSecret: "datadog-secret"
  clusterName: "sandbox"
  kubelet:
    tlsVerify: false

clusterAgent:
  enabled: true

agents:
  image:
    tag: 7  # Match customer's agent version if known
```

**Helm vs Operator**: If the ticket mentions the Datadog Operator, use the Operator instead of Helm. Default to Helm.

```bash
helm upgrade --install dd-zd-{{TICKET_ID}} datadog/datadog \
  -n datadog-zd-{{TICKET_ID}} -f values.yaml

kubectl rollout status daemonset/dd-zd-{{TICKET_ID}}-datadog \
  -n datadog-zd-{{TICKET_ID}} --timeout=300s
```

## Phase 8: Verify Agent + Data Flow

### Tier 1 — curl
Verify API calls work:
```bash
curl -s -o /dev/null -w "%{http_code}" "https://api.datadoghq.com/api/v1/validate" \
  -H "DD-API-KEY: $DD_API_KEY"
```

### Tier 3 — Docker
```bash
docker-compose exec datadog-agent agent status
docker-compose exec datadog-agent agent check <INTEGRATION>
```

### Tier 4 — Kubernetes
```bash
kubectl exec -n datadog-zd-{{TICKET_ID}} daemonset/dd-zd-{{TICKET_ID}}-datadog \
  -c agent -- agent status

kubectl exec -n datadog-zd-{{TICKET_ID}} daemonset/dd-zd-{{TICKET_ID}}-datadog \
  -c agent -- agent check <INTEGRATION>
```

### Verify data reaches Datadog (all tiers)

Metrics:
```bash
curl -s "https://api.datadoghq.com/api/v1/query?from=$(date -v-15M +%s)&to=$(date +%s)&query=<metric>{*}" \
  -H "DD-API-KEY: $DD_API_KEY" \
  -H "DD-APPLICATION-KEY: $DD_APP_KEY"
```

Logs:
```bash
curl -s -X POST "https://api.datadoghq.com/api/v2/logs/events/search" \
  -H "Content-Type: application/json" \
  -H "DD-API-KEY: $DD_API_KEY" \
  -H "DD-APPLICATION-KEY: $DD_APP_KEY" \
  -d '{"filter":{"query":"*","from":"now-15m","to":"now"},"page":{"limit":5}}'
```

## Phase 9: Reproduce the Issue

Execute the specific behavior described in the ticket:

1. Apply the customer's configuration (or as close as possible)
2. Trigger the scenario that causes the issue
3. Capture the output — both expected and actual behavior
4. Save CLI output and API query results as text evidence

## Phase 10: Test Workaround/Fix

If the investigation identified a potential workaround or fix:

1. Apply the config change
2. Re-trigger the scenario
3. Compare before/after behavior
4. Document the exact config change and its effect

If no workaround was identified, note that in findings and suggest what to try.

## Phase 11: Document Findings

Write ALL findings into `investigations/ZD-{{TICKET_ID}}.md` under a `## Reproduction` section.

Use this structure:

```markdown
## Reproduction

### Context
[What was reproduced and why — 1-2 sentences]

### Tier
[Tier 1/2/3/4 — CLI/Local/Docker/Kubernetes]

### Environment
- **Agent Version:** 7.XX.X
- **Platform:** minikube / Docker / Local / CLI
- **Integration:** [if applicable]

### Schema
```mermaid
[Mermaid diagram of the setup — what connects to what]
```

### Setup Commands
[All commands and inline manifests — copy-paste ready]
[Include values.yaml, docker-compose.yml, ConfigMaps inline]

### Test Commands
[kubectl exec, agent status, agent check, curl, etc.]

### Expected vs Actual
| Behavior | Expected | Actual |
|----------|----------|--------|
| [describe] | [expected] | [actual] |

### Evidence
[CLI output snippets and API query results — text only]

### Workaround Tested
[Config fix applied + result, or "No workaround identified"]

### Cleanup
[Commands to tear down — NOT executed automatically]
[e.g., kubectl delete namespace sandbox-zd-{{TICKET_ID}}]
[e.g., helm uninstall dd-zd-{{TICKET_ID}} -n datadog-zd-{{TICKET_ID}}]

### References
[Doc links, similar sandboxes, GitHub issues]
```

Then write the `## Reproduction Decision`:

```markdown
## Reproduction Decision
- Status: <completed|blocked|partial>
- Blocker: <if blocked, what is needed from TSE>
- Findings: <one-line summary>
- Push to sandbox repo: <suggested category/path if applicable, e.g., "kubernetes/autodiscovery-annotations">
```

**IMPORTANT — Cleanup rules:**
- Document cleanup commands (kubectl delete namespace, helm uninstall, docker-compose down) in the `### Cleanup` section
- **NEVER execute cleanup commands automatically** — TSE may want to inspect the running environment
- Only the TSE decides when to clean up

## Phase 12: Blocker Handling

If at any point the agent cannot proceed:

1. Document what was accomplished so far in `## Reproduction`
2. Set `Status: blocked` in `## Reproduction Decision`
3. Describe the blocker clearly in `Blocker:` field
4. Do NOT clean up the environment — TSE may want to inspect
5. Common blockers:
   - Needs cloud credentials (AWS, Azure, GCP)
   - Unclear customer config — need more info
   - Minikube crash or resource issue
   - Non-reproducible issue type (login, billing)
   - Requires specific license or feature flag

## Phase 13: Review Feedback Handling (Re-run)

This phase runs when the TSE provides feedback via the Reproduction tab.

Check for the `## Reproduction Review History` section at the end of `ZD-{{TICKET_ID}}.md`:

```markdown
## Reproduction Review History

### Round N — TSE Feedback (YYYY-MM-DD HH:MM)
[TSE's feedback — e.g., "try with agent version 7.60", "test with PostgreSQL"]
```

When feedback exists:
1. Read the latest feedback from `## Reproduction Review History`
2. Execute the requested changes in the **existing** environment (same namespace, same setup)
3. Update the `## Reproduction` section with new findings
4. Update the `## Reproduction Decision` with revised status
5. Append the results as a new revision round:

```markdown
### Round N — Agent Revision (YYYY-MM-DD HH:MM)
- **Changes applied:** [what was changed per TSE feedback]
- **Result:** [new findings]
```

## Rules

- NEVER hardcode API keys in manifests — always use kubectl secrets
- NEVER delete minikube — reuse the cluster, isolate by namespace
- NEVER auto-execute cleanup commands — document them for TSE
- NEVER interact with the production "Datadog" organization — always verify sandbox org
- NEVER use browser tools — all operations via shell commands (minikube, kubectl, helm, curl, docker)
- ALL manifests inline in the report (no separate YAML files)
- Use generic names: `minikube`, `sandbox`, `example.com`
- Match the customer's agent version if known
- Match the customer's deployment method (Helm vs Operator)
- Pick the SIMPLEST tier — never use minikube when curl suffices
- Capture CLI output and API results as text evidence
- If reproduction is successful, suggest pushing to `datadog-sandboxes-by-ai` in the Decision section
