#!/bin/bash
# Support Admin API via Chrome JS — shared helper for all support-admin skills
# Usage: support-admin-api.sh <command> [args...]
#
# Commands:
#   tab                              Find Support Admin tab index in Chrome
#   auth                             Verify session is valid
#   org                              Get current org context (org_id, org_name)
#   spans <query> [from] [to]        Search spans (APM trace search)
#   trace <trace_id>                 Get a full trace by ID
#   services [query]                 List/search services
#   logs <query> [from] [to]         Search logs
#   metrics <query> [from] [to]      Query metrics timeseries
#   hosts [filter]                   List hosts
#   monitors [query]                 List monitors
#
# Output format matches Datadog MCP tool output (METADATA + TSV/JSON/YAML wrappers).
#
# Prerequisites:
#   - macOS with osascript
#   - Google Chrome running with a tab on https://support-admin.us1.prod.dog
#   - "Allow JavaScript from Apple Events" enabled (Chrome > View > Developer)
#   - Authenticated session on support-admin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/chrome-helper.sh"

COMMAND="${1:-help}"
shift || true

SA_URL="support-admin.us1.prod.dog"

# ── Tab helpers (reuse chrome-helper.sh) ──────────────────────────────────────

find_tab() {
    chrome_find_tab "$SA_URL"
}

chrome_js() {
    chrome_exec_js "$1" "$2" "$3"
}

# Robust JS file executor: writes an AppleScript file and runs osascript on it.
# This avoids all quoting/escaping issues that plague the inline -e approach.
# Uses python3 JSON-encoding so JS with any quotes/backslashes works correctly.
chrome_js_file() {
    local win_index="$1"
    local tab_index="$2"
    local js_file="$3"

    _chrome_ensure_target || { echo "ERROR: Cannot reach Chrome"; return 1; }

    # Read JS, strip // comments (they break single-line collapse), collapse to one line,
    # then JSON-encode it so it's a safe AppleScript string
    local js_escaped
    js_escaped=$(python3 -c "
import sys, json, re
code = open(sys.argv[1]).read()
code = re.sub(r'(?m)^\s*//.*$', '', code)          # full-line // comments
code = re.sub(r'\s//[^\n]*', '', code)             # trailing // comments
code = code.replace(chr(10), ' ')
print(json.dumps(code))
" "$js_file")

    # Build AppleScript file using printf (heredoc would break on the quotes in js_escaped)
    local as_file
    as_file=$(mktemp /tmp/sa-as-XXXXXXXX)
    printf 'tell application "Google Chrome"\n    tell tab %s of window %s\n        return (execute javascript %s)\n    end tell\nend tell\n' \
        "$tab_index" "$win_index" "$js_escaped" > "$as_file"

    osascript "$as_file" 2>/dev/null
    local rc=$?
    rm -f "$as_file"
    return $rc
}

require_tab() {
    local result
    result=$(find_tab)
    local win_index="${result%%:*}"
    local tab_index="${result##*:}"
    if [ "$win_index" -le 0 ] 2>/dev/null || [ "$tab_index" -le 0 ] 2>/dev/null; then
        echo "ERROR: No Support Admin tab found in Chrome. Open https://${SA_URL} and log in." >&2
        exit 1
    fi
    echo "$win_index:$tab_index"
}

parse_win() { echo "${1%%:*}"; }
parse_tab() { echo "${1##*:}"; }

# ── Helpers ───────────────────────────────────────────────────────────────────

# Default time range: last 1 hour
default_from() { echo "${1:-$(( $(date +%s) - 3600 ))}"; }
default_to()   { echo "${1:-$(date +%s)}"; }

# Convert relative time (now-1h, now-15m, now-1d) to epoch seconds
parse_time() {
    local t="$1"
    if [[ "$t" == "now" ]]; then
        date +%s
    elif [[ "$t" =~ ^now-([0-9]+)([smhd])$ ]]; then
        local val="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        local now; now=$(date +%s)
        case "$unit" in
            s) echo $(( now - val )) ;;
            m) echo $(( now - val * 60 )) ;;
            h) echo $(( now - val * 3600 )) ;;
            d) echo $(( now - val * 86400 )) ;;
        esac
    elif [[ "$t" =~ ^[0-9]+$ ]]; then
        # Already epoch seconds (or ms — convert if > 10 digits)
        if [ ${#t} -gt 10 ]; then
            echo $(( t / 1000 ))
        else
            echo "$t"
        fi
    else
        date +%s
    fi
}

# ── Commands ──────────────────────────────────────────────────────────────────

case "$COMMAND" in

    tab)
        find_tab
        ;;

    auth)
        TAB=$(require_tab)
        chrome_js "$(parse_win "$TAB")" "$(parse_tab "$TAB")" "
(function(){
  try {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', '/config', false);
    xhr.send();
    if (xhr.status === 401 || xhr.status === 403) {
      return 'AUTH_REQUIRED';
    }
    if (xhr.status !== 200) {
      return 'ERROR: HTTP ' + xhr.status;
    }
    return 'OK';
  } catch(e) {
    return 'ERROR: ' + e.message;
  }
})()"
        ;;

    org)
        TAB=$(require_tab)
        chrome_js "$(parse_win "$TAB")" "$(parse_tab "$TAB")" "
(function(){
  try {
    // Step 1: get the org UUID from /api/v2/current_user
    var xhr = new XMLHttpRequest();
    xhr.open('GET', '/api/v2/current_user', false);
    xhr.send();
    if (xhr.status === 401 || xhr.status === 403) return 'AUTH_REQUIRED';
    if (xhr.status !== 200) return 'ERROR: current_user HTTP ' + xhr.status;
    var user = JSON.parse(xhr.responseText);
    var orgId = user.data.relationships.org.data.id;
    // Step 2: get org details by UUID
    var xhr2 = new XMLHttpRequest();
    xhr2.open('GET', '/api/v1/org/' + orgId, false);
    xhr2.send();
    if (xhr2.status !== 200) return 'ERROR: org HTTP ' + xhr2.status;
    var d = JSON.parse(xhr2.responseText);
    var org = d.org || d;
    return 'org_id:' + (org.public_id || orgId) + ' | name:' + (org.name || 'unknown');
  } catch(e) { return 'ERROR: ' + e.message; }
})()"
        ;;

    spans)
        QUERY="${1:?Usage: support-admin-api.sh spans <query> [from] [to]}"
        FROM_RAW="${2:-now-1h}"
        TO_RAW="${3:-now}"
        FROM_S=$(parse_time "$FROM_RAW")
        TO_S=$(parse_time "$TO_RAW")
        # support-admin only allows GET — use query-string params for /api/v2/spans/events
        FROM_ISO=$(python3 -c "from datetime import datetime,timezone; print(datetime.fromtimestamp(${FROM_S},tz=timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))")
        TO_ISO=$(python3 -c "from datetime import datetime,timezone; print(datetime.fromtimestamp(${TO_S},tz=timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))")
        QUERY_JSON=$(printf '%s' "$QUERY" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

        TAB=$(require_tab)
        TMPJS=$(mktemp /tmp/sa-spans-XXXXXXXX)
        cat > "$TMPJS" << 'JSEOF'
(function(){
  try {
    var query = __QUERY_JSON__;
    var url = '/api/v2/spans/events?filter[query]=' + encodeURIComponent(query)
      + '&filter[from]=__FROM_ISO__'
      + '&filter[to]=__TO_ISO__'
      + '&sort=-timestamp&page[limit]=50';
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, false);
    xhr.send();
    if (xhr.status === 401 || xhr.status === 403) return 'AUTH_REQUIRED';
    if (xhr.status !== 200) return 'ERROR: HTTP ' + xhr.status + ' ' + xhr.responseText.substring(0, 200);
    var resp = JSON.parse(xhr.responseText);
    var spans = (resp.data || []);
    if (spans.length === 0) {
      return '<METADATA>\n  <count>0</count>\n</METADATA>\n<YAML_DATA>\n</YAML_DATA>';
    }
    var result = '<METADATA>\n  <count>' + spans.length + '</count>\n</METADATA>\n<YAML_DATA>\n';
    for (var i = 0; i < spans.length; i++) {
      var s = spans[i].attributes || spans[i];
      result += '- trace_id: ' + (s.trace_id || '') + '\n';
      result += '  span_id: ' + (s.span_id || spans[i].id || '') + '\n';
      result += '  service: ' + (s.service || '') + '\n';
      result += '  resource_name: ' + (s.resource_name || '') + '\n';
      result += '  name: ' + (s.name || '') + '\n';
      result += '  type: ' + (s.type || '') + '\n';
      result += '  duration: ' + (s.duration || 0) + '\n';
      result += '  start: ' + (s.start || s.timestamp || '') + '\n';
      result += '  status: ' + ((s.status || '') === 'error' ? 'error' : 'ok') + '\n';
      if (s.meta || s.attributes) {
        var meta = s.meta || s.attributes || {};
        var keys = Object.keys(meta);
        if (keys.length > 0) {
          result += '  meta:\n';
          for (var k = 0; k < keys.length; k++) {
            if (typeof meta[keys[k]] === 'string' || typeof meta[keys[k]] === 'number') {
              result += '    ' + keys[k] + ': ' + String(meta[keys[k]]).substring(0, 500) + '\n';
            }
          }
        }
      }
    }
    result += '</YAML_DATA>';
    return result;
  } catch(e) { return 'ERROR: ' + e.message; }
})()
JSEOF
        # Inject shell variables into the JS file via sed (heredoc is quoted, no shell expansion)
        sed -i '' "s|__QUERY_JSON__|${QUERY_JSON}|g" "$TMPJS"
        sed -i '' "s|__FROM_ISO__|${FROM_ISO}|g" "$TMPJS"
        sed -i '' "s|__TO_ISO__|${TO_ISO}|g" "$TMPJS"
        chrome_js_file "$(parse_win "$TAB")" "$(parse_tab "$TAB")" "$TMPJS"
        rm -f "$TMPJS"
        ;;

    trace)
        # Fetch all spans for a given trace ID via GET /api/v2/spans/events
        TRACE_ID="${1:?Usage: support-admin-api.sh trace <trace_id>}"
        SAFE_TRACE_ID=$(printf '%s' "$TRACE_ID" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
        TAB=$(require_tab)
        TMPJS=$(mktemp /tmp/sa-trace-XXXXXXXX)
        cat > "$TMPJS" << 'JSEOF'
(function(){
  try {
    var traceId = __TRACE_ID_JSON__;
    /* Search spans belonging to this trace - 15-min window by default; if no results, widen to 1h, then 24h */
    var windows = [900000, 3600000, 86400000];
    var spans = [];
    for (var w = 0; w < windows.length; w++) {
      var from = new Date(Date.now() - windows[w]).toISOString();
      var to = new Date().toISOString();
      var url = '/api/v2/spans/events?filter[query]=trace_id:' + encodeURIComponent(traceId)
        + '&filter[from]=' + encodeURIComponent(from)
        + '&filter[to]=' + encodeURIComponent(to)
        + '&sort=-timestamp&page[limit]=100';
      var xhr = new XMLHttpRequest();
      xhr.open('GET', url, false);
      xhr.send();
      if (xhr.status === 401 || xhr.status === 403) return 'AUTH_REQUIRED';
      if (xhr.status !== 200) return 'ERROR: HTTP ' + xhr.status + ' ' + xhr.responseText.substring(0, 200);
      var resp = JSON.parse(xhr.responseText);
      spans = resp.data || [];
      if (spans.length > 0) break;
    }
    if (spans.length === 0) {
      return '<METADATA>\n  <trace_id>' + traceId + '</trace_id>\n  <span_count>0</span_count>\n  <note>No spans found. Trace may have expired or be outside 24h retention.</note>\n</METADATA>\n<YAML_DATA>\n</YAML_DATA>';
    }
    var result = '<METADATA>\n  <trace_id>' + traceId + '</trace_id>\n  <span_count>' + spans.length + '</span_count>\n</METADATA>\n<YAML_DATA>\n';
    for (var i = 0; i < spans.length; i++) {
      var s = spans[i].attributes || spans[i];
      result += '- span_id: ' + (s.span_id || spans[i].id || '') + '\n';
      result += '  parent_id: ' + (s.parent_id || '') + '\n';
      result += '  service: ' + (s.service || '') + '\n';
      result += '  name: ' + (s.name || '') + '\n';
      result += '  resource: ' + (s.resource_name || s.resource || '') + '\n';
      result += '  type: ' + (s.type || '') + '\n';
      result += '  duration: ' + (s.duration || 0) + '\n';
      result += '  start: ' + (s.start || s.timestamp || '') + '\n';
      result += '  status: ' + ((s.status || s.error) === 'error' || s.error === 1 ? 'error' : 'ok') + '\n';
      if (s.meta) {
        var keys = Object.keys(s.meta);
        if (keys.length > 0) {
          result += '  meta:\n';
          for (var k = 0; k < keys.length; k++) {
            result += '    ' + keys[k] + ': ' + String(s.meta[keys[k]]).substring(0, 500) + '\n';
          }
        }
      }
      if (s.metrics) {
        var mkeys = Object.keys(s.metrics);
        if (mkeys.length > 0) {
          result += '  metrics:\n';
          for (var m = 0; m < mkeys.length; m++) {
            result += '    ' + mkeys[m] + ': ' + s.metrics[mkeys[m]] + '\n';
          }
        }
      }
    }
    result += '</YAML_DATA>';
    return result;
  } catch(e) { return 'ERROR: ' + e.message; }
})()
JSEOF
        sed -i '' "s|__TRACE_ID_JSON__|${SAFE_TRACE_ID}|g" "$TMPJS"
        chrome_js_file "$(parse_win "$TAB")" "$(parse_tab "$TAB")" "$TMPJS"
        rm -f "$TMPJS"
        ;;

    services)
        QUERY="${1:-}"
        QUERY_JSON=$(printf '%s' "${QUERY:-}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
        TAB=$(require_tab)
        TMPJS=$(mktemp /tmp/sa-svc-XXXXXXXX)
        cat > "$TMPJS" << 'JSEOF'
(function(){
  try {
    var url = '/api/v2/services/definitions';
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, false);
    xhr.send();
    if (xhr.status === 401 || xhr.status === 403) return 'AUTH_REQUIRED';
    if (xhr.status !== 200) {
      xhr = new XMLHttpRequest();
      xhr.open('GET', '/api/v1/services', false);
      xhr.send();
      if (xhr.status !== 200) return 'ERROR: HTTP ' + xhr.status;
    }
    var resp = JSON.parse(xhr.responseText);
    var services = resp.data || resp || [];
    if (!Array.isArray(services)) services = Object.keys(services).map(function(k){ return {name:k, type:services[k]}; });
    var query = __QUERY_JSON__.toLowerCase();
    if (query) {
      services = services.filter(function(s){
        var name = (s.attributes && s.attributes.schema && s.attributes.schema['dd-service']) || s.name || s.id || '';
        return name.toLowerCase().indexOf(query) !== -1;
      });
    }
    if (services.length === 0) {
      return '<METADATA>\n  <message>No services found.</message>\n</METADATA>\n<TSV_DATA>\n</TSV_DATA>';
    }
    var result = '<METADATA>\n  <count>' + services.length + '</count>\n</METADATA>\n<TSV_DATA>\nservice\ttype\tteam\tdescription\n';
    for (var i = 0; i < services.length; i++) {
      var s = services[i];
      var attr = s.attributes || s;
      var schema = attr.schema || attr;
      var name = schema['dd-service'] || s.name || s.id || '';
      var type = schema['dd-type'] || attr.type || '';
      var team = schema['dd-team'] || (attr.contacts && attr.contacts[0] && attr.contacts[0].name) || '';
      var desc = (schema.description || '').substring(0, 200).replace(/\t/g, ' ').replace(/\n/g, ' ');
      result += name + '\t' + type + '\t' + team + '\t' + desc + '\n';
    }
    result += '</TSV_DATA>';
    return result;
  } catch(e) { return 'ERROR: ' + e.message; }
})()
JSEOF
        sed -i '' "s|__QUERY_JSON__|${QUERY_JSON}|g" "$TMPJS"
        chrome_js_file "$(parse_win "$TAB")" "$(parse_tab "$TAB")" "$TMPJS"
        rm -f "$TMPJS"
        ;;

    logs)
        # NOTE: Support-admin blocks POST requests and the logs search API
        # (v2/logs/events/search) requires POST. The v2/logs/events GET
        # endpoint also returns 401. Only log indexes (GET) work.
        QUERY="${1:?Usage: support-admin-api.sh logs <query> [from] [to]}"
        FROM_RAW="${2:-now-1h}"
        TO_RAW="${3:-now}"
        FROM_S=$(parse_time "$FROM_RAW")
        TO_S=$(parse_time "$TO_RAW")
        FROM_ISO=$(python3 -c "from datetime import datetime,timezone; print(datetime.fromtimestamp(${FROM_S},tz=timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))")
        TO_ISO=$(python3 -c "from datetime import datetime,timezone; print(datetime.fromtimestamp(${TO_S},tz=timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))")
        QUERY_JSON=$(printf '%s' "$QUERY" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

        TAB=$(require_tab)
        TMPJS=$(mktemp /tmp/sa-logs-XXXXXXXX)
        cat > "$TMPJS" << 'JSEOF'
(function(){
  try {
    var query = __QUERY_JSON__;
    var from_iso = '__FROM_ISO__';
    var to_iso = '__TO_ISO__';
    var url = '/api/v2/logs/events?filter[query]=' + encodeURIComponent(query)
      + '&filter[from]=' + encodeURIComponent(from_iso)
      + '&filter[to]=' + encodeURIComponent(to_iso)
      + '&sort=-timestamp&page[limit]=50';
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, false);
    xhr.send();
    if (xhr.status === 200) {
      var resp = JSON.parse(xhr.responseText);
      var logs = resp.data || [];
      if (logs.length === 0) {
        return '<METADATA>\n  <displayed_items>0</displayed_items>\n  <count>0</count>\n</METADATA>\n<TSV_DATA>\n</TSV_DATA>';
      }
      var result = '<METADATA>\n  <displayed_items>' + logs.length + '</displayed_items>\n  <count>' + logs.length + '</count>\n</METADATA>\n<TSV_DATA>\ntimestamp\thost\tservice\tstatus\tmessage\n';
      for (var i = 0; i < logs.length; i++) {
        var l = logs[i].attributes || logs[i];
        var ts = l.timestamp || '';
        var host = l.host || '';
        var svc = l.service || '';
        var status = l.status || '';
        var msg = (l.message || '').substring(0, 1000).replace(/\t/g, ' ').replace(/\n/g, ' ');
        result += ts + '\t' + host + '\t' + svc + '\t' + status + '\t' + msg + '\n';
      }
      result += '</TSV_DATA>';
      return result;
    }
    /* Logs search blocked on support-admin - return diagnostic info */
    var xhr2 = new XMLHttpRequest();
    xhr2.open('GET', '/api/v1/logs/indexes', false);
    xhr2.send();
    var indexes = [];
    if (xhr2.status === 200) {
      var idxResp = JSON.parse(xhr2.responseText);
      indexes = (idxResp.indexes || []).map(function(idx){ return idx.name; });
    }
    return 'NOT_AVAILABLE: Logs search requires POST which support-admin blocks (HTTP 401).\n'
      + 'Use the Datadog MCP logs tools or navigate to Logs Explorer in support-admin UI.\n'
      + 'Available log indexes: ' + (indexes.length > 0 ? indexes.join(', ') : 'unknown');
  } catch(e) { return 'ERROR: ' + e.message; }
})()
JSEOF
        sed -i '' "s|__QUERY_JSON__|${QUERY_JSON}|g" "$TMPJS"
        sed -i '' "s|__FROM_ISO__|${FROM_ISO}|g" "$TMPJS"
        sed -i '' "s|__TO_ISO__|${TO_ISO}|g" "$TMPJS"
        chrome_js_file "$(parse_win "$TAB")" "$(parse_tab "$TAB")" "$TMPJS"
        rm -f "$TMPJS"
        ;;

    metrics)
        QUERY="${1:?Usage: support-admin-api.sh metrics <query> [from] [to]}"
        FROM_RAW="${2:-now-1h}"
        TO_RAW="${3:-now}"
        FROM_S=$(parse_time "$FROM_RAW")
        TO_S=$(parse_time "$TO_RAW")
        QUERY_JSON=$(printf '%s' "$QUERY" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

        TAB=$(require_tab)
        TMPJS=$(mktemp /tmp/sa-metrics-XXXXXXXX)
        cat > "$TMPJS" << 'JSEOF'
(function(){
  try {
    var q = __QUERY_JSON__;
    var url = '/api/v1/query?from=__FROM_S__&to=__TO_S__&query=' + encodeURIComponent(q);
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, false);
    xhr.send();
    if (xhr.status === 401 || xhr.status === 403) return 'AUTH_REQUIRED';
    if (xhr.status !== 200) return 'ERROR: HTTP ' + xhr.status;
    var d = JSON.parse(xhr.responseText);
    var series = d.series || [];
    if (series.length === 0) {
      return '<METADATA>\n  <message>No data returned.</message>\n</METADATA>\n<JSON_DATA>\n[]\n</JSON_DATA>';
    }
    var out = [];
    for (var si = 0; si < series.length; si++) {
      var s = series[si];
      var pts = s.pointlist || [];
      var vals = pts.map(function(p){ return p[1]; }).filter(function(v){ return v !== null; });
      var mn = vals.length ? Math.min.apply(null, vals) : 0;
      var mx = vals.length ? Math.max.apply(null, vals) : 0;
      var sm = vals.reduce(function(a,b){ return a+b; }, 0);
      var avg = vals.length ? sm / vals.length : 0;
      out.push({
        expression: s.expression || q,
        scope: s.scope || '*',
        unit: (s.unit && s.unit[0] && s.unit[0].name) || '',
        time_range: [new Date(pts[0][0]).toISOString(), new Date(pts[pts.length-1][0]).toISOString()],
        overall_stats: { count: pts.length, min: mn, max: mx, avg: avg, sum: sm },
        pointlist_length: pts.length,
        last_value: pts.length ? pts[pts.length-1][1] : null
      });
    }
    return '<METADATA>\n  <series_count>' + out.length + '</series_count>\n</METADATA>\n<JSON_DATA>\n' + JSON.stringify(out) + '\n</JSON_DATA>';
  } catch(e) { return 'ERROR: ' + e.message; }
})()
JSEOF
        sed -i '' "s|__QUERY_JSON__|${QUERY_JSON}|g" "$TMPJS"
        sed -i '' "s|__FROM_S__|${FROM_S}|g" "$TMPJS"
        sed -i '' "s|__TO_S__|${TO_S}|g" "$TMPJS"
        chrome_js_file "$(parse_win "$TAB")" "$(parse_tab "$TAB")" "$TMPJS"
        rm -f "$TMPJS"
        ;;

    hosts)
        FILTER="${1:-}"
        FILTER_JSON=$(printf '%s' "${FILTER:-}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
        TAB=$(require_tab)
        TMPJS=$(mktemp /tmp/sa-hosts-XXXXXXXX)
        cat > "$TMPJS" << 'JSEOF'
(function(){
  try {
    var url = '/api/v1/hosts?count=100';
    var filter = __FILTER_JSON__;
    if (filter) url += '&filter=' + encodeURIComponent(filter);
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, false);
    xhr.send();
    if (xhr.status === 401 || xhr.status === 403) return 'AUTH_REQUIRED';
    if (xhr.status !== 200) return 'ERROR: HTTP ' + xhr.status;
    var resp = JSON.parse(xhr.responseText);
    var hosts = resp.host_list || resp.hosts || [];
    var total = resp.total_matching || resp.total_returned || hosts.length;
    if (hosts.length === 0) {
      return '<METADATA>\n  <displayed_rows>0</displayed_rows>\n  <total_rows>0</total_rows>\n</METADATA>\n<TSV_DATA>\nhostname\tcloud_provider\tos\tinstance_type\tagent_version\n</TSV_DATA>';
    }
    var result = '<METADATA>\n  <displayed_rows>' + hosts.length + '</displayed_rows>\n  <total_rows>' + total + '</total_rows>\n</METADATA>\n<TSV_DATA>\nhostname\tcloud_provider\tos\tinstance_type\tagent_version\n';
    for (var i = 0; i < hosts.length; i++) {
      var h = hosts[i];
      var name = h.host_name || h.name || '';
      var cloud = (h.meta && h.meta.cloud_provider) || '';
      var os = (h.meta && (h.meta.os || h.meta.platform)) || '';
      var inst = (h.meta && h.meta.instance_type) || '';
      var agent = (h.meta && h.meta.agent_version) || '';
      result += name + '\t' + cloud + '\t' + os + '\t' + inst + '\t' + agent + '\n';
    }
    result += '</TSV_DATA>';
    return result;
  } catch(e) { return 'ERROR: ' + e.message; }
})()
JSEOF
        sed -i '' "s|__FILTER_JSON__|${FILTER_JSON}|g" "$TMPJS"
        chrome_js_file "$(parse_win "$TAB")" "$(parse_tab "$TAB")" "$TMPJS"
        rm -f "$TMPJS"
        ;;

    monitors)
        QUERY="${1:-}"
        QUERY_JSON=$(printf '%s' "${QUERY:-}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
        TAB=$(require_tab)
        TMPJS=$(mktemp /tmp/sa-mon-XXXXXXXX)
        cat > "$TMPJS" << 'JSEOF'
(function(){
  try {
    var url = '/api/v1/monitor';
    var query = __QUERY_JSON__;
    if (query) url += '?query=' + encodeURIComponent(query);
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, false);
    xhr.send();
    if (xhr.status === 401 || xhr.status === 403) return 'AUTH_REQUIRED';
    if (xhr.status !== 200) return 'ERROR: HTTP ' + xhr.status;
    var monitors = JSON.parse(xhr.responseText);
    if (!Array.isArray(monitors)) monitors = monitors.monitors || [monitors];
    if (monitors.length === 0) {
      return '<METADATA>\n  <count>0</count>\n</METADATA>\n[]';
    }
    var out = monitors.map(function(m){
      return {
        id: m.id,
        name: m.name || '',
        message: (m.message || '').substring(0, 500),
        type: m.type || '',
        status: (m.overall_state || ''),
        query: m.query || '',
        creator: (m.creator && m.creator.name) || '',
        created_at: m.created || ''
      };
    });
    return '<METADATA>\n  <count>' + out.length + '</count>\n</METADATA>\n<JSON_DATA>\n' + JSON.stringify(out) + '\n</JSON_DATA>';
  } catch(e) { return 'ERROR: ' + e.message; }
})()
JSEOF
        sed -i '' "s|__QUERY_JSON__|${QUERY_JSON}|g" "$TMPJS"
        chrome_js_file "$(parse_win "$TAB")" "$(parse_tab "$TAB")" "$TMPJS"
        rm -f "$TMPJS"
        ;;

    help|*)
        echo "Support Admin API via Chrome JS — Datadog MCP-compatible output"
        echo ""
        echo "Usage: support-admin-api.sh <command> [args...]"
        echo ""
        echo "Commands:"
        echo "  tab                              Find Support Admin tab index"
        echo "  auth                             Verify session (OK / AUTH_REQUIRED)"
        echo "  org                              Get current org (org_id | name)"
        echo "  spans <query> [from] [to]        Search spans (APM)"
        echo "  trace <trace_id>                 Get full trace by ID"
        echo "  services [query]                 List/search services"
        echo "  logs <query> [from] [to]         Search logs"
        echo "  metrics <query> [from] [to]      Query metrics timeseries"
        echo "  hosts [filter]                   List hosts"
        echo "  monitors [query]                 List monitors"
        echo ""
        echo "Time formats: epoch seconds, 'now', 'now-1h', 'now-15m', 'now-1d'"
        echo "Output: Matches Datadog MCP format (METADATA + TSV/JSON/YAML)"
        echo ""
        echo "Requires: Chrome + Support Admin tab + JS from Apple Events enabled"
        ;;
esac
