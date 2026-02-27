---
name: flare-network-analysis
description: Analyze a locally extracted Datadog Agent flare for network/connectivity issues related to the agent forwarder and intake endpoints. Use when the user asks to analyze a flare for network issues, forwarder problems, packet loss, connectivity errors, or intake failures.
---

# Flare Network Analysis

Analyzes a locally extracted Datadog Agent flare directory to produce a structured summary of network health — specifically **Datadog intake connectivity** as seen by the agent forwarder.

## When This Skill is Activated

Triggers: "analyze flare network", "flare connectivity", "forwarder analysis", "check flare for network issues", "intake connectivity", "packet loss analysis", "flare network summary"

## Prerequisites

- A locally extracted flare directory (e.g., `~/Downloads/flare-2024-.../hostname-xxx/`)
- The user provides the path to the flare directory

## How to Use

1. Say **"analyze this flare for network issues: ~/Downloads/flare-2024-.../hostname/"**
2. The agent reads this skill, follows `analyze-prompt.md`
3. Outputs a structured network health summary

## Input

The skill expects a path to an **extracted** flare directory containing at minimum:
- `status.log`
- `expvar/forwarder`

If the user provides a `.zip`, unzip it first.

## Files Analyzed

### Primary (Forwarder Transactions & Connectivity)

| File | What we extract |
|------|----------------|
| `status.log` (Forwarder section) | Transaction Success/Dropped/Requeued/Retried/RetryQueueSize, Errors by type, HTTP errors by code, on-disk storage, API key status |
| `expvar/forwarder` | `ConnectionEvents` (ConnectSuccess, DNSSuccess), `ErrorsByType` (ConnectionErrors, DNSErrors, TLSErrors, SentRequestErrors, WroteRequestErrors), `HTTPErrorsByCode`, `InputBytesByEndpoint`, `SuccessByEndpoint`, `DroppedByEndpoint`, `RequeuedByEndpoint`, `FileStorage` stats |
| `diagnose.log` | Per-endpoint connectivity test results (DNS, Connection, TLS), PASS/FAIL counts |
| `runtime_config_dump.yaml` | `forwarder_*` settings, `site`, `proxy`, `skip_ssl_validation`, `min_tls_version`, `dd_url` overrides |

### Secondary (Logs Agent & APM Network)

| File | What we extract |
|------|----------------|
| `expvar/logs-agent` | `BytesSent`, `LogsSent`, `DestinationErrors`, `RetryCount`, `RetryTimeSpent`, per-destination idle/inUse stats |
| `status.log` (Logs Agent section) | Same as above in human-readable form |
| `logs/agent.log` | Forwarder error lines: backoff, unexpected EOF, connection reset, payload post failures |
| `logs/trace-agent.log` | APM intake errors: connection reset, i/o timeout |

### Context

| File | What we extract |
|------|----------------|
| `health.yaml` | Is `forwarder` and `logs-agent` listed as healthy? |
| `expvar/compressor` | Compression ratio (BytesIn / BytesOut) |
| `expvar/process_agent` | `submission_error_count`, queue sizes, endpoints |
| `status.log` (header) | Agent version, uptime, site, hostname |
| `version-history.json` | Recent version changes |

## Output Format

The skill produces three outputs:

### 1. Full Report (written to file)
Structured markdown saved to `investigations/flare-network-analysis-{hostname}.md`:
- Agent Context — version, uptime, site, hostname, install method
- Forwarder Health — verdict (Healthy / Degraded / Critical) with supporting numbers
- Transaction Summary — total success, errors, error rate %, dropped, retried
- Error Breakdown — by type (DNS, TLS, Connection, HTTP) with HTTP error codes
- Logs Agent Health — bytes sent, retry count, retry time vs uptime ratio
- APM Agent Health — intake errors from trace-agent.log
- Connectivity Tests — diagnose.log PASS/FAIL summary, failed endpoints listed
- Configuration Review — proxy, site, forwarder tuning, TLS settings
- Recommendations — prioritized action items
- **Customer Message** — ready to copy-paste into the Zendesk ticket

### 2. Customer Message (inside the report)
A professional, concise message including key evidence from `status.log` and `agent.log` — transaction counts, error rates, log retry stats, observed error patterns with timestamps, and configuration notes. Ready to paste into the ticket.

## Verdict Logic

| Condition | Verdict |
|-----------|---------|
| Error rate < 0.01% AND no drops AND all diagnose PASS | **Healthy** |
| Error rate < 1% OR few retries OR minor HTTP errors (408) | **Degraded** |
| Error rate > 1% OR drops > 0 OR diagnose FAIL OR TLS/DNS errors | **Critical** |

## Integration

Works standalone. Can be used alongside:
- `zendesk-ticket-investigator` — when a ticket includes a flare with network symptoms
- Connectivity rules in `.cursor/rules/datadog-flare/connectivity/rules.mdc`
