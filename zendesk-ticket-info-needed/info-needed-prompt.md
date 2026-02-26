Estimate what customer info is needed for Zendesk ticket #{{TICKET_ID}}.

## Step 1: Read the full ticket conversation

Read ALL comments on the ticket, not just the initial message:

```
Tool: user-glean_ai-code-read_document
urls: ["https://datadog.zendesk.com/agent/tickets/{{TICKET_ID}}"]
```

From the full conversation, extract:
- **Problem description** — what is the customer reporting?
- **Product area** — which Datadog product/feature is involved?
- **Specific integration** — if applicable (e.g., PostgreSQL, nginx, AWS EC2)
- **Environment** — OS, container runtime, cloud provider mentioned?
- **Already provided** — list everything the customer already shared:
  - Config files or snippets
  - Flare IDs or attached flares
  - Log excerpts
  - Error messages
  - Screenshots
  - Agent version
  - Commands already run and their output
  - Steps already attempted
- **Already asked** — list everything a Datadog agent already requested in previous comments
- **Pending asks** — things already requested but not yet provided by the customer

## Step 2: Identify the product area and spec

Based on the ticket content, determine:
1. The **primary product area** (Agent, APM, Logs, DBM, Containers, Cloud Integrations, NDM, NPM, Monitors, Synthetics, RUM, Security, etc.)
2. The **specific feature or integration** (e.g., "PostgreSQL integration", "Log pipelines", "K8s DaemonSet deployment")

Use these keywords to build your Confluence search query in Step 3.

## Step 3: Fetch the troubleshooting guide from Confluence

Search Confluence for the product area's internal troubleshooting guide:

```
Tool: user-glean_ai-code-search
query: {product_area} troubleshooting guide
app: confluence
```

If the first search doesn't return a clear troubleshooting guide, try variations:
- `{product_area} runbook`
- `{product_area} diagnostic steps`
- `{integration_name} troubleshooting`
- `{product_area} common issues`

When you find a relevant guide, read it fully:

```
Tool: user-glean_ai-code-read_document
urls: ["{confluence_url}"]
```

From the troubleshooting guide, extract:
- **Required diagnostic info** — what data points does the guide say are needed?
- **Commands to run** — exact commands the customer should execute
- **Common causes** — what issues does the guide cover?
- **Decision trees** — "if X then ask for Y" logic

## Step 4: Fetch relevant public documentation

Find the public doc page for the specific feature/integration:

```
Tool: user-glean_ai-code-search
query: {product_area} {integration_name} setup
app: glean help docs
```

Or read directly if you know the path:

```
Tool: user-glean_ai-code-read_document
urls: ["https://docs.datadoghq.com/{relevant_path}"]
```

Key doc paths:

| Product | Doc URL |
|---------|---------|
| Agent | https://docs.datadoghq.com/agent/ |
| Agent Integrations | https://docs.datadoghq.com/integrations/{integration_name}/ |
| Logs | https://docs.datadoghq.com/logs/ |
| APM / Tracing | https://docs.datadoghq.com/tracing/ |
| DBM | https://docs.datadoghq.com/database_monitoring/ |
| Containers | https://docs.datadoghq.com/containers/ |
| Cloud Integrations | https://docs.datadoghq.com/integrations/ |
| NDM | https://docs.datadoghq.com/network_monitoring/devices/ |
| NPM | https://docs.datadoghq.com/network_monitoring/performance/ |
| Monitors | https://docs.datadoghq.com/monitors/ |
| Synthetics | https://docs.datadoghq.com/synthetics/ |
| RUM | https://docs.datadoghq.com/real_user_monitoring/ |
| Security | https://docs.datadoghq.com/security/ |

Extract:
- **Setup prerequisites** — what the customer should have configured
- **Verification commands** — commands to confirm correct setup
- **Troubleshooting section** — if the doc has one, note the diagnostic steps

## Step 5: Cross-reference provided vs needed

Create two lists:

### Already Provided
Go through each item the troubleshooting guide requires and check if the customer already provided it in any comment. Mark as:
- **Provided** — customer gave this info (cite which comment)
- **Partially provided** — customer gave something related but incomplete
- **Requested but not provided** — a Datadog agent already asked for this, customer hasn't responded yet
- **Missing** — never mentioned, never asked for

### Priority Classification
For each missing item, classify priority:

- **🔴 Critical** — Cannot proceed without this. Blocks diagnosis entirely.
  - Examples: flare for agent issues, config for setup issues, error message for bug reports
- **🟡 Helpful** — Speeds up resolution significantly, but can start without it.
  - Examples: exact agent version, OS details, environment topology
- **🟢 Nice to have** — Additional context that might help edge cases.
  - Examples: when the issue started, any recent changes, business impact

## Step 6: Build OS-appropriate commands

For each command the customer needs to run, provide variants for their OS/environment:

### Agent commands
| Action | Linux | Windows | Container |
|--------|-------|---------|-----------|
| Flare | `sudo datadog-agent flare` | `& "$env:ProgramFiles\Datadog\Datadog Agent\bin\agent.exe" flare` | `kubectl exec -it <POD> -- agent flare` |
| Check | `sudo datadog-agent check <NAME> --log-level debug` | `& "$env:ProgramFiles\Datadog\Datadog Agent\bin\agent.exe" check <NAME> --log-level debug` | `kubectl exec -it <POD> -- agent check <NAME> --log-level debug` |
| Status | `sudo datadog-agent status` | `& "$env:ProgramFiles\Datadog\Datadog Agent\bin\agent.exe" status` | `kubectl exec -it <POD> -- agent status` |
| Config | `sudo datadog-agent configcheck` | `& "$env:ProgramFiles\Datadog\Datadog Agent\bin\agent.exe" configcheck` | `kubectl exec -it <POD> -- agent configcheck` |

For manual check output capture:
- **Linux/Mac:** `sudo datadog-agent check <NAME> --log-level debug 2>&1 | tee /tmp/check_output.txt`
- **Windows (PowerShell):** `& "$env:ProgramFiles\Datadog\Datadog Agent\bin\agent.exe" check <NAME> --log-level debug 2>&1 | Tee-Object -FilePath C:\tmp\check_output.txt`

Detect the customer's OS from:
1. Ticket content (mentions of Linux, Windows, Mac, K8s, Docker, ECS, etc.)
2. Flare content if one was attached
3. Agent version format

If OS is unknown, provide both Linux and Windows variants.

## Step 7: Generate the output

Produce TWO sections:

### Section A: Internal Analysis

```markdown
## Info Needed: ZD-{{TICKET_ID}}

### Product Area
- **Spec:** {spec_name}
- **Feature/Integration:** {specific_feature}
- **Troubleshooting Guide:** [{guide_title}]({confluence_url})
- **Public Doc:** [{doc_title}]({doc_url})

### Conversation Summary
- **Total comments:** {N}
- **Customer comments:** {N}
- **Datadog comments:** {N}
- **Status:** {open/pending/on-hold}
- **Last activity:** {date}

### Already Provided
- [x] {item} — found in comment #{N} ({date})
- [x] {item} — attached as {filename}

### Already Requested (pending from customer)
- [ ] {item} — asked by {agent_name} in comment #{N} ({date})

### Still Needed (Priority Order)

#### 🔴 Critical (can't proceed without)
| # | What | Why | Source |
|---|------|-----|--------|
| 1 | {item} | {reason from troubleshooting guide} | {guide name} |

#### 🟡 Helpful (speeds up resolution)
| # | What | Why | Source |
|---|------|-----|--------|
| 1 | {item} | {reason} | {guide name} |

#### 🟢 Nice to have
| # | What | Why |
|---|------|-----|
| 1 | {item} | {reason} |

### Estimated Back-and-Forths
- **If we ask for everything now:** ~{N} reply needed from customer
- **If we ask incrementally:** ~{N} back-and-forths
- **Recommendation:** {ask all at once / ask incrementally because...}
```

### Section B: Customer Message (copy-paste ready)

Write a polite, professional customer message that:

1. **Acknowledges** the issue briefly (1 sentence)
2. **Explains** what you need and why (don't just list commands blindly)
3. **Provides numbered steps** with exact commands for their OS
4. **Includes doc links** to relevant public documentation
5. **Sets expectations** on what happens after they provide the info

Template:

```
Hi {customer_name},

Thank you for reaching out about {brief_issue_summary}.

To investigate this further, could you please provide the following:

1. **{Item 1}** — {brief explanation of why}
   ```
   {exact command to run}
   ```
   {Any notes about the output format}

2. **{Item 2}** — {brief explanation}
   Please follow the steps in our documentation: {doc_link}

3. **{Item 3}** — {brief explanation}
   ```
   {command}
   ```

{If applicable: "For reference, here is our troubleshooting guide for {product}: {doc_link}"}

Once we receive this information, we'll be able to {what you'll do with it}.

Best regards
```

**Important rules for the customer message:**
- NEVER mention Confluence or internal docs — only link to public docs.datadoghq.com
- NEVER say "troubleshooting guide says..." — phrase it as your own expert knowledge
- DO include exact commands with the right syntax for their OS
- DO explain WHY each piece of info helps (customers respond better when they understand the reason)
- DO batch all requests into one message to minimize back-and-forths
- If something was already asked by a previous agent and the customer didn't respond, re-ask it politely ("I noticed we previously asked for X — could you share that when you get a chance?")

## Rules

- The Confluence troubleshooting guide is the PRIMARY source of truth for what to ask
- ALWAYS search Confluence — never rely solely on the hardcoded patterns in SKILL.md
- Read ALL ticket comments — don't just read the first message
- If a previous Datadog agent already asked for something, don't re-ask unless the customer didn't respond
- If the customer already provided something, don't ask for it again — acknowledge it
- Provide OS-appropriate commands (detect OS from ticket content)
- Link to public docs only in the customer message — never internal Confluence links
- Prioritize ruthlessly — only mark as 🔴 Critical what truly blocks diagnosis
