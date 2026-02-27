Analyze the Datadog Agent flare at `{{FLARE_PATH}}` for internal profiling data (memory, CPU, contention).

## Step 0: Verify Go is installed

Run `go version` to confirm Go is available.

If Go is **not installed**, stop and display:
```
❌ Go is required for profiling analysis.

Install Go: https://go.dev/dl/
macOS: brew install go
```

## Step 1: Locate the flare root

The flare may be a zip or extracted directory. If zip, extract it first.
Inside, find the hostname directory (e.g., `i-0abc123def/`) — that's the flare root.

Confirm the `profiles/` directory exists and contains `.pprof` files.
If no `profiles/` directory is found, stop and report:
```
No profiles/ directory found in this flare.
The agent was likely not configured with internal_profiling: enabled: true
```

List what's in `profiles/` and note file sizes.

## Step 2: Extract agent context

Read the **first 15 lines of `status.log`** to get:
- Agent version
- Status date and Agent start time → compute **uptime**
- Hostname

Also read:
- `install_info.log` → install method
- `status.log` Collector section → list of running checks (just check names, not full config)

## Step 3: Read memory stats

Read `expvar/memstats` and extract:
- `Alloc` — currently allocated bytes (in use by the application)
- `TotalAlloc` — cumulative bytes allocated (ever)
- `Sys` — total memory obtained from OS
- `HeapAlloc` — heap bytes in use
- `HeapSys` — heap bytes obtained from OS
- `HeapInuse` — heap bytes in in-use spans
- `HeapIdle` — heap bytes in idle spans
- `HeapReleased` — heap bytes released to OS
- `HeapObjects` — number of allocated heap objects
- `NumGC` — number of completed GC cycles
- `PauseTotalNs` — total GC pause time (convert to ms)
- `LastGC` — timestamp of last GC (convert to human-readable)
- `NextGC` — target heap size for next GC

Convert all byte values to human-readable (MB/GB).

## Step 4: Heap diff analysis (CORE AGENT)

This is the most important step for memory leak detection.

Run the heap diff between the two snapshots to see what **grew**:

```bash
go tool pprof -top -diff_base={{FLARE_PATH}}/profiles/core-1st-heap.pprof {{FLARE_PATH}}/profiles/core-2nd-heap.pprof 2>&1 | head -30
```

This shows `inuse_space` growth by default — functions that allocated more memory between snapshot 1 and 2 (30s apart).

Also get `inuse_objects` diff to see object count growth:

```bash
go tool pprof -top -sample_index=inuse_objects -diff_base={{FLARE_PATH}}/profiles/core-1st-heap.pprof {{FLARE_PATH}}/profiles/core-2nd-heap.pprof 2>&1 | head -30
```

Also get the absolute top allocators from the **2nd snapshot** (current state):

```bash
go tool pprof -top {{FLARE_PATH}}/profiles/core-2nd-heap.pprof 2>&1 | head -25
```

**Interpretation guide:**
- `flat` = memory directly allocated by this function
- `cum` = memory allocated by this function + everything it calls
- Large `flat` in internal Go functions (e.g., `runtime.malg`, `runtime.allocm`) is usually normal
- Large `flat` in `pkg/collector/python._Cfunc_GoString` → Python check memory
- Large `flat` in `pkg/aggregator` or `pkg/metrics` → aggregation pipeline memory
- Large `flat` in `pkg/serializer` → serialization buffer growth

## Step 5: CPU profile analysis (CORE AGENT)

```bash
go tool pprof -top {{FLARE_PATH}}/profiles/core-cpu.pprof 2>&1 | head -25
```

**Interpretation guide:**
- Duration line shows the profiling window (e.g., `Duration: 30s`)
- High CPU in `runtime.cgocall` → CGo/Python overhead
- High CPU in `compress/zlib` → compression overhead (usually normal)
- High CPU in `pkg/collector` → check collection overhead
- High CPU in `pkg/aggregator` → aggregation bottleneck

## Step 6: Block profile analysis (CORE AGENT)

```bash
go tool pprof -top {{FLARE_PATH}}/profiles/core-block.pprof 2>&1 | head -20
```

Shows where goroutines block waiting on synchronization.
- High `contentions` in `sync.(*Mutex).Lock` → lock contention
- High `delay` values → goroutines spending significant time waiting
- Usually informational; concerning if total delay > seconds

## Step 7: Mutex profile analysis (CORE AGENT)

```bash
go tool pprof -top {{FLARE_PATH}}/profiles/core-mutex.pprof 2>&1 | head -20
```

Shows mutex contention hotspots.
- Similar to block profile but focused on mutex unlock delay
- Concerning if a single mutex holds >50% of contention

## Step 8: Trace-agent profiles

Repeat Steps 4-7 for `trace-*` files:

```bash
# Heap diff
go tool pprof -top -diff_base={{FLARE_PATH}}/profiles/trace-1st-heap.pprof {{FLARE_PATH}}/profiles/trace-2nd-heap.pprof 2>&1 | head -30

# CPU
go tool pprof -top {{FLARE_PATH}}/profiles/trace-cpu.pprof 2>&1 | head -25

# Block
go tool pprof -top {{FLARE_PATH}}/profiles/trace-block.pprof 2>&1 | head -20

# Mutex
go tool pprof -top {{FLARE_PATH}}/profiles/trace-mutex.pprof 2>&1 | head -20
```

If trace-agent files are missing or empty, note "No trace-agent profiles available" and skip.

## Step 9: Note trace files and goroutine dump

For execution traces (`core.trace`, `trace.trace`):
- Note their **file size** only
- Do NOT analyze them — they require `go tool trace` which renders in a browser
- Mention they are available for engineering if needed

For `go-routine-dump.log`:
- Count total goroutines (count lines matching `^goroutine `)
- Note if count is unusually high (>500 is worth flagging)
- Do NOT dump the full content — just the count

## Step 10: Write the report

Save to `investigations/flare-profiling-{hostname}.md`:

```markdown
# Flare Profiling Analysis: {hostname}

**Agent:** v{version} | **Uptime:** {X days Y hours} | **Hostname:** {hostname}
**Install:** {method} | **Flare date:** {date} | **Profile source:** internal_profiling

---

## Verdict: {MEMORY LEAK / CPU SPIKE / CONTENTION / MULTIPLE ISSUES / NORMAL}

{One-line summary of the main finding}

---

## Memory Stats (expvar/memstats)

| Metric | Value |
|--------|-------|
| Alloc (in use) | {MB} |
| Sys (from OS) | {MB} |
| HeapInuse | {MB} |
| HeapObjects | {n} |
| NumGC | {n} |
| GC Pause Total | {ms} |

---

## Core Agent — Heap Diff (1st → 2nd, 30s window)

**Total growth:** {X MB} in 30 seconds

### Top allocators by memory growth (inuse_space)

| Rank | Function | Growth (flat) | Growth (cum) |
|------|----------|---------------|--------------|
| 1 | {package.Function} | {KB/MB} | {KB/MB} |
| 2 | ... | ... | ... |
| ... | ... | ... | ... |

### Top allocators by object count growth (inuse_objects)

| Rank | Function | Objects (flat) | Objects (cum) |
|------|----------|----------------|---------------|
| 1 | {package.Function} | {n} | {n} |
| ... | ... | ... | ... |

### Current heap state (2nd snapshot)

| Rank | Function | In Use (flat) | In Use (cum) |
|------|----------|---------------|--------------|
| 1 | {package.Function} | {MB} | {MB} |
| ... | ... | ... | ... |

**Analysis:** {2-3 sentences interpreting the heap data — is there a leak? Which component? What's growing?}

---

## Core Agent — CPU Profile

**Duration:** {N}s | **Total samples:** {N}

| Rank | Function | CPU (flat) | CPU (cum) |
|------|----------|------------|-----------|
| 1 | {package.Function} | {%} | {%} |
| ... | ... | ... | ... |

**Analysis:** {1-2 sentences — any abnormal CPU consumers?}

---

## Core Agent — Block Profile

| Rank | Function | Contentions | Delay |
|------|----------|-------------|-------|
| 1 | {package.Function} | {n} | {duration} |
| ... | ... | ... | ... |

(If empty or minimal: "No significant blocking contention detected.")

---

## Core Agent — Mutex Profile

| Rank | Function | Contentions | Delay |
|------|----------|-------------|-------|
| 1 | {package.Function} | {n} | {duration} |
| ... | ... | ... | ... |

(If empty or minimal: "No significant mutex contention detected.")

---

## Trace-Agent Profiles

(Same structure as core agent sections, or "No trace-agent profiles available")

### Heap Diff
{table}

### CPU Profile
{table}

### Block/Mutex
{summary}

---

## Execution Traces & Goroutine Dump

| File | Size | Note |
|------|------|------|
| core.trace | {size} | Available for `go tool trace` analysis |
| trace.trace | {size} | Available for `go tool trace` analysis |
| go-routine-dump.log | {goroutine count} goroutines | {Normal / High — flag if >500} |

---

## Running Checks

{List of checks from status.log Collector section — useful for correlating allocations with specific integrations}

---

## Recommendations

1. **{Priority}** — {action item}
2. **{Priority}** — {action item}
3. ...

---

## Customer Message

Hi {customer},

After analyzing the agent profiling data from the flare, here is what we found:

**Agent:** v{version} running on `{hostname}` (uptime: {uptime})

**Memory overview:**
- Current heap in use: {HeapInuse} MB ({HeapObjects} objects)
- Heap growth observed over 30s profiling window: {growth} MB
{If growth is significant:
- Top memory consumers:
  - `{function1}`: {growth1}
  - `{function2}`: {growth2}}

**CPU overview:**
- Top CPU consumer: `{function}` at {percentage}%
{If abnormal: "This is above expected levels for normal agent operation."}
{If normal: "CPU usage appears normal."}

{1-2 sentences with finding and next steps — e.g., "The profiling data shows memory growth in the aggregation pipeline, which may indicate a memory leak related to the number of unique metric contexts. We are escalating to our engineering team for further analysis."}

Please let us know if you have any questions.

Best regards,
Alexandre

---

## Escalation Summary

**For JIRA / Slack escalation — copy-paste ready:**

```
Ticket: {ticket_url_or_id}
Agent: v{version} on {hostname} ({OS})
Uptime: {uptime}
Symptom: {brief description — e.g., "memory growing steadily, reported by customer after upgrade to 7.73"}
Profile source: internal_profiling (30s window)

Heap diff (inuse_space, top 5):
{pprof -top output, first 5 lines}

Heap diff (inuse_objects, top 5):
{pprof -top output, first 5 lines}

Current heap (2nd snapshot, top 5):
{pprof -top output, first 5 lines}

CPU (top 5):
{pprof -top output, first 5 lines}

Memstats: Alloc={X}MB, Sys={Y}MB, HeapInuse={Z}MB, HeapObjects={N}, NumGC={N}
Running checks: {list}

Flare: {path or link}
```
```

## Verdict Decision Logic

**MEMORY LEAK** if ANY of:
- Heap diff shows >10MB growth in 30s in application functions (not runtime/GC)
- A single non-runtime function accounts for >30% of heap growth
- HeapObjects growing with flat NumGC (GC not collecting)

**CPU SPIKE** if ANY of:
- A single application function consumes >50% of CPU flat
- Total CPU utilization anomaly (>80% in non-runtime functions)

**CONTENTION** if ANY of:
- Block profile shows >1s cumulative delay in a single function
- Mutex profile shows >1s cumulative delay in a single mutex

**MULTIPLE ISSUES** if more than one of the above conditions are met.

**NORMAL** if:
- Heap growth < 5MB in 30s
- No single function dominates CPU
- No significant contention
- Memory stats consistent with expected agent footprint

## Rules

- **NEVER expose API keys** — always use `[REDACTED]`
- Keep pprof output faithful — don't rearrange or truncate function names
- Convert bytes to human-readable (KB/MB/GB) in tables
- Include the raw pprof top output in the Escalation Summary for engineering
- If a profile file is missing or empty (0 bytes), note it and skip — don't fail
- Ticket URL or ID should be included in the escalation block if known from context
