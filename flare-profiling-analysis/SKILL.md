---
name: flare-profiling-analysis
description: Analyze Go profiling data (pprof) from a locally extracted Datadog Agent flare to identify memory leaks, CPU hotspots, and contention issues. Produces a structured report with heap diffs, top consumers, and an escalation-ready summary.
---

# Flare Profiling Analysis

Analyzes a locally extracted Datadog Agent flare containing `profiles/` directory to produce a structured summary of resource consumption — **memory leaks**, **CPU hotspots**, and **goroutine contention**.

## When This Skill is Activated

Triggers: "analyze flare profiling", "flare memory leak", "flare cpu analysis", "pprof analysis", "agent profiling", "heap analysis", "memory usage flare", "internal profiling flare"

## Prerequisites

- A locally extracted flare directory containing a `profiles/` folder
  - Generated via `internal_profiling: enabled: true` in the agent config
- The user provides the path to the flare directory
- **Go must be installed** (`go tool pprof` is required)
  - If Go is not found, the skill will fail with install instructions

## How to Use

1. Say **"analyze this flare for profiling: /path/to/flare/hostname/"**
2. The agent reads this skill, follows `analyze-prompt.md`
3. Outputs a structured profiling report

## Input

The skill expects a path to an **extracted** flare directory containing:

```
profiles/
├── core-1st-heap.pprof    # Heap snapshot #1 (core agent)
├── core-2nd-heap.pprof    # Heap snapshot #2 (30s later)
├── core-cpu.pprof         # CPU profile (core agent)
├── core-block.pprof       # Block profile (goroutine blocking)
├── core-mutex.pprof       # Mutex contention profile
├── core.trace             # Execution trace (noted, not analyzed)
├── trace-1st-heap.pprof   # Heap snapshot #1 (trace-agent)
├── trace-2nd-heap.pprof   # Heap snapshot #2 (trace-agent)
├── trace-cpu.pprof        # CPU profile (trace-agent)
├── trace-block.pprof      # Block profile (trace-agent)
├── trace-mutex.pprof      # Mutex contention profile (trace-agent)
└── trace.trace            # Execution trace (noted, not analyzed)
```

If the user provides a `.zip`, unzip it first.

## Files Analyzed

### Primary (Profiling Data)

| File | What we extract |
|------|----------------|
| `profiles/core-1st-heap.pprof` | Baseline heap snapshot for the core agent |
| `profiles/core-2nd-heap.pprof` | Second heap snapshot (30s later) — **diff with 1st** reveals growth |
| `profiles/core-cpu.pprof` | Top CPU consumers in the core agent |
| `profiles/core-block.pprof` | Goroutine blocking hotspots |
| `profiles/core-mutex.pprof` | Mutex contention hotspots |
| `profiles/trace-*` | Same as above but for the trace-agent process |

### Light Correlation

| File | What we extract |
|------|----------------|
| `status.log` (header) | Agent version, uptime, hostname |
| `expvar/memstats` | Runtime memory stats — Alloc, Sys, HeapInuse, HeapObjects, NumGC |
| `install_info.log` | Install method |
| `status.log` (Collector section) | Running checks — to correlate allocations with specific integrations |

### Noted Only

| File | Purpose |
|------|---------|
| `profiles/core.trace` | Execution trace file — size noted, left for engineering |
| `profiles/trace.trace` | Same for trace-agent |
| `go-routine-dump.log` | Goroutine dump — count noted, full analysis left for engineering |

## Output Format

The skill produces two outputs:

### 1. Full Report (written to file)
Structured markdown saved to `investigations/flare-profiling-{hostname}.md`:
- Agent Context — version, uptime, hostname, install method
- Memory Stats — from `expvar/memstats` (Alloc, Sys, HeapInuse, GC stats)
- Heap Diff Analysis — what grew between snapshot 1 and 2 (top 10 allocators)
- CPU Profile — top 10 CPU consumers
- Block Profile — top contention points (if any)
- Mutex Profile — top mutex hotspots (if any)
- Trace-Agent Profiles — same analysis for the trace-agent process
- Trace Files — existence and size noted
- Goroutine Dump — count noted
- Running Checks — list from status.log for correlation
- Verdict — Memory Leak / CPU Spike / Contention / Normal
- Recommendations — prioritized action items
- **Customer Message** — concise summary for the Zendesk ticket
- **Escalation Summary** — structured block for JIRA card

### 2. Customer Message (inside the report)
Professional message including top memory/CPU consumers and heap growth numbers. Not full pprof output — just key findings and next steps.

### 3. Escalation Summary (inside the report)
Structured block for copy-pasting into a JIRA card: symptom, top allocators/CPU consumers, agent context, heap diff numbers.

## Verdict Logic

| Condition | Verdict |
|-----------|---------|
| Heap diff shows significant growth (>10MB in 30s) in non-GC functions | **Memory Leak** |
| CPU profile shows a single function consuming >50% CPU | **CPU Spike** |
| Block/mutex profile shows significant contention (>1s cumulative) | **Contention** |
| Multiple of the above | **Multiple Issues** |
| No significant findings in any profile | **Normal** |

## How to Request Profiling from Customer

If the flare has **no `profiles/` directory**, the customer needs to enable profiling first. There are two methods:

### Method 1: One-time capture via flare command (recommended for first diagnosis)

```bash
sudo datadog-agent flare --profile 30
```

This captures a 30-second profiling snapshot and includes it in the flare. No config change needed, no restart. Available since Agent **v6.x / v7.x** (all modern versions).

**When to use:** Quick one-off capture. Customer just needs to run the command while the issue is occurring (high CPU/memory).

### Method 2: Continuous profiling via config (recommended for intermittent issues)

Add to `datadog.yaml`:

```yaml
# Core agent profiling
internal_profiling:
  enabled: true

# Process agent profiling (if process agent memory/CPU is the concern)
process_config:
  internal_profiling:
    enabled: true
```

Restart the agent after this change. Profiles will be continuously collected and included in every flare automatically. Available since Agent **v7.53.0+**.

**When to use:** When the issue is intermittent or hard to reproduce. The customer can send a flare at any time and profiles will be there.

### Customer message template — requesting profiling

```
To investigate the resource usage issue, we need to collect Go profiling data from the agent. Please do the following:

1. Wait until the issue (high memory/CPU) is actively occurring
2. Run the following command:

   sudo datadog-agent flare --profile 30

3. Send us the resulting flare number

This will capture a 30-second snapshot of where the agent is spending CPU and memory, which we will analyze to identify the source of the issue.

If the issue is intermittent and hard to catch, you can enable continuous profiling instead:
- Add `internal_profiling: enabled: true` under the root of your `datadog.yaml`
- Restart the agent
- When the issue next occurs, send a normal flare — profiles will be included automatically
```

### Key references
- [Troubleshooting High Agent CPU or Memory Consumption](https://datadoghq.atlassian.net/wiki/spaces/TS/pages/1106313536)
- [Agent Process Memory Is Very Large (Gigabyte+)](https://datadoghq.atlassian.net/wiki/spaces/TS/pages/3606250273)
- [Agent Internal Profiling](https://datadoghq.atlassian.net/wiki/spaces/agent/pages/2234318891)
- [Viewing Datadog Agent Profiles (pprof)](https://datadoghq.atlassian.net/wiki/spaces/~712020e44eba1b675f43abbbc1a1dcd1af7b79/pages/4425613736)
- [Public docs: High CPU or Memory](https://docs.datadoghq.com/agent/troubleshooting/high_memory_usage/)

## Ownership: Integration vs Core Agent

After analyzing the profiles, the TSE must determine **who owns the fix** — this dictates where to escalate.

### How to determine ownership from pprof output

| Pattern in function path | Owner | What it means |
|--------------------------|-------|---------------|
| `pkg/collector/python._Cfunc_GoString` | **Integration (Python check)** | Memory from Python-to-Go string conversion — proportional to metrics submitted by Python checks |
| `pkg/collector/python.*` | **Integration (Python)** | Python check runtime overhead |
| `pkg/collector/corechecks/*` | **Integration (Go check)** | A specific Go-based core check |
| `pkg/aggregator.*` | **Core Agent** (aggregation) | Metric context tracking, sample buffering — often caused by high cardinality |
| `pkg/serializer.*` | **Core Agent** (serialization) | Serialization buffers — usually related to payload size |
| `pkg/forwarder.*` | **Core Agent** (forwarder) | Network/HTTP client — may indicate backpressure |
| `pkg/trace.*` | **Trace-Agent** (APM) | Trace processing pipeline |
| `pkg/process.*` | **Process Agent** | Process/container collection |
| `pkg/obfuscate.*` | **DBM / APM** | SQL obfuscation — heavy with DBM |
| `pkg/metrics.*` | **Core Agent** (metrics pipeline) | Gauge/Histogram flush — scales with # of metric contexts |
| `pkg/tagset.*` | **Core Agent** (tagging) | Tag hashing — high cardinality driver |
| `runtime.*` | **Go runtime** | GC, goroutine scheduling — usually informational |
| `[libpython3.*]` | **Integration (Python runtime)** | Embedded Python interpreter CPU/memory |
| `ristretto.*` | **Core Agent** (cache) | In-memory cache for contexts/tags |

### Decision tree for escalation routing

```
1. Is the top consumer in pkg/collector/python.* or [libpython*]?
   → YES: Integration issue. Check which checks are running (status.log).
          Correlate with the number of instances.
          Escalate to the integration team owning that check.

2. Is the top consumer in pkg/aggregator.* or pkg/metrics.*?
   → YES: Core agent aggregation pipeline.
          Likely high cardinality (too many unique metric contexts).
          Escalate to Agent team (#support-agent).

3. Is the top consumer in pkg/trace.*?
   → YES: Trace-agent issue.
          Escalate to APM team.

4. Is the top consumer in pkg/obfuscate.*?
   → YES: DBM SQL obfuscation.
          Escalate to DBM team.

5. Is it in runtime.* or system libs?
   → Usually not actionable. Look deeper at the cum% column.
```

### What to tell the escalation team

The escalation summary in the report should contain:
1. **Symptom** — what the customer reported (memory growing, CPU spike, etc.)
2. **Top allocators / CPU consumers** — raw pprof output (top 5-10 lines)
3. **Heap diff** — what grew between the two snapshots
4. **Agent context** — version, uptime, running checks, install method
5. **memstats** — Alloc, Sys, HeapInuse, HeapObjects, NumGC
6. **Correlation** — if the growth maps to a specific integration, call it out explicitly
7. **Flare link** — the flare file or ticket link

## Integration

Works standalone. Can be used alongside:
- `flare-network-analysis` — when a ticket involves both network and resource issues
- `zendesk-ticket-investigator` — when a ticket includes a flare with performance symptoms
