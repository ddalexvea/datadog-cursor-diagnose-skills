import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const CLUSTERS = {
  us1: "monitor-results-realtime.us1.prod.dog",
  eu1: "monitor-results-realtime.eu1.prod.dog",
  us3: "monitor-results-realtime.us3.prod.dog",
  us5: "monitor-results-realtime.us5.prod.dog",
  ap1: "monitor-results-realtime.ap1.prod.dog",
  us1_fed: "monitor-results-realtime.us1-fed.prod.dog",
};

async function apiCall(cluster, path, body) {
  const host = CLUSTERS[cluster];
  if (!host) throw new Error(`Unknown cluster: ${cluster}. Valid: ${Object.keys(CLUSTERS).join(", ")}`);
  const res = await fetch(`https://${host}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(JSON.stringify(data));
  return data;
}

const STATUS_MAP = { 0: "OK", 1: "ALERT", 2: "WARNING", 3: "NO_DATA", 4: "SKIPPED", 10: "OK_STAY_ALERT" };

function formatStatusCounts(counts) {
  return Object.entries(counts)
    .map(([k, v]) => `${STATUS_MAP[k] || `STATUS_${k}`}: ${v}`)
    .join(", ");
}

const server = new McpServer({
  name: "monitor-admin",
  version: "1.0.0",
});

// 1. Get current monitor state
server.tool(
  "monitor_get_state",
  "Get the current state of a monitor and all its groups. Shows overall status, per-group status, and forced status reasons.",
  {
    cluster: z.enum(Object.keys(CLUSTERS)).describe("Datadog cluster (e.g., eu1, us1)"),
    org_id: z.string().describe("Organization ID"),
    monitor_id: z.string().describe("Monitor ID"),
  },
  async ({ cluster, org_id, monitor_id }) => {
    const data = await apiCall(cluster, "/v1/monitor_states/get", {
      monitorId: monitor_id,
      orgId: org_id,
    });
    const groups = Object.values(data.groups || {});
    const summary = [
      `Monitor ${monitor_id} (org ${org_id}) on ${cluster}`,
      `Overall State: ${data.overallState}`,
      `State Map: ${JSON.stringify(data.stateMap)}`,
      `Total Groups: ${data.numGroups}`,
      `Last Result: ${new Date(Number(data.last_result_ts) * 1000).toISOString()}`,
      `State Modified: ${data.overall_state_modified}`,
      "",
      "Groups with non-OK status or forced reasons:",
    ];
    const interesting = groups.filter(
      (g) => g.status !== "OK" || g.forced_status_reason !== "none" || g.removed_ts
    );
    if (interesting.length === 0) {
      summary.push("  (all groups OK, no forced statuses)");
    } else {
      for (const g of interesting) {
        let line = `  ${g.name}: ${g.status}`;
        if (g.forced_status_reason !== "none") line += ` (forced: ${g.forced_status_reason})`;
        if (g.removed_ts) line += ` (removed: ${new Date(Number(g.removed_ts) * 1000).toISOString()})`;
        summary.push(line);
      }
    }
    return { content: [{ type: "text", text: summary.join("\n") }] };
  }
);

// 2. Get monitor evaluation results for a time range
server.tool(
  "monitor_get_results",
  "Get monitor evaluation results for a time range. Each result represents one evaluation cycle (typically 1/min for sub-24hr integration periods). Shows result IDs, timestamps, errors, group status counts, and distribution factor.",
  {
    cluster: z.enum(Object.keys(CLUSTERS)).describe("Datadog cluster"),
    org_id: z.string().describe("Organization ID"),
    monitor_id: z.string().describe("Monitor ID"),
    from: z.string().describe("Start time in ISO 8601 UTC (e.g., 2026-02-12T10:11:00.000Z)"),
    to: z.string().describe("End time in ISO 8601 UTC (e.g., 2026-02-12T11:31:00.000Z)"),
  },
  async ({ cluster, org_id, monitor_id, from, to }) => {
    const data = await apiCall(cluster, "/v1/monitor_results/get_from_timerange", {
      from,
      to,
      monitor_id,
      org_id,
    });
    const results = data.results || [];
    const lines = [
      `Monitor ${monitor_id} results from ${from} to ${to}`,
      `Total results: ${results.length}`,
      "",
    ];
    for (const r of results) {
      const res = r.result;
      const meta = r.metadata;
      const evalTs = new Date(Number(res.evaluation_timestamp) * 1000).toISOString();
      const schedTs = new Date(Number(res.scheduled_timestamp) * 1000).toISOString();
      const hasError = res.eval_error && Object.keys(res.eval_error).length > 0;
      lines.push(
        `Result ${res.result_id} | eval: ${evalTs} | sched: ${schedTs} | ${formatStatusCounts(meta.status_counts)} | dist: ${meta.distribution_factor}${hasError ? " | ERROR: " + JSON.stringify(res.eval_error) : ""}`
      );
    }
    return { content: [{ type: "text", text: lines.join("\n") }] };
  }
);

// 3. Get detailed result for a specific evaluation
server.tool(
  "monitor_get_result_detail",
  "Get detailed evaluation result showing per-group values, statuses, and thresholds. This is the key tool for understanding WHY a monitor triggered - compare each group's value against its threshold.",
  {
    cluster: z.enum(Object.keys(CLUSTERS)).describe("Datadog cluster"),
    org_id: z.string().describe("Organization ID"),
    result_id: z.string().describe("Result ID from monitor_get_results"),
    timestamp: z.string().describe("Evaluation timestamp in ISO 8601 UTC from the result"),
    group_filter: z
      .string()
      .optional()
      .describe("Optional: filter groups by name substring (e.g., 'statuscode:503')"),
    status_filter: z
      .array(z.enum(["OK", "ALERT", "WARNING", "NO_DATA", "SKIPPED", "OK_STAY_ALERT"]))
      .optional()
      .describe("Optional: only show groups with these statuses"),
  },
  async ({ cluster, org_id, result_id, timestamp, group_filter, status_filter }) => {
    const data = await apiCall(cluster, "/v1/monitor_results/get", {
      id: result_id,
      org_id,
      timestamp,
    });
    const sched = data.result?.scheduling_result;
    const evalResult = sched?.evaluation_result || {};
    let groups = evalResult.groups || [];

    const monitor = sched?.monitor || {};
    const queryInfo = evalResult.parsed_monitor_query_info || {};
    const queryDebug = evalResult.debug?.content?.query || null;
    const comparator = queryInfo.comparator || "unknown";
    const comparatorSymbol = { GE: ">=", GT: ">", LE: "<=", LT: "<", EQ: "==" }[comparator] || comparator;

    if (group_filter) {
      groups = groups.filter((g) => g.name.includes(group_filter));
    }
    const statusCodeMap = Object.fromEntries(Object.entries(STATUS_MAP).map(([k, v]) => [v, Number(k)]));
    if (status_filter && status_filter.length > 0) {
      const codes = new Set(status_filter.map((s) => statusCodeMap[s]));
      groups = groups.filter((g) => codes.has(g.status || 0));
    }

    const lines = [];

    if (monitor.name) lines.push(`Monitor: ${monitor.name} (ID: ${monitor.id})`);
    if (queryDebug) lines.push(`Query: ${queryDebug}`);
    if (queryInfo.metrics?.length) lines.push(`Metrics: ${queryInfo.metrics.join(", ")}`);
    lines.push(`Comparator: ${comparatorSymbol} (triggers when value ${comparatorSymbol} threshold)`);
    if (queryInfo.timeframe) lines.push(`Timeframe: ${queryInfo.timeframe}`);
    lines.push("");
    lines.push(`Result ${result_id} detail (${groups.length} groups shown)`);
    lines.push("");

    for (const g of groups) {
      const status = STATUS_MAP[g.status || 0] || `STATUS_${g.status}`;
      let line = `  ${g.name}: ${status}`;
      if (g.value !== undefined) line += ` | value: ${g.value}`;
      if (g.details?.snapshot_data) {
        const sd = g.details.snapshot_data;
        line += ` | threshold: ${sd.threshold}`;
        if (g.value !== undefined && sd.threshold !== undefined) {
          const margin = sd.threshold - g.value;
          const pct = sd.threshold !== 0 ? ((margin / sd.threshold) * 100).toFixed(1) : "N/A";
          line += ` | margin: ${margin >= 0 ? "+" : ""}${margin.toFixed(4)} (${pct}% of threshold)`;
        }
        if (sd.critical_recovery_threshold !== undefined)
          line += ` | recovery: ${sd.critical_recovery_threshold}`;
        line += ` | window: ${sd.from_ts} -> ${sd.to_ts}`;
      }
      if (g.last_seen) line += ` | last_seen: ${g.last_seen}`;
      lines.push(line);
    }
    return { content: [{ type: "text", text: lines.join("\n") }] };
  }
);

// 4. Get group payload (alert history)
server.tool(
  "monitor_get_group_payload",
  "Get detailed group payload showing alert history: last triggered, last resolved, last notified timestamps, and alert cycle keys. Useful for understanding the alerting history of a monitor's groups.",
  {
    cluster: z.enum(Object.keys(CLUSTERS)).describe("Datadog cluster"),
    org_id: z.string().describe("Organization ID"),
    monitor_id: z.string().describe("Monitor ID"),
    group_filter: z.string().optional().describe("Optional: filter groups by name substring"),
  },
  async ({ cluster, org_id, monitor_id, group_filter }) => {
    const data = await apiCall(cluster, "/v1/monitor_states/get_payload", {
      monitorId: monitor_id,
      orgId: org_id,
    });
    let groups = data.groups || [];
    if (group_filter) {
      groups = groups.filter((g) => g.name.includes(group_filter));
    }

    const interesting = groups.filter(
      (g) => g.last_triggered_ts || g.last_resolved_ts || g.removed_ts
    );

    const lines = [
      `Monitor ${monitor_id} group payload (${interesting.length} groups with history, ${groups.length} total)`,
      "",
    ];
    for (const g of interesting) {
      const parts = [`  ${g.name}`];
      if (g.last_triggered_ts)
        parts.push(`triggered: ${new Date(Number(g.last_triggered_ts) * 1000).toISOString()}`);
      if (g.last_resolved_ts)
        parts.push(`resolved: ${new Date(Number(g.last_resolved_ts) * 1000).toISOString()}`);
      if (g.last_notified_ts)
        parts.push(`notified: ${new Date(Number(g.last_notified_ts) * 1000).toISOString()}`);
      if (g.first_triggered_ts)
        parts.push(`first_triggered: ${new Date(Number(g.first_triggered_ts) * 1000).toISOString()}`);
      if (g.removed_ts)
        parts.push(`removed: ${new Date(Number(g.removed_ts) * 1000).toISOString()}`);
      lines.push(parts.join(" | "));
    }
    return { content: [{ type: "text", text: lines.join("\n") }] };
  }
);

// 5. Search downtimes
server.tool(
  "monitor_downtime_search",
  "Search for downtimes that may affect a monitor. Useful to check if a monitor was silenced during a period.",
  {
    cluster: z.enum(Object.keys(CLUSTERS)).describe("Datadog cluster"),
    org_id: z.string().describe("Organization ID"),
    query: z.string().describe("Search query for downtimes"),
    size: z.number().optional().default(50).describe("Number of results"),
  },
  async ({ cluster, org_id, query, size }) => {
    const data = await apiCall(cluster, "/v1/monitor_results/downtime_search", {
      org_id,
      query,
      size,
      from: 0,
    });
    const lines = [`Downtime search for "${query}" (total: ${data.total?.value || 0})`, ""];
    for (const d of data.downtimes || []) {
      lines.push(`  ${JSON.stringify(d)}`);
    }
    if ((data.downtimes || []).length === 0) lines.push("  No downtimes found.");
    return { content: [{ type: "text", text: lines.join("\n") }] };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
