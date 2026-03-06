# Flare General Analysis Prompt

You are performing a comprehensive analysis of a Datadog Agent flare.

## Input
- Flare directory path: `/path/to/flare-YYYYMMDD-HHMMSS/`
- Optional: Zendesk ticket ID (for context/output naming)

## Task

1. Navigate to the flare directory
2. Run health check, config review, and issue diagnostics
3. Check integration versions
4. Generate structured report
5. Save to `investigations/ZD-{ID}/flare-analysis.md`

## Step 1: Extract & Verify

If given a `.zip` file:
```bash
unzip flare-*.zip -d ./flare-analysis
cd flare-analysis
ls -la
```

Verify key files exist:
- `status.log` ✓
- `runtime_config_dump.yaml` ✓
- `installed_packages.txt` ✓
- `diagnose.log` ✓

If files missing, note in report.

## Step 2: Health Check from status.log

Read `status.log` and note:

**Component Status:**
- Is the Agent running? (check first line)
- Which components are running/stopped?
- Any failed checks?

**Errors & Warnings:**
```
SEARCH FOR: ERROR, FAILED, WARNING (case-insensitive)
EXTRACT: Full line + context
SEVERITY: 🔴 ERROR, 🟠 FAILED, 🟡 WARNING
```

**Check Results:**
- Count passing vs failing
- Note any timeout or unavailable checks
- Extract error messages from failed checks

Example from status.log:
```
Agent (v7.52.0)
  Status: OK
  Pid: 12345

Checks
  cpu: OK
  postgres: FAILED (connection refused)
  mongo: OK
```

Document:
```
✅ Agent running (v7.52.0, PID 12345)
✅ 2/3 checks passing
🔴 postgres check failed: connection refused
```

## Step 3: Configuration Review

Open `runtime_config_dump.yaml`:
- Is it valid YAML? (check format)
- Any missing critical sections?
- Are there DEBUG/experimental flags set?

Open `config-check.log`:
- Any validation errors?
- Any deprecation warnings?
- Parse errors?

Document:
```
Configuration Status:
✅ YAML valid
🟡 Found 1 deprecation warning: dogstatsd_port (use dogstatsd listen_address)
❌ Missing logs agent configuration
```

## Step 4: Detect Issue Type & Run Diagnostics

Read `status.log` and extract error messages to determine issue type.

### Check for Issue Types

**Connectivity Issues:**
- Keywords: "connection refused", "timeout", "DNS", "refused", "connection reset"
- Primary file: `diagnose.log`, `expvar/forwarder`
- Check: Forwarder status, endpoint connectivity, DNS resolution

**Check Failures:**
- Keywords: "FAILED", "Error", "check failed"
- Primary files: check-specific logs
- Check: Integration configuration, permissions, service availability

**Invalid API Key:**
- Keywords: "invalid api key", "401", "unauthorized"
- Primary files: `diagnose.log`, agent logs
- Check: API key format, site mismatch (US1 vs EU1)

**Secrets Backend Issues:**
- Keywords: "secrets", "empty api key", "authentication failed"
- Primary files: `diagnose.log`
- Check: Backend configuration, access rights

**Performance Issues:**
- Keywords: "high cpu", "high memory", "goroutine", "allocation"
- Primary files: `expvar/`, `go-routine-dump.log`
- Check: Check frequency, memory leaks, blocking operations

**Logs Agent Issues:**
- Keywords: "logs agent", "tail", "file not found"
- Primary files: `status.log` Logs Agent section
- Check: File paths, permissions, tailing state

**APM/Trace Issues:**
- Keywords: "trace-agent", "APM", "traces not appearing"
- Primary files: `trace-agent.log`
- Check: Language library, instrumentation, trace sampling

**Kubernetes/Container Issues:**
- Keywords: "kubernetes", "container", "pod", "rbac", "daemonset"
- Primary files: `status.log` Container section
- Check: RBAC permissions, kubelet connectivity, node agent

**JMX Issues:**
- Keywords: "jmx", "jmxfetch", "mbean"
- Primary files: `jmx.log`, `jmx_status.log`
- Check: JMX port accessibility, bean registration

**Database Monitoring Issues:**
- Keywords: "postgres", "mysql", "oracle", "relations", "pg_stat"
- Primary files: db-specific logs, `status.log`
- Check: DB permissions, integration config, DBM features

### Extract Evidence

For each issue found, extract:
- **File:** Which log file contains the evidence
- **Line/Context:** The actual error message or relevant section
- **Severity:** 🔴 🟠 🟡 ✅
- **Impact:** What this breaks for the customer

## Step 5: Integration Version Check

Open `installed_packages.txt` and search for `datadog-*` entries:

```
Example:
datadog-mongo==5.3.0
datadog-postgres==12.2.0
datadog-redis==4.6.1
```

For each integration found:

### 5a. Identify Repository

Check if the integration is in **integrations-core** (bundled) or **integrations-extras** (community):

```bash
# Core integrations (bundled with Agent):
# apache, cassandra, consul, docker, elasticsearch, etcd, kafka, kubernetes,
# memcached, mongo, mysql, nginx, postgres, rabbitmq, redis, sqlserver, tomcat

# Extras (installed separately):
# 1password, aws_pricing, cert_manager, fluxcd, gatekeeper, launchdarkly,
# neo4j, nomad, pihole, traefik, unbound
```

### 5b. Find Latest Version

**For Core:**
- Check GitHub: `https://github.com/DataDog/integrations-core/{integration}/CHANGELOG.md`
- Look at latest version at top of CHANGELOG

**For Extras:**
- Check GitHub: `https://github.com/DataDog/integrations-extras/{integration}/CHANGELOG.md`
- Or use PyPI API: `https://pypi.org/pypi/datadog-{integration}/json`

### 5c. Compare & Report

```
Integration Versions:
| Integration | Installed | Latest | Repo | Status |
|---|---|---|---|---|
| mongo | 5.3.0 | 6.1.0 | integrations-core | ⚠️ Major version behind |
| postgres | 12.2.0 | 12.2.0 | integrations-core | ✅ Current |
| neo4j | 1.0.0 | 1.1.2 | integrations-extras | 🟡 Minor update available |
```

### 5d. Search for Related Issues

If an integration is outdated AND there are matching symptoms:
- Search GitHub issues: `https://github.com/DataDog/integrations-core/issues`
- Search PR: `https://github.com/DataDog/integrations-core/pulls`
- Look for: "version X.Y.Z", error messages from the flare

## Step 6: Timeline Analysis

Read the agent logs and correlate errors:

1. **Find the reported issue timestamp** (from ticket context)
2. **Search logs 5-10 minutes BEFORE** that time
3. **Look for patterns:**
   - Configuration reload?
   - Service restart?
   - Multiple error spikes?
   - State changes?

Document timeline:
```
15:23 - Config reload triggered
15:23-15:45 - Postgres check failures (connection refused)
15:46 - Error rate spikes
15:50 - Customer reports issue
```

## Step 7: Produce Report

Write to `investigations/ZD-{ID}/flare-analysis.md`:

```markdown
## Flare Analysis Report

**Flare Date:** YYYY-MM-DD HH:MM
**Agent Version:** X.X.X
**Platform:** Linux / macOS / Windows
**Uptime:** [from status.log]

### Summary
[1-2 sentences describing overall health and main issues]

### Health Status

**Overall:** 🔴 Critical / 🟠 Degraded / ✅ Healthy

**Components:**
- Agent: ✅ Running (v7.52.0)
- Forwarder: ✅ Connected
- Checks: 🟠 2/5 passing (postgres, mysql failed)

**Errors Found:** 3 critical, 1 warning

### Configuration
✅ Runtime config valid
🟡 1 deprecation warning: [description]
❌ Missing: [config section]

### Integration Versions
| Integration | Installed | Latest | Status |
|---|---|---|---|
| mongo | 5.3.0 | 6.1.0 | ⚠️ Major version behind |

### Issues Found

**🔴 CRITICAL: Postgres check failing**
- Evidence: `status.log` line 245, `diagnose.log` lines 1023-1045
- Root cause: Connection refused to postgres://localhost:5432
- Impact: No postgres metrics collected
- Recommendation: Verify postgres service is running and accessible on localhost:5432

**🟠 HIGH: API Key validation warning**
- Evidence: `agent.log` line 567
- Root cause: Possible key mismatch or site configuration
- Impact: Forwarder may fail if key is actually invalid
- Recommendation: Verify API key format and Datadog site configuration

**🟡 MEDIUM: Deprecated config option**
- Evidence: `config-check.log` line 89
- Root cause: `dogstatsd_port` is deprecated
- Impact: Will break in future Agent versions
- Recommendation: Update to `dogstatsd.listeners` configuration

### Timeline

**15:23** - Configuration reload detected (status.log line 156)
**15:24** - Postgres check begins failing with "connection refused" (postgres.log)
**15:25-15:50** - 25 failed check attempts, exponential backoff applied (diagnose.log)
**15:51** - Customer reports no metrics (ticket creation time)

### Related Skills to Run

If needed, run:
- `flare-network-analysis` — For detailed forwarder/connectivity diagnostics
- `flare-profiling-analysis` — For memory leak or CPU hotspot investigation

### Next Steps

1. [First action based on critical issues]
2. [Second action based on high priority issues]
3. [Verification step to confirm fix]
```

## Output

Print the report in markdown format. It will be saved to `investigations/ZD-{ID}/flare-analysis.md` and included in the investigation summary.

## Key Rules

1. **Evidence-based:** Every finding references a specific file and line
2. **Actionable:** Clear recommendations for each issue
3. **Integrated:** Check versions against latest
4. **Timeline-aware:** Correlate errors with customer-reported time
5. **Dispatch:** Route to network or profiling analysis if needed
