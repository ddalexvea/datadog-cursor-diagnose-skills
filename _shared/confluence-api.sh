#!/bin/bash
# Confluence API via Chrome JS — shared helper for creating/updating pages
# Usage: confluence-api.sh <command> [args...]
#
# Commands:
#   tab                                    Find Confluence tab index in Chrome
#   create-page <parent_id> <title_file> <content_file>   Create child page (reads from files)
#   update-page <page_id> <content_file>  Update existing page content (reads markdown from file)
#   get-page <page_id>                    Get page content

set -euo pipefail

COMMAND="${1:-help}"
shift || true

CONFLUENCE_URL="datadoghq.atlassian.net/wiki"

find_tab() {
    osascript -e 'tell application "Google Chrome"
        set winIndex to -1
        set tabIndex to -1
        set wIdx to 0
        repeat with w in windows
            set wIdx to wIdx + 1
            set tabCount to count of tabs of w
            repeat with i from 1 to tabCount
                if URL of tab i of w contains "atlassian.net/wiki" then
                    set winIndex to wIdx
                    set tabIndex to i
                    exit repeat
                end if
            end repeat
            if tabIndex > -1 then exit repeat
        end repeat
        return (winIndex as text) & ":" & (tabIndex as text)
    end tell' 2>/dev/null
}

chrome_js() {
    local win_index="$1"
    local tab_index="$2"
    local js_code="$3"
    osascript -e "tell application \"Google Chrome\"
        tell tab ${tab_index} of window ${win_index}
            return (execute javascript \"${js_code}\")
        end tell
    end tell" 2>/dev/null
}

require_tab() {
    local result
    result=$(find_tab)
    local win_index="${result%%:*}"
    local tab_index="${result##*:}"
    if [ "$win_index" -le 0 ] 2>/dev/null || [ "$tab_index" -le 0 ] 2>/dev/null; then
        echo "ERROR: No Confluence tab found in Chrome. Please open https://${CONFLUENCE_URL} in Chrome." >&2
        exit 1
    fi
    echo "$win_index:$tab_index"
}

parse_win() { echo "${1%%:*}"; }
parse_tab() { echo "${1##*:}"; }

case "$COMMAND" in
    tab)
        find_tab
        ;;
    
    create-page)
        PARENT_ID="${1:-}"
        TITLE_FILE="${2:-}"
        CONTENT_FILE="${3:-}"
        
        if [ -z "$PARENT_ID" ] || [ -z "$TITLE_FILE" ] || [ -z "$CONTENT_FILE" ]; then
            echo "Usage: confluence-api.sh create-page <parent_id> <title_file> <content_file>" >&2
            echo "  title_file:   path to file containing the page title" >&2
            echo "  content_file: path to file containing the page content (markdown)" >&2
            exit 1
        fi
        
        if [ ! -f "$TITLE_FILE" ] || [ ! -f "$CONTENT_FILE" ]; then
            echo "ERROR: Title or content file not found" >&2
            exit 1
        fi
        
        TAB=$(require_tab)
        WIN=$(parse_win "$TAB")
        TIDX=$(parse_tab "$TAB")
        
        # Use node to JSON-encode title+content, then base64 for safe transport
        # through shell → osascript → AppleScript → Chrome JS (zero escaping issues)
        B64_PAYLOAD=$(node -e "
            var fs = require('fs');
            var title = fs.readFileSync('${TITLE_FILE}', 'utf8').trim();
            var md = fs.readFileSync('${CONTENT_FILE}', 'utf8').trim();

            var lines = md.split('\n');
            var html = '';
            var inCodeBlock = false;
            var inList = false;
            var listType = '';

            for (var i = 0; i < lines.length; i++) {
                var line = lines[i];
                if (line.match(/^\`\`\`/)) {
                    if (inCodeBlock) {
                        html += ']]></ac:plain-text-body></ac:structured-macro>';
                        inCodeBlock = false;
                    } else {
                        if (inList) { html += '</' + listType + '>'; inList = false; }
                        var lang = line.replace(/\`\`\`/, '').trim() || 'text';
                        html += '<ac:structured-macro ac:name=\"code\"><ac:parameter ac:name=\"language\">' + lang + '</ac:parameter><ac:plain-text-body><![CDATA[';
                        inCodeBlock = true;
                    }
                    continue;
                }
                if (inCodeBlock) { html += line + '\n'; continue; }
                if (line.trim() === '') {
                    if (inList) { html += '</' + listType + '>'; inList = false; }
                    continue;
                }
                var hMatch = line.match(/^(#{1,6})\s+(.*)/);
                if (hMatch) {
                    if (inList) { html += '</' + listType + '>'; inList = false; }
                    var level = hMatch[1].length;
                    html += '<h' + level + '>' + fmt(hMatch[2]) + '</h' + level + '>';
                    continue;
                }
                if (line.match(/^\s*[-*]\s+/)) {
                    var content = line.replace(/^\s*[-*]\s+/, '');
                    if (!inList || listType !== 'ul') {
                        if (inList) html += '</' + listType + '>';
                        html += '<ul>'; inList = true; listType = 'ul';
                    }
                    html += '<li>' + fmt(content) + '</li>';
                    continue;
                }
                var olMatch = line.match(/^\s*(\d+)[.)]\s+(.*)/);
                if (olMatch) {
                    if (!inList || listType !== 'ol') {
                        if (inList) html += '</' + listType + '>';
                        html += '<ol>'; inList = true; listType = 'ol';
                    }
                    html += '<li>' + fmt(olMatch[2]) + '</li>';
                    continue;
                }
                if (inList) { html += '</' + listType + '>'; inList = false; }
                html += '<p>' + fmt(line) + '</p>';
            }
            if (inList) html += '</' + listType + '>';

            function fmt(s) {
                s = s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
                s = s.replace(/\`([^\`]+)\`/g, '<code>\$1</code>');
                s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>\$1</strong>');
                s = s.replace(/_([^_]+)_/g, '<em>\$1</em>');
                return s;
            }

            process.stdout.write(Buffer.from(JSON.stringify({ title: title, html: html })).toString('base64'));
        ")
        
        if [ -z "$B64_PAYLOAD" ]; then
            echo "ERROR: Failed to encode content" >&2
            exit 1
        fi
        
        chrome_js "$WIN" "$TIDX" "var b64 = '${B64_PAYLOAD}'; var bytes = Uint8Array.from(atob(b64), function(c) { return c.charCodeAt(0); }); var decoded = new TextDecoder('utf-8').decode(bytes); var data = JSON.parse(decoded); var xhr = new XMLHttpRequest(); xhr.open('GET', '/wiki/api/v2/pages/${PARENT_ID}', false); xhr.send(); if (xhr.status !== 200) { 'ERROR: GET parent ' + xhr.status; } else { var parent = JSON.parse(xhr.responseText); var spaceId = parent.spaceId; var payload = JSON.stringify({ spaceId: spaceId, status: 'current', title: data.title, parentId: '${PARENT_ID}', body: { representation: 'storage', value: data.html } }); var xhr2 = new XMLHttpRequest(); xhr2.open('POST', '/wiki/api/v2/pages', false); xhr2.setRequestHeader('Content-Type', 'application/json'); xhr2.setRequestHeader('Accept', 'application/json'); xhr2.send(payload); if (xhr2.status >= 200 && xhr2.status < 300) { var result = JSON.parse(xhr2.responseText); var xp = new XMLHttpRequest(); xp.open('POST', '/wiki/rest/api/content/' + result.id + '/property', false); xp.setRequestHeader('Content-Type', 'application/json'); xp.send(JSON.stringify({key:'content-appearance-published',value:{appearance:'full-width'},version:{number:1}})); 'CREATED: ' + result.id + ' | ' + (result._links ? result._links.webui : ''); } else { 'ERROR: POST ' + xhr2.status + ' ' + xhr2.responseText.substring(0, 200); } }"
        ;;
    
    update-page)
        PAGE_ID="${1:-}"
        CONTENT_FILE="${2:-}"
        
        if [ -z "$PAGE_ID" ] || [ -z "$CONTENT_FILE" ]; then
            echo "Usage: confluence-api.sh update-page <page_id> <content_file>" >&2
            echo "  content_file: path to file containing the page content (markdown)" >&2
            exit 1
        fi
        
        if [ ! -f "$CONTENT_FILE" ]; then
            echo "ERROR: Content file not found: $CONTENT_FILE" >&2
            exit 1
        fi
        
        TAB=$(require_tab)
        WIN=$(parse_win "$TAB")
        TIDX=$(parse_tab "$TAB")
        
        B64_PAYLOAD=$(node -e "
            var fs = require('fs');
            var md = fs.readFileSync('${CONTENT_FILE}', 'utf8').trim();

            var lines = md.split('\n');
            var html = '';
            var inCodeBlock = false;
            var inList = false;
            var listType = '';

            for (var i = 0; i < lines.length; i++) {
                var line = lines[i];
                if (line.match(/^\`\`\`/)) {
                    if (inCodeBlock) {
                        html += ']]></ac:plain-text-body></ac:structured-macro>';
                        inCodeBlock = false;
                    } else {
                        if (inList) { html += '</' + listType + '>'; inList = false; }
                        var lang = line.replace(/\`\`\`/, '').trim() || 'text';
                        html += '<ac:structured-macro ac:name=\"code\"><ac:parameter ac:name=\"language\">' + lang + '</ac:parameter><ac:plain-text-body><![CDATA[';
                        inCodeBlock = true;
                    }
                    continue;
                }
                if (inCodeBlock) { html += line + '\n'; continue; }
                if (line.trim() === '') {
                    if (inList) { html += '</' + listType + '>'; inList = false; }
                    continue;
                }
                var hMatch = line.match(/^(#{1,6})\s+(.*)/);
                if (hMatch) {
                    if (inList) { html += '</' + listType + '>'; inList = false; }
                    var level = hMatch[1].length;
                    html += '<h' + level + '>' + fmt(hMatch[2]) + '</h' + level + '>';
                    continue;
                }
                if (line.match(/^\s*[-*]\s+/)) {
                    var content = line.replace(/^\s*[-*]\s+/, '');
                    if (!inList || listType !== 'ul') {
                        if (inList) html += '</' + listType + '>';
                        html += '<ul>'; inList = true; listType = 'ul';
                    }
                    html += '<li>' + fmt(content) + '</li>';
                    continue;
                }
                var olMatch = line.match(/^\s*(\d+)[.)]\s+(.*)/);
                if (olMatch) {
                    if (!inList || listType !== 'ol') {
                        if (inList) html += '</' + listType + '>';
                        html += '<ol>'; inList = true; listType = 'ol';
                    }
                    html += '<li>' + fmt(olMatch[2]) + '</li>';
                    continue;
                }
                if (inList) { html += '</' + listType + '>'; inList = false; }
                html += '<p>' + fmt(line) + '</p>';
            }
            if (inList) html += '</' + listType + '>';

            function fmt(s) {
                s = s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
                s = s.replace(/\`([^\`]+)\`/g, '<code>\$1</code>');
                s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>\$1</strong>');
                s = s.replace(/_([^_]+)_/g, '<em>\$1</em>');
                return s;
            }

            process.stdout.write(Buffer.from(JSON.stringify({ html: html })).toString('base64'));
        ")
        
        if [ -z "$B64_PAYLOAD" ]; then
            echo "ERROR: Failed to encode content" >&2
            exit 1
        fi
        
        chrome_js "$WIN" "$TIDX" "var b64 = '${B64_PAYLOAD}'; var bytes = Uint8Array.from(atob(b64), function(c) { return c.charCodeAt(0); }); var decoded = new TextDecoder('utf-8').decode(bytes); var data = JSON.parse(decoded); var xhr = new XMLHttpRequest(); xhr.open('GET', '/wiki/api/v2/pages/${PAGE_ID}', false); xhr.send(); if (xhr.status !== 200) { 'ERROR: GET ' + xhr.status; } else { var current = JSON.parse(xhr.responseText); var payload = JSON.stringify({ id: '${PAGE_ID}', status: 'current', title: current.title, body: { representation: 'storage', value: data.html }, version: { number: current.version.number + 1, message: 'Updated via automation' } }); var xhr2 = new XMLHttpRequest(); xhr2.open('PUT', '/wiki/api/v2/pages/${PAGE_ID}', false); xhr2.setRequestHeader('Content-Type', 'application/json'); xhr2.setRequestHeader('Accept', 'application/json'); xhr2.send(payload); if (xhr2.status >= 200 && xhr2.status < 300) { var result = JSON.parse(xhr2.responseText); var xg = new XMLHttpRequest(); xg.open('GET', '/wiki/rest/api/content/${PAGE_ID}/property/content-appearance-published', false); xg.send(); if (xg.status === 200) { var prop = JSON.parse(xg.responseText); if (!prop.value || prop.value.appearance !== 'full-width') { var xp = new XMLHttpRequest(); xp.open('PUT', '/wiki/rest/api/content/${PAGE_ID}/property/content-appearance-published', false); xp.setRequestHeader('Content-Type', 'application/json'); xp.send(JSON.stringify({key:'content-appearance-published',value:{appearance:'full-width'},version:{number:prop.version.number+1}})); } } else { var xp = new XMLHttpRequest(); xp.open('POST', '/wiki/rest/api/content/${PAGE_ID}/property', false); xp.setRequestHeader('Content-Type', 'application/json'); xp.send(JSON.stringify({key:'content-appearance-published',value:{appearance:'full-width'},version:{number:1}})); } 'UPDATED: ' + result.id + ' | ' + (result._links ? result._links.webui : ''); } else { 'ERROR: PUT ' + xhr2.status + ' ' + xhr2.responseText.substring(0, 200); } }"
        ;;
    
    get-page)
        PAGE_ID="${1:-}"
        
        if [ -z "$PAGE_ID" ]; then
            echo "Usage: confluence-api.sh get-page <page_id>" >&2
            exit 1
        fi
        
        TAB=$(require_tab)
        WIN=$(parse_win "$TAB")
        TIDX=$(parse_tab "$TAB")
        
        chrome_js "$WIN" "$TIDX" "var xhr = new XMLHttpRequest(); xhr.open('GET', '/wiki/api/v2/pages/${PAGE_ID}?body-format=storage', false); xhr.send(); if (xhr.status === 200) { var result = JSON.parse(xhr.responseText); result.title + ' | ' + result.body.storage.value; } else { 'ERROR: ' + xhr.status; }"
        ;;
    
    help|*)
        cat >&2 <<EOF
Confluence API via Chrome JS

Usage: confluence-api.sh <command> [args...]

Commands:
  tab                                    Find Confluence tab in Chrome
  create-page <parent_id> <title_file> <content_file>   Create child page (reads from files)
  update-page <page_id> <content>       Update page content
  get-page <page_id>                    Get page content

Prerequisites:
  - Chrome must have an active Confluence session on datadoghq.atlassian.net/wiki
  - "Allow JavaScript from Apple Events" must be enabled in Chrome (Developer menu)

Examples:
  # Create a RAG entry (write title and content to files first)
  echo "[JMX/Kafka] Missing metrics" > /tmp/title.txt
  echo "## Symptoms..." > /tmp/content.txt
  confluence-api.sh create-page 6310658850 /tmp/title.txt /tmp/content.txt
  
  # Update existing page
  confluence-api.sh update-page 1234567890 "Updated content..."
EOF
        exit 1
        ;;
esac
