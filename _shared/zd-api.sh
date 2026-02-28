#!/bin/bash
# Zendesk API via Chrome JS — shared helper for all skills
# Usage: zd-api.sh <command> [args...]
#
# Commands:
#   tab                        Find Zendesk tab index in Chrome
#   me                         Get current user (id | name | email)
#   ticket <ID>                Get ticket metadata (filtered to useful tags only)
#   comments <ID> [chars]      Get comments (default: 500 chars/body, pass 0 for full)
#   replied <ID>               Check if current user replied (REPLIED / NOT_REPLIED)
#   search <QUERY>             Search tickets (compact: key metadata extracted from tags)
#   attachments <ID>           List attachments (filename | size | type | url)
#   download <URL> <NAME>      Trigger Chrome download of an attachment
#   read <ID> [chars]          Combined: ticket metadata + comments in one call

set -euo pipefail

COMMAND="${1:-help}"
shift || true

ZD_API="~/.cursor/skills/_shared/zd-api.sh"

# JS snippet: filter tags to only useful ones, return as key:value pairs
# Extracts: product_type, account_type, tier, mrr, complexity, impact, spec, org, reply_count, critical, hipaa, top75
TAG_FILTER_JS="
var useful = {};
t.tags.forEach(function(tag) {
  if (tag.match(/^pt_product_type:/)) useful.product = tag.split(':')[1];
  else if (tag.match(/^account_type:/)) useful.account = tag.split(':')[1];
  else if (tag.match(/^(t0|t1|t2|t3|t4|t_not_available)$/)) useful.tier = tag;
  else if (tag.match(/^mrr_/)) useful.mrr = tag.replace('mrr_','');
  else if (tag.match(/^ticket_complexity_/)) useful.complexity = tag.replace('ticket_complexity_','');
  else if (tag.match(/^impact_/)) useful.impact = tag.replace('impact_','');
  else if (tag.match(/^spec_/)) useful.spec = tag.replace('spec_','').replace('_ticket','');
  else if (tag.match(/^org:/)) useful.org_id = tag.split(':')[1];
  else if (tag.match(/^\\\\d+_agent_replies$/)) useful.replies = tag.split('_')[0];
  else if (tag === 'critical' || tag.match(/^critical_/)) useful.critical = 'true';
  else if (tag === 'hipaa_org') useful.hipaa = 'true';
  else if (tag === 'top75org') useful.top75 = 'true';
  else if (tag.match(/^org_region_/)) useful.region = tag.replace('org_region_','');
  else if (tag.match(/^pt_dbm_category:|^pt_agent_category:|^pt_monitors_category:/)) useful.subcategory = tag.split(':')[1];
  else if (tag === 'oai_opted_out') useful.ai_optout = 'true';
});
var tagStr = '';
Object.keys(useful).forEach(function(k) { tagStr += k + ':' + useful[k] + ', '; });
tagStr.slice(0, -2);
"

find_tab() {
    osascript -e 'tell application "Google Chrome"
        set tabIndex to -1
        repeat with w in windows
            set tabCount to count of tabs of w
            repeat with i from 1 to tabCount
                if URL of tab i of w contains "zendesk.com" then
                    set tabIndex to i
                    exit repeat
                end if
            end repeat
            if tabIndex > -1 then exit repeat
        end repeat
        return tabIndex
    end tell' 2>/dev/null
}

chrome_js() {
    local tab_index="$1"
    local js_code="$2"
    osascript -e "tell application \"Google Chrome\"
        tell tab ${tab_index} of window 1
            return (execute javascript \"${js_code}\")
        end tell
    end tell" 2>/dev/null
}

require_tab() {
    local tab
    tab=$(find_tab)
    if [ "$tab" -le 0 ] 2>/dev/null; then
        echo "ERROR: No Zendesk tab found in Chrome" >&2
        exit 1
    fi
    echo "$tab"
}

case "$COMMAND" in
    tab)
        find_tab
        ;;

    me)
        TAB=$(require_tab)
        chrome_js "$TAB" "var xhr = new XMLHttpRequest(); xhr.open('GET', '/api/v2/users/me.json', false); xhr.send(); if (xhr.status === 200) { var u = JSON.parse(xhr.responseText).user; u.id + ' | ' + u.name + ' | ' + u.email; } else { 'ERROR: HTTP ' + xhr.status; }"
        ;;

    ticket)
        TICKET_ID="${1:?Usage: zd-api.sh ticket <ID>}"
        TAB=$(require_tab)
        chrome_js "$TAB" "var xhr = new XMLHttpRequest(); xhr.open('GET', '/api/v2/tickets/${TICKET_ID}.json', false); xhr.send(); if (xhr.status === 200) { var t = JSON.parse(xhr.responseText).ticket; ${TAG_FILTER_JS} 'SUBJECT: ' + t.subject + '\\\\nSTATUS: ' + t.status + '\\\\nPRIORITY: ' + (t.priority || 'none') + '\\\\nCREATED: ' + t.created_at + '\\\\nUPDATED: ' + t.updated_at + '\\\\n' + tagStr; } else { 'ERROR: HTTP ' + xhr.status; }"
        ;;

    comments)
        TICKET_ID="${1:?Usage: zd-api.sh comments <ID> [max_chars]}"
        MAX_CHARS="${2:-500}"
        TAB=$(require_tab)
        if [ "$MAX_CHARS" = "0" ]; then
            SUBSTR_JS="c.body"
        else
            SUBSTR_JS="c.body.substring(0, ${MAX_CHARS})"
        fi
        chrome_js "$TAB" "var xhr = new XMLHttpRequest(); xhr.open('GET', '/api/v2/tickets/${TICKET_ID}/comments.json', false); xhr.send(); if (xhr.status === 200) { var data = JSON.parse(xhr.responseText); var result = 'COMMENTS: ' + data.comments.length + '\\\\n'; data.comments.forEach(function(c, i) { result += '---\\\\n[' + (i+1) + '] AUTHOR:' + c.author_id + ' | ' + c.created_at + '\\\\n' + ${SUBSTR_JS} + '\\\\n'; }); result; } else { 'ERROR: HTTP ' + xhr.status; }"
        ;;

    read)
        TICKET_ID="${1:?Usage: zd-api.sh read <ID> [max_chars]}"
        MAX_CHARS="${2:-500}"
        TAB=$(require_tab)
        if [ "$MAX_CHARS" = "0" ]; then
            SUBSTR_JS="c.body"
        else
            SUBSTR_JS="c.body.substring(0, ${MAX_CHARS})"
        fi
        chrome_js "$TAB" "var xhr = new XMLHttpRequest(); xhr.open('GET', '/api/v2/tickets/${TICKET_ID}.json', false); xhr.send(); var xhr2 = new XMLHttpRequest(); xhr2.open('GET', '/api/v2/tickets/${TICKET_ID}/comments.json', false); xhr2.send(); if (xhr.status === 200 && xhr2.status === 200) { var t = JSON.parse(xhr.responseText).ticket; ${TAG_FILTER_JS} var comments = JSON.parse(xhr2.responseText).comments; var result = 'SUBJECT: ' + t.subject + '\\\\nSTATUS: ' + t.status + '\\\\nPRIORITY: ' + (t.priority || 'none') + '\\\\nCREATED: ' + t.created_at + '\\\\nUPDATED: ' + t.updated_at + '\\\\n' + tagStr + '\\\\n\\\\nCOMMENTS: ' + comments.length + '\\\\n'; comments.forEach(function(c, i) { result += '---\\\\n[' + (i+1) + '] AUTHOR:' + c.author_id + ' | ' + c.created_at + '\\\\n' + ${SUBSTR_JS} + '\\\\n'; }); result; } else { 'ERROR: ' + xhr.status + '/' + xhr2.status; }"
        ;;

    replied)
        TICKET_ID="${1:?Usage: zd-api.sh replied <ID>}"
        TAB=$(require_tab)
        chrome_js "$TAB" "var xhr_me = new XMLHttpRequest(); xhr_me.open('GET', '/api/v2/users/me.json', false); xhr_me.send(); var myId = JSON.parse(xhr_me.responseText).user.id; var xhr = new XMLHttpRequest(); xhr.open('GET', '/api/v2/tickets/${TICKET_ID}/comments.json', false); xhr.send(); if (xhr.status === 200) { var comments = JSON.parse(xhr.responseText).comments; var replied = comments.some(function(c) { return c.author_id === myId; }); replied ? 'REPLIED' : 'NOT_REPLIED'; } else { 'ERROR: HTTP ' + xhr.status; }"
        ;;

    search)
        QUERY="${1:?Usage: zd-api.sh search <QUERY>}"
        TAB=$(require_tab)
        chrome_js "$TAB" "var xhr = new XMLHttpRequest(); xhr.open('GET', '/api/v2/search.json?query=' + encodeURIComponent('${QUERY}') + '&sort_by=updated_at&sort_order=desc', false); xhr.send(); if (xhr.status === 200) { var data = JSON.parse(xhr.responseText); var result = 'TOTAL:' + data.count + '\\\\n'; data.results.forEach(function(t) { var tags = t.tags || []; var product = ''; var tier = ''; var complexity = ''; var replies = ''; var critical = ''; tags.forEach(function(tag) { if (tag.match(/^pt_product_type:/)) product = tag.split(':')[1]; else if (tag.match(/^(t0|t1|t2|t3|t4|t_not_available)$/)) tier = tag; else if (tag.match(/^ticket_complexity_/)) complexity = tag.replace('ticket_complexity_',''); else if (tag.match(/^\\\\d+_agent_replies$/)) replies = tag.split('_')[0]; else if (tag === 'critical') critical = 'CRIT'; }); result += t.id + ' | ' + t.status + ' | ' + (t.priority || 'none') + ' | ' + product + ' | ' + tier + ' | ' + complexity + ' | ' + (replies ? replies+'r' : '') + ' | ' + (critical ? critical+' | ' : '') + t.updated_at.substring(0,16) + ' | ' + t.subject + '\\\\n'; }); result; } else { 'ERROR: HTTP ' + xhr.status; }"
        ;;

    attachments)
        TICKET_ID="${1:?Usage: zd-api.sh attachments <ID>}"
        TAB=$(require_tab)
        chrome_js "$TAB" "var xhr = new XMLHttpRequest(); xhr.open('GET', '/api/v2/tickets/${TICKET_ID}/comments.json', false); xhr.send(); if (xhr.status === 200) { var data = JSON.parse(xhr.responseText); var attachments = []; data.comments.forEach(function(c) { if (c.attachments) { c.attachments.forEach(function(a) { attachments.push(a.file_name + ' | ' + Math.round(a.size/1024/1024*100)/100 + ' MB | ' + a.content_type + ' | ' + a.content_url); }); } }); attachments.length > 0 ? attachments.join('\\\\n') : 'NO_ATTACHMENTS'; } else { 'ERROR: HTTP ' + xhr.status; }"
        ;;

    download)
        URL="${1:?Usage: zd-api.sh download <URL> <FILENAME>}"
        FILENAME="${2:?Usage: zd-api.sh download <URL> <FILENAME>}"
        TAB=$(require_tab)
        chrome_js "$TAB" "var a=document.createElement('a');a.href='${URL}';a.download='${FILENAME}';document.body.appendChild(a);a.click();document.body.removeChild(a);'Download triggered: ${FILENAME}'"
        ;;

    help|*)
        echo "Zendesk API via Chrome JS — token-optimized"
        echo ""
        echo "Usage: zd-api.sh <command> [args...]"
        echo ""
        echo "Commands:"
        echo "  tab                        Find Zendesk tab index"
        echo "  me                         Get current user"
        echo "  ticket <ID>                Metadata + filtered tags"
        echo "  comments <ID> [chars]      Comments (default 500 chars, 0=full)"
        echo "  read <ID> [chars]          Combined ticket+comments (one call)"
        echo "  replied <ID>               Check if current user replied"
        echo "  search <QUERY>             Search with extracted metadata"
        echo "  attachments <ID>           List attachments"
        echo "  download <URL> <NAME>      Download attachment"
        echo ""
        echo "Tag filtering: only product, account, tier, mrr, complexity,"
        echo "impact, spec, org, replies, critical, hipaa, top75, region"
        echo ""
        echo "Requires: Chrome + Zendesk tab + JS from Apple Events enabled"
        ;;
esac
