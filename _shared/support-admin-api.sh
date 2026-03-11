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
#   metrics-gaps <query> [from] [to] Check for missing datapoints (raw pointlist)
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
        var team = '';
        if (s.attributes && s.attributes.schema) team = s.attributes.schema['dd-team'] || '';
        return name.toLowerCase().indexOf(query) !== -1 || team.toLowerCase().indexOf(query) !== -1;
      });
    }
    if (services.length === 0) {
      return '<METADATA>\n  <message>No services found.</message>\n</METADATA>\n<YAML_DATA>\n</YAML_DATA>';
    }
    var result = '<METADATA>\n  <count>' + services.length + '</count>\n</METADATA>\n<YAML_DATA>\n';
    for (var i = 0; i < services.length; i++) {
      var s = services[i];
      var attr = s.attributes || s;
      var schema = attr.schema || attr;
      var name = schema['dd-service'] || s.name || s.id || '';
      var type = schema['dd-type'] || attr.type || '';
      var team = schema['dd-team'] || '';
      var desc = (schema.description || '').substring(0, 500).replace(/\n/g, ' ');
      result += '- name: ' + name + '\n';
      result += '  type: ' + type + '\n';
      result += '  team: ' + team + '\n';
      result += '  description: ' + desc + '\n';
      /* Extract links if available */
      var links = schema.links || (attr.links) || [];
      if (links.length > 0) {
        result += '  links:\n';
        for (var l = 0; l < links.length && l < 10; l++) {
          result += '    - name: ' + (links[l].name || links[l].type || '') + '\n';
          result += '      url: ' + (links[l].url || '') + '\n';
          result += '      type: ' + (links[l].type || '') + '\n';
        }
      }
      /* Extract contacts if available */
      var contacts = schema.contacts || (attr.contacts) || [];
      if (contacts.length > 0) {
        result += '  contacts:\n';
        for (var c = 0; c < contacts.length && c < 5; c++) {
          result += '    - name: ' + (contacts[c].name || '') + '\n';
          result += '      type: ' + (contacts[c].type || '') + '\n';
          result += '      contact: ' + (contacts[c].contact || '') + '\n';
        }
      }
      /* Extract tags */
      var tags = schema.tags || [];
      if (tags.length > 0) {
        result += '  tags: ' + tags.join(', ') + '\n';
      }
    }
    result += '</YAML_DATA>';
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
    /* Try GET first (works on some support-admin versions) */
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
    /* GET failed — try POST (may work if support-admin allows it) */
    var xhr2 = new XMLHttpRequest();
    xhr2.open('POST', '/api/v2/logs/events/search', false);
    xhr2.setRequestHeader('Content-Type', 'application/json');
    xhr2.send(JSON.stringify({
      filter: { query: query, from: from_iso, to: to_iso },
      sort: '-timestamp',
      page: { limit: 50 }
    }));
    if (xhr2.status === 200) {
      var resp2 = JSON.parse(xhr2.responseText);
      var logs2 = resp2.data || [];
      if (logs2.length === 0) {
        return '<METADATA>\n  <displayed_items>0</displayed_items>\n  <count>0</count>\n</METADATA>\n<TSV_DATA>\n</TSV_DATA>';
      }
      var result2 = '<METADATA>\n  <displayed_items>' + logs2.length + '</displayed_items>\n  <count>' + logs2.length + '</count>\n</METADATA>\n<TSV_DATA>\ntimestamp\thost\tservice\tstatus\tmessage\n';
      for (var j = 0; j < logs2.length; j++) {
        var l2 = logs2[j].attributes || logs2[j];
        var ts2 = l2.timestamp || '';
        var host2 = l2.host || '';
        var svc2 = l2.service || '';
        var status2 = l2.status || '';
        var msg2 = (l2.message || '').substring(0, 1000).replace(/\t/g, ' ').replace(/\n/g, ' ');
        result2 += ts2 + '\t' + host2 + '\t' + svc2 + '\t' + status2 + '\t' + msg2 + '\n';
      }
      result2 += '</TSV_DATA>';
      return result2;
    }
    /* Both failed — return diagnostic info */
    var xhr3 = new XMLHttpRequest();
    xhr3.open('GET', '/api/v1/logs/indexes', false);
    xhr3.send();
    var indexes = [];
    if (xhr3.status === 200) {
      var idxResp = JSON.parse(xhr3.responseText);
      indexes = (idxResp.indexes || []).map(function(idx){ return idx.name; });
    }
    return 'NOT_AVAILABLE: Logs search returned HTTP ' + xhr.status + ' (GET) and ' + xhr2.status + ' (POST).\nUse the Datadog MCP logs tools or navigate to Logs Explorer in support-admin UI.\nAvailable log indexes: ' + (indexes.length > 0 ? indexes.join(', ') : 'unknown');
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
      /* Create 20 time-buckets to match MCP binned output */
      var binCount = 20;
      var binSize = Math.max(1, Math.ceil(pts.length / binCount));
      var binned = [];
      for (var b = 0; b < binCount && b * binSize < pts.length; b++) {
        var start = b * binSize;
        var end = Math.min(start + binSize, pts.length);
        var binVals = [];
        for (var p = start; p < end; p++) {
          if (pts[p][1] !== null) binVals.push(pts[p][1]);
        }
        if (binVals.length > 0) {
          var bMin = Math.min.apply(null, binVals);
          var bMax = Math.max.apply(null, binVals);
          var bSum = binVals.reduce(function(a,c){ return a+c; }, 0);
          binned.push({
            start_time: new Date(pts[start][0]).toISOString(),
            count: binVals.length,
            min: bMin,
            max: bMax,
            avg: bSum / binVals.length
          });
        }
      }
      out.push({
        expression: s.expression || q,
        time_range: pts.length > 0 ? [new Date(pts[0][0]).toISOString(), new Date(pts[pts.length-1][0]).toISOString()] : [],
        overall_stats: { count: pts.length, min: mn, max: mx, avg: avg, sum: sm },
        binned: binned,
        scope: s.scope || '*',
        unit: (s.unit && s.unit[0] && s.unit[0].name) || ''
      });
    }
    return '<METADATA>\n  <metrics_explorer_url>n/a (support-admin)</metrics_explorer_url>\n</METADATA>\n<JSON_DATA>\n' + JSON.stringify(out) + '\n</JSON_DATA>';
  } catch(e) { return 'ERROR: ' + e.message; }
})()
JSEOF
        sed -i '' "s|__QUERY_JSON__|${QUERY_JSON}|g" "$TMPJS"
        sed -i '' "s|__FROM_S__|${FROM_S}|g" "$TMPJS"
        sed -i '' "s|__TO_S__|${TO_S}|g" "$TMPJS"
        chrome_js_file "$(parse_win "$TAB")" "$(parse_tab "$TAB")" "$TMPJS"
        rm -f "$TMPJS"
        ;;

    metrics-gaps)
        QUERY="${1:?Usage: support-admin-api.sh metrics-gaps <query> [from] [to]}"
        FROM_RAW="${2:-now-7d}"
        TO_RAW="${3:-now}"
        FROM_S=$(parse_time "$FROM_RAW")
        TO_S=$(parse_time "$TO_RAW")
        QUERY_JSON=$(printf '%s' "$QUERY" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

        TAB=$(require_tab)
        TMPJS=$(mktemp /tmp/sa-metrics-gaps-XXXXXXXX)
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
      return '<METADATA>\n  <message>No data returned.</message>\n</METADATA>\n<JSON_DATA>\n{"gaps":[],"null_count":0,"total_points":0}\n</JSON_DATA>';
    }
    var out = { series: [], gaps: [], null_count: 0, total_points: 0 };
    for (var si = 0; si < series.length; si++) {
      var s = series[si];
      var pts = (s.pointlist || []).slice().sort(function(a,b){ return a[0]-b[0]; });
      var total = pts.length;
      var nullCount = pts.filter(function(p){ return p[1] === null; }).length;
      var gaps = [];
      if (pts.length >= 2) {
        var deltas = [];
        for (var i = 1; i < pts.length; i++) {
          deltas.push(pts[i][0] - pts[i-1][0]);
        }
        var sorted = deltas.slice().sort(function(a,b){ return a-b; });
        var medianDelta = sorted[Math.floor(sorted.length/2)] || 0;
        var threshold = Math.max(medianDelta * 2, 60000);
        for (var j = 1; j < pts.length; j++) {
          var delta = pts[j][0] - pts[j-1][0];
          if (delta > threshold) {
            gaps.push({
              after: new Date(pts[j-1][0]).toISOString(),
              before: new Date(pts[j][0]).toISOString(),
              gap_seconds: Math.round(delta/1000),
              missing_approx: Math.round(delta / medianDelta)
            });
          }
        }
      }
      out.series.push({
        expression: s.expression || q,
        scope: s.scope || '*',
        total_points: total,
        null_count: nullCount,
        first_ts: pts.length ? new Date(pts[0][0]).toISOString() : '',
        last_ts: pts.length ? new Date(pts[pts.length-1][0]).toISOString() : '',
        gaps: gaps,
        gaps_count: gaps.length
      });
      out.total_points += total;
      out.null_count += nullCount;
      gaps.forEach(function(g){ out.gaps.push(g); });
    }
    return '<METADATA>\n  <metrics_explorer_url>n/a (support-admin)</metrics_explorer_url>\n</METADATA>\n<JSON_DATA>\n' + JSON.stringify(out, null, 2) + '\n</JSON_DATA>';
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
    var url = '/api/v1/hosts?count=100&include_hosts_metadata=true';
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
      return '<METADATA>\n  <displayed_columns>11</displayed_columns>\n  <displayed_rows>0</displayed_rows>\n  <total_rows>0</total_rows>\n</METADATA>\n<TSV_DATA>\nhostname\tcloud_provider\tresource_type\tos\tinstance_type\tagent_version\tmemory_mib\tcpu_cores\tkernel_name\tkernel_release\tsource\n</TSV_DATA>';
    }
    var result = '<METADATA>\n  <displayed_columns>11</displayed_columns>\n  <displayed_rows>' + hosts.length + '</displayed_rows>\n  <total_rows>' + total + '</total_rows>\n</METADATA>\n<TSV_DATA>\nhostname\tcloud_provider\tresource_type\tos\tinstance_type\tagent_version\tmemory_mib\tcpu_cores\tkernel_name\tkernel_release\tsource\n';
    for (var i = 0; i < hosts.length; i++) {
      var h = hosts[i];
      var name = h.host_name || h.name || '';
      var meta = h.meta || {};
      var cloud = meta.cloud_provider || '';
      var resType = cloud ? cloud + '_' + (meta.instance_type ? 'ec2_instance' : 'host') : '';
      var os = meta.os || meta.platform || '';
      var inst = meta.instance_type || '';
      var agent = meta.agent_version || '';
      var memMib = '';
      if (h.metrics && h.metrics.memory) memMib = Math.round(h.metrics.memory / 1048576);
      else if (meta.totalMemory) memMib = Math.round(meta.totalMemory);
      var cpuCores = meta.cpuCores || (meta.processor_count && meta.processor_count.toString()) || '';
      var kernelName = meta.kernel_name || (os.indexOf('Windows') !== -1 ? 'Windows' : (os.indexOf('Linux') !== -1 || os.indexOf('GNU') !== -1 ? 'Linux' : ''));
      var kernelRelease = meta.kernel_release || meta.kernel_version || '';
      var source = (h.sources && h.sources.length > 0) ? h.sources[0] : '';
      result += name + '\t' + cloud + '\t' + resType + '\t' + os + '\t' + inst + '\t' + agent + '\t' + memMib + '\t' + cpuCores + '\t' + kernelName + '\t' + kernelRelease + '\t' + source + '\n';
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
        echo "  metrics-gaps <query> [from] [to] Check for missing datapoints (raw pointlist)"
        echo "  hosts [filter]                   List hosts"
        echo "  monitors [query]                 List monitors"
        echo ""
        echo "Time formats: epoch seconds, 'now', 'now-1h', 'now-15m', 'now-1d'"
        echo "Output: Matches Datadog MCP format (METADATA + TSV/JSON/YAML)"
        echo ""
        echo "Requires: Chrome + Support Admin tab + JS from Apple Events enabled"
        ;;
esac
