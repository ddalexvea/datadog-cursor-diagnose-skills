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

## Integration

Works standalone. Can be used alongside:
- `flare-network-analysis` — when a ticket involves both network and resource issues
- `zendesk-ticket-investigator` — when a ticket includes a flare with performance symptoms
