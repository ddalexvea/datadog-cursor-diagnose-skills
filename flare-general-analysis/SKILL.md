---
name: flare-general-analysis
description: Comprehensive flare analysis covering health check, config review, issue-specific diagnostics, and integration version checks. Use when the user says "analyze flare", "full flare analysis", "diagnose flare", or after downloading a flare from a ticket.
kanban: true
kanban_columns: investigation
---

# Flare General Analysis

Orchestrates a complete analysis of an extracted Datadog Agent flare: health check, configuration review, issue-specific diagnostics, integration version validation, and produces a structured report.

## Prerequisites

- Extracted flare directory (or path provided)
- File structure:
  ```
  flare-YYYYMMDD-HHMMSS/
  ├── status.log
  ├── diagnose.log
  ├── runtime_config_dump.yaml
  ├── config-check.log
  ├── installed_packages.txt
  ├── agent.log
  ├── python-version.txt
  └── [other logs]
  ```

## How to Use

Just say: **"analyze flare"** or **"full flare analysis for #1234567"**

The agent will:
1. Extract flare (if needed)
2. Run health check (`status.log`, component states)
3. Review configuration (`runtime_config_dump.yaml`)
4. Detect issue type and run issue-specific diagnostics
5. Check integration versions against latest
6. Output structured report to `investigations/ZD-{ID}/flare-analysis.md`

## When This Skill is Activated

If an agent receives a message matching any of these patterns:
- "analyze flare"
- "full flare analysis"
- "diagnose flare"
- "what's in this flare?"
- "flare analysis for #XYZ"
- Called by `investigator` after downloading a flare

Then:
1. Locate the flare at `~/Downloads/flare-extracted-{{TICKET_ID}}/` or any matching path
2. Extract if needed
3. Follow the steps in `flare-analysis-prompt.md`
4. Output report to `investigations/ZD-{{TICKET_ID}}/flare-analysis.md`

## Analysis Workflow

### Step 1: Extract & Orient

```bash
unzip flare-*.zip -d ./flare-analysis
cd flare-analysis
ls -la
```

### Step 2: Health Check (status.log)

Review `status.log` for:
- 🔴 **ERROR entries** — component failures, failed checks
- 🟡 **WARNING entries** — degraded state, deprecated configs
- ✅ **Component states** — running/stopped status
- Check execution results — pass/fail for each check

### Step 3: Configuration Review

- **runtime_config_dump.yaml** — active config with defaults
- **config-check.log** — validation results and warnings
- Compare with customer's intended configuration

### Step 4: Issue-Specific Diagnostics

Based on symptoms, apply diagnostic rules:

| Issue Type | Primary Files | Diagnostic Rules |
|---|---|---|
| Check failures | `status.log`, integration logs | connectivity, check-failures, invalid-key |
| Connectivity / API | `diagnose.log`, `expvar/forwarder` | connectivity, secrets-backend |
| Performance | `expvar/`, `go-routine-dump.log` | performance |
| Logs collection | `status.log` Logs section | logs-agent |
| APM / Tracing | `trace-agent.log`, APM section | apm-trace, dbm-apm-correlation |
| JMX | `jmx.log`, `jmx_status.log` | jmx |
| Kubernetes | `status.log` container section | container-agent, cluster-agent, kubernetes-compatibility |
| Process Agent | `process-agent.log` | process-agent |
| DBM | `postgres.log`, `mysql.log`, etc. | Any db-specific issues |

### Step 5: Integration Version Check

For each integration found in `installed_packages.txt`:

1. **Identify version:** Extract from `installed_packages.txt` (e.g., `datadog-mongo==5.3.0`)
2. **Determine repository:** Check if core or extras
   - Core: bundled with Agent (datadog-agent repo)
   - Extras: community-maintained (integrations-extras repo)
3. **Find latest version:** Query GitHub CHANGELOG or PyPI
4. **Compare:** Identify if outdated
   - Major version behind → likely missing features
   - Minor patch behind → likely bug fixes
5. **Search for related issues:** GitHub PR/issues matching the version and symptoms

### Step 6: Timeline Analysis

When reviewing logs:
1. Find the timestamp of the reported issue
2. Look for events **leading up to it**
3. Check for **patterns** (recurring errors, config reloads)
4. Note any **correlations** (error spikes, performance drops)

### Step 7: Document Findings

Structure report with:

```markdown
## Flare Analysis Summary

**Agent Version:** X.X.X
**Platform:** [OS/Container]
**Flare Date:** YYYY-MM-DD

### Health Status
- 🔴 Critical Issues: [count]
- 🟠 High Priority: [count]
- 🟡 Medium: [count]
- ✅ OK: [components]

### Configuration
- Validated: Yes/No
- Issues found: [list]
- Warnings: [list]

### Integration Versions
| Integration | Installed | Latest | Status |
|---|---|---|---|
| mongo | 5.3.0 | 6.1.0 | ⚠️ Outdated |
| postgres | 12.2.0 | 12.2.0 | ✅ Current |

### Issues Found
1. 🔴 [Critical issue]
   - Evidence: [file/line]
   - Impact: [severity]
   - Fix: [recommendation]

2. 🟠 [High priority issue]
   - Evidence: [file/line]
   - Impact: [severity]
   - Fix: [recommendation]

### Recommendations
1. [Primary action]
2. [Secondary action]
3. [Follow-up verification]

### Related Flare Analysis Skills
- `flare-network-analysis` — For connectivity/forwarder issues
- `flare-profiling-analysis` — For memory/CPU performance issues
```

## Integration with Other Skills

- **Called by:** `investigator` (after downloading flare), `attachment-downloader` (after extraction)
- **Calls:** `flare-network-analysis` (if connectivity issues), `flare-profiling-analysis` (if performance issues)
- **Produces:** `investigations/ZD-{ID}/flare-analysis.md` — structured report
- **Output used by:** `investigator` (includes in findings), `escalation-creator` (includes as evidence)

## Data Sources

### Files Analyzed
- `status.log` — Agent and component status
- `runtime_config_dump.yaml` — Active configuration
- `config-check.log` — Config validation
- `diagnose.log` — Diagnostic output
- `installed_packages.txt` — Integration versions
- Integration-specific logs (postgres.log, mysql.log, etc.)
- `go-routine-dump.log` — Goroutine snapshot (performance)
- `expvar/` — Exposed variables (metrics, forwarder stats)

### External References
- GitHub integrations-core CHANGELOG
- GitHub integrations-extras CHANGELOG
- PyPI API for version lookups
- Agent release notes for compatibility info

## Output

Reports are saved to `investigations/ZD-{ID}/flare-analysis.md` and included in the investigation report's "Flare Analysis" section.

The report is:
- **Actionable:** Clear recommendations for fixes
- **Evidence-based:** References specific files and lines
- **Integrated:** Includes version compatibility assessment
- **Specialized:** Routes to network or profiling analysis if needed

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This file — skill definition |
| `flare-analysis-prompt.md` | Step-by-step flare analysis prompt |
