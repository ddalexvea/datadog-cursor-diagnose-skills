Investigate the monitor triggering issue described by the user using the Monitor Admin MCP tools.

## Prerequisites Check

- The `monitor-admin` MCP server must be running (configured in `~/.cursor/mcp.json`)
- You must be on the Datadog VPN (APIs are VPN-gated, no auth tokens needed)

If MCP tools are unavailable, tell the user to run `setup.sh` from the skill directory and restart Cursor.

## Step 1: Parse Input

The user will provide some combination of:
- **org_id**: The customer's organization ID (numeric, e.g., `1234567890`)
- **monitor_id**: The monitor being investigated (numeric, e.g., `12345678`)
- **time range**: When the issue occurred — convert to **UTC ISO 8601** before calling APIs. Ask for timezone if unclear.
- **group query**: Optional specific group to focus on (e.g., `test_tenant:de,statuscode:503`)
- **cluster**: Derive automatically from org_id (see Cluster Lookup below)
- **Monitor Admin URL**: Parse org_id, monitor_id, cluster, time range (from_ts/to_ts are millisecond unix timestamps), and group_name from URLs like:
  `https://monitor-admin.eu1.prod.dog/monitors/cluster/realtime/org/{org_id}/monitor/{monitor_id}?from_ts=...&to_ts=...&group_name=...`

## Step 2: Derive Cluster from Org ID

**Do not ask the user for the datacenter if the org_id falls in a known range.**

| Cluster | Org ID Range |
|---------|-------------|
| us1 | 1 – 999,999,999 (< 1B) |
| eu1 | 1,000,000,000 – 1,099,999,999 (1B – 1.1B) |
| us1_fed | 1,100,000,000 – 1,199,999,999 (1.1B – 1.2B) |
| us3 | 1,200,000,000 – 1,299,999,999 (1.2B – 1.3B) |
| us5 | 1,300,000,000 – 1,399,999,999 (1.3B – 1.4B) |
| ap1 | 1,400,000,000+ (1.4B+) |

**Important**: For org_ids >= 1,400,000,000 (ap1 range), the mapping may not be accurate as new datacenters may exist. Ask the user to confirm the cluster if the org_id is >= 1.4B.

## Step 3: Get Current Monitor State

Use `monitor_get_state` to understand the current state of the monitor.

Look for:
- How many groups are there?
- What is the overall state (OK / ALERT / WARNING)?
- Are any groups in non-OK states?
- Are there forced statuses (e.g., `new_group_delay`)?

## Step 4: Get Evaluation Results for the Time Range

Use `monitor_get_results` to list all evaluations during the period of interest.

Look for:
- Status counts per evaluation (OK, ALERT, WARNING, SKIPPED, OK_STAY_ALERT)
- Evaluation errors (any `eval_error` fields)
- When status transitions happened (when ALERT count increased from 0)
- Distribution factor for each evaluation

Expand the time range by ±30 minutes around the reported incident time to capture the full transition.

## Step 5: Drill Into Specific Evaluations (Key Step)

Use `monitor_get_result_detail` for key evaluation timestamps — especially those where the ALERT count changed.

This is the most important step — it shows the actual **value vs threshold** for each group.

For each evaluation:
- Note the **monitor query**, **monitor name**, and **comparator** (e.g., `>=`) — this explains what is being measured and the trigger condition
- Use `group_filter` to focus on the specific group(s) the user asked about
- Use `status_filter: ["ALERT"]` to isolate triggering groups

**Margin analysis** — the tool computes how far each value was from the threshold:
- **Positive margin** (e.g., +0.9286): Value is below threshold — monitor is NOT triggering
- **Negative margin** (e.g., -0.5): Value exceeded threshold — monitor IS triggering
- **Small margin** (±0.05): Value is very close to the threshold (borderline / potentially noisy)
- A margin of -500% = massive overshoot (clear incident); a margin of -2% = barely triggered (possibly noise)

Track margin across multiple evaluations to show the trend and whether this was a clear spike or borderline crossing.

## Step 6: Check Alert History (If Needed)

Use `monitor_get_group_payload` to see when groups last triggered, resolved, and were notified.

Useful for:
- Understanding alert cycling (trigger → resolve → re-trigger patterns)
- Finding `first_triggered_ts` and `last_resolved_ts`
- Checking if groups were removed

## Step 7: Check Downtimes (If Relevant)

Use `monitor_downtime_search` if the user suspects the monitor was silenced during the period.

## Status Codes Reference

| Code | Name | Meaning |
|------|------|---------|
| 0 | OK | Value is below threshold |
| 1 | ALERT | Value exceeds critical threshold |
| 2 | WARNING | Value exceeds warning threshold |
| 3 | NO_DATA | No data received for this group |
| 4 | SKIPPED | Group was skipped (not enough data points) |
| 10 | OK_STAY_ALERT | Value recovered below threshold but monitor stays in alert (recovery conditions not yet met) |

## Key Concepts

- **Evaluation**: One cycle of the monitor query being run. For monitors with integration periods < 24hr, this happens every minute.
- **Threshold**: The value the metric is compared against. If `value >= threshold`, the group enters ALERT.
- **Recovery threshold**: The value below which the metric must fall for the monitor to recover from ALERT to OK.
- **Distribution factor**: Internal distribution metric (e.g., "2/3" means evaluation shard 2 of 3).
- **Forced status**: System-forced group status (e.g., `new_group_delay` holds new groups in OK until enough data is collected).
- **SKIPPED**: Groups without enough data to evaluate. Normal for sparse metrics.
- **OK_STAY_ALERT (status 10)**: Value is currently OK but the group stays in ALERT because recovery threshold or recovery conditions over enough cycles haven't been met.

## Output Format

Provide a clear summary with these sections:

1. **Monitor definition** — What the monitor measures: query, metric, comparator, threshold. This sets context for the entire investigation.
2. **Current state** — Overall monitor state, group count, any forced statuses
3. **Timeline** — What happened during the investigated period (evaluation-by-evaluation if relevant)
4. **Root cause** — Why the monitor triggered (or didn't) — always cite specific value vs threshold
5. **Margin analysis** — How close was the value to the threshold? Was it a clear spike (large negative margin) or borderline crossing (small negative margin)? Show margin trend across evaluations.
6. **Group details** — For specific groups asked about, show the value progression

Be precise with numbers. Always show the actual value, threshold, and margin when explaining trigger/recovery behavior.

## Example

User: "Why did monitor 12345678 trigger for org 1234567890 on eu1 around Feb 12, 11:25 AM UTC for group env:prod,service:web?"

1. Derive cluster: org_id 1234567890 → eu1
2. `monitor_get_state` → Monitor currently OK, 96 groups
3. `monitor_get_results` from 10:15 to 12:30 UTC → Find result at 11:27 where ALERT count = 1
4. `monitor_get_result_detail` for that result, `group_filter: "service:web"`:
   - Query: `anomalies(sum:my.metric{*} by {group}.as_count(), ...)`, comparator: `>=`
   - Value was 1.5, threshold is 1.0 — margin: -0.5 (-50%) → triggered because error rate exceeded threshold by 50%
5. Check surrounding evaluations → at 11:28 margin was +0.3 (recovered); pattern shows a 1-minute spike
