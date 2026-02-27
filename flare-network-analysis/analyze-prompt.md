Analyze the Datadog Agent flare at `{{FLARE_PATH}}` for network/connectivity issues.

## Step 1: Locate the flare root

The flare may be a zip or extracted directory. If zip, extract it first.
Inside, find the hostname directory (e.g., `prod-agent-xyz-abc123/`) — that's the flare root.

Confirm these files exist:
- `status.log` (required)
- `expvar/forwarder` (required)
- `diagnose.log` (optional but highly valuable)
- `logs/agent.log` (optional)

## Step 2: Extract agent context

Read the **first 15 lines of `status.log`** to get:
- Agent version
- Status date and Agent start time → compute **uptime**
- Hostname
- Site (from runtime_config_dump.yaml if not in status.log)

Also read:
- `install_info.log` → install method (helm, apt, msi, etc.)
- `version-history.json` → recent upgrades
- `health.yaml` → is `forwarder` in `healthy` list?

## Step 3: Analyze forwarder transactions

### From `status.log` — Forwarder section

Extract (between `Forwarder` and the next `===` section):
- **Transaction Successes** → Total number, by endpoint
- **Transaction Errors** → Total number, by type
- **HTTP Errors** → Total number, by code
- **Dropped** count
- **Requeued** count
- **Retried** count
- **RetryQueueSize**
- **On-disk storage** status

### From `expvar/forwarder`

This file has the richest data. Extract:

```
Transactions:
  Success: <total>
  Errors: <total>
  Dropped: <total>
  Requeued: <total>
  Retried: <total>
  
  ConnectionEvents:
    ConnectSuccess: <n>
    DNSSuccess: <n>
  
  ErrorsByType:
    ConnectionErrors: <n>
    DNSErrors: <n>
    TLSErrors: <n>
    SentRequestErrors: <n>
    WroteRequestErrors: <n>
  
  HTTPErrors: <n>
  HTTPErrorsByCode:
    "408": <n>
    "429": <n>
    "500": <n>
    etc.
  
  InputBytesByEndpoint:
    series_v2: <bytes>
    check_run_v1: <bytes>
    etc.
  
  SuccessByEndpoint: { ... }
  DroppedByEndpoint: { ... }
  RequeuedByEndpoint: { ... }
  RetriedByEndpoint: { ... }
```

**Compute:**
- `error_rate = Errors / (Success + Errors) * 100`
- `drop_rate = Dropped / (Success + Errors + Dropped) * 100`
- Total bytes sent across all endpoints

### From `expvar/compressor`
- `BytesIn` / `BytesOut` → compression ratio

## Step 4: Analyze Logs Agent network health

### From `expvar/logs-agent`
Extract:
- `BytesSent` and `EncodedBytesSent` → compression ratio
- `LogsSent` vs `LogsProcessed` → any gap = losses
- `DestinationErrors` count
- `RetryCount`
- `RetryTimeSpent` (in nanoseconds) → convert to human-readable
- `LogsTruncated`

**Compute:**
- `retry_time_ratio = RetryTimeSpent / uptime_nanoseconds * 100` — if > 5%, network is severely degraded
- `log_loss_rate = (LogsProcessed - LogsSent) / LogsProcessed * 100`

### From `status.log` — Logs Agent section
Cross-reference the same numbers in human-readable form. Note the `RetryTimeSpent` field shows duration format (e.g., `25h28m`).

## Step 5: Scan agent.log for network errors

Search `logs/agent.log` for these patterns (case-insensitive):
- `Could not send payload` → failed HTTP sends
- `unexpected EOF` → connection dropped mid-transfer
- `connection reset by peer` → remote closed connection
- `sleeping until .* before retrying. Backoff duration` → backoff events with duration
- `dial tcp.*connection refused` → endpoint unreachable
- `no such host` → DNS failure
- `tls: handshake failure` → TLS negotiation failed
- `x509: certificate` → certificate validation issues
- `context deadline exceeded` → timeout
- `forwarder_retry_queue_payloads_max_size` → retry queue overflow
- `408\|429\|500\|502\|503` → HTTP error codes

Count occurrences and note timestamps of first and last occurrence.

## Step 6: Scan trace-agent.log for APM network errors

Search `logs/trace-agent.log` for:
- `connection reset by peer` → intake connection drops
- `i/o timeout` → read/write timeout
- `unexpected EOF`
- `context deadline exceeded`

## Step 7: Analyze diagnose.log connectivity tests

Parse `diagnose.log` for:
- Count total **PASS** and **FAIL** results
- List any **FAIL** entries with the endpoint URL and diagnosis text
- Note the **connectivity-datadog-core-endpoints** suite specifically:
  - Each test shows: DNS Lookup, Connection, TLS Handshake steps
  - Any step marked as failed indicates where connectivity breaks

## Step 8: Review network configuration

From `runtime_config_dump.yaml`, extract:
- `site:` → which Datadog site
- `proxy:` → any proxy configured
- `skip_ssl_validation:` → should be false in production
- `min_tls_version:` → TLS version requirement
- `forwarder_timeout:` → default 20s
- `forwarder_num_workers:` → default 1
- `forwarder_backoff_base:` / `forwarder_backoff_factor:` / `forwarder_backoff_max:` → backoff behavior
- `forwarder_storage_max_size_in_bytes:` → 0 means disk buffering disabled
- `forwarder_retry_queue_capacity_time_interval_sec:` → retry window
- `dd_url` or any `*_dd_url` overrides → custom endpoints
- `convert_dd_site_fqdn.enabled` → FQDN conversion (agent 7.67+)

## Step 9: Write the summary

Output the following structured report:

```markdown
# Flare Network Analysis: {hostname}

**Agent:** v{version} | **Uptime:** {X days Y hours} | **Site:** {site}
**Hostname:** {hostname} | **Install:** {method} | **Flare date:** {date}

---

## Verdict: {HEALTHY / DEGRADED / CRITICAL}

{One-line summary of overall network health}

---

## Forwarder Transactions

| Metric | Value |
|--------|-------|
| Total Success | {n} |
| Total Errors | {n} |
| Error Rate | {x.xx%} |
| Dropped | {n} |
| Requeued | {n} |
| Retried | {n} |
| RetryQueueSize | {n} |
| On-disk buffering | {enabled/disabled} |

### Successes by Endpoint

| Endpoint | Count | Bytes In |
|----------|-------|----------|
| series_v2 | {n} | {MB/GB} |
| check_run_v1 | {n} | {MB/GB} |
| ... | ... | ... |

### Errors by Type

| Error Type | Count |
|------------|-------|
| ConnectionErrors | {n} |
| DNSErrors | {n} |
| TLSErrors | {n} |
| SentRequestErrors | {n} |
| WroteRequestErrors | {n} |

### HTTP Errors by Code

| Code | Count | Meaning |
|------|-------|---------|
| 408 | {n} | Request Timeout |
| 429 | {n} | Rate Limited |
| 500 | {n} | Server Error |

### Connection Events

| Event | Count |
|-------|-------|
| ConnectSuccess | {n} |
| DNSSuccess | {n} |

---

## Logs Agent

| Metric | Value |
|--------|-------|
| LogsProcessed | {n} |
| LogsSent | {n} |
| Log Loss Rate | {x.xx%} |
| BytesSent | {GB} |
| EncodedBytesSent | {GB} |
| Compression Ratio | {x:1} |
| DestinationErrors | {n} |
| RetryCount | {n} |
| RetryTimeSpent | {Xh Ym} |
| Retry/Uptime Ratio | {x.xx%} |
| LogsTruncated | {n} |

---

## APM Agent

| Finding | Details |
|---------|---------|
| Endpoint | {url} |
| Errors in trace-agent.log | {count and types} |

---

## Connectivity Tests (diagnose.log)

**Result:** {X} PASS / {Y} FAIL out of {total} tests

### Failed Tests
| # | Endpoint | Failure |
|---|----------|---------|
| {n} | {url} | {diagnosis} |

(If all pass: "All connectivity tests passed.")

---

## Configuration

| Setting | Value | Note |
|---------|-------|------|
| site | {site} | |
| proxy | {yes/no + url if set} | |
| skip_ssl_validation | {true/false} | Should be false |
| min_tls_version | {version} | |
| forwarder_timeout | {n}s | Default: 20 |
| forwarder_num_workers | {n} | Default: 1 |
| forwarder_backoff_max | {n}s | Default: 64 |
| on-disk storage | {enabled/disabled} | |
| dd_url override | {yes/no} | Custom endpoint |

---

## Agent Log Errors (network-related)

| Pattern | Count | First seen | Last seen |
|---------|-------|------------|-----------|
| unexpected EOF | {n} | {timestamp} | {timestamp} |
| connection reset | {n} | ... | ... |
| backoff events | {n} | ... | ... |
| ... | ... | ... | ... |

---

## Recommendations

1. **{Priority}** — {action item}
2. **{Priority}** — {action item}
3. ...
```

## Verdict Decision Logic

Apply these rules in order:

**CRITICAL** if ANY of:
- Forwarder error rate > 1%
- Dropped transactions > 0
- DNSErrors > 0 or TLSErrors > 0
- Any diagnose.log FAIL on core endpoints
- `forwarder` not in `health.yaml` healthy list
- Retry/Uptime ratio > 10%

**DEGRADED** if ANY of:
- Forwarder error rate between 0.01% and 1%
- HTTP 408 or 429 errors present
- RetryCount > 100
- Retry/Uptime ratio between 1% and 10%
- Backoff events in agent.log
- `unexpected EOF` or `connection reset` in logs

**HEALTHY** if:
- Error rate < 0.01%
- No drops
- All diagnose tests PASS
- Retry/Uptime ratio < 1%
- No network errors in agent.log

## Rules

- **NEVER expose API keys** — always use `[REDACTED]` or `***`
- Keep numbers precise — don't round transaction counts
- Convert bytes to human-readable (KB/MB/GB) for readability
- Convert nanoseconds to hours/minutes for RetryTimeSpent
- If a file doesn't exist, note it as "Not available in this flare" and skip that section
- Reference https://docs.datadoghq.com/agent/configuration/network/ for endpoint context
