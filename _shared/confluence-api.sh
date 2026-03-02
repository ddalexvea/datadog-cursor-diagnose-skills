#!/bin/bash
# Confluence API via Chrome JS — shared helper for creating/updating pages
# Usage: confluence-api.sh <command> [args...]
#
# Commands:
#   tab                                    Find Confluence tab index in Chrome
#   create-page <parent_id> <title> <content>   Create a child page under parent
#   update-page <page_id> <content>       Update existing page content
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
        TITLE="${2:-}"
        CONTENT="${3:-}"
        
        if [ -z "$PARENT_ID" ] || [ -z "$TITLE" ] || [ -z "$CONTENT" ]; then
            echo "Usage: confluence-api.sh create-page <parent_id> <title> <content>" >&2
            exit 1
        fi
        
        TAB=$(require_tab)
        WIN=$(parse_win "$TAB")
        TIDX=$(parse_tab "$TAB")
        
        # Escape content for JS string (replace quotes, newlines)
        ESCAPED_TITLE=$(echo "$TITLE" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        ESCAPED_CONTENT=$(echo "$CONTENT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        
        # Use Confluence REST API v2 to create page
        # We'll convert markdown to Atlassian Document Format (ADF) via a simple wrapper
        JS_CODE="
(async function() {
    const cloudId = window.location.pathname.split('/')[2];
    const apiBase = 'https://datadoghq.atlassian.net/wiki/api/v2';
    
    // Convert markdown to plain text storage format (simplified)
    const content = {
        representation: 'storage',
        value: '<p>' + decodeURIComponent('${ESCAPED_CONTENT}').replace(/\n\n/g, '</p><p>').replace(/\n/g, '<br/>') + '</p>'
    };
    
    const payload = {
        spaceId: null,  // will be inherited from parent
        status: 'current',
        title: decodeURIComponent('${ESCAPED_TITLE}'),
        parentId: '${PARENT_ID}',
        body: content
    };
    
    const response = await fetch(apiBase + '/pages', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        },
        credentials: 'include',
        body: JSON.stringify(payload)
    });
    
    if (!response.ok) {
        const err = await response.text();
        return 'ERROR: ' + response.status + ' - ' + err;
    }
    
    const result = await response.json();
    return 'CREATED: ' + result.id + ' | ' + result._links.webui;
})();
        "
        
        chrome_js "$WIN" "$TIDX" "$JS_CODE"
        ;;
    
    update-page)
        PAGE_ID="${1:-}"
        CONTENT="${2:-}"
        
        if [ -z "$PAGE_ID" ] || [ -z "$CONTENT" ]; then
            echo "Usage: confluence-api.sh update-page <page_id> <content>" >&2
            exit 1
        fi
        
        TAB=$(require_tab)
        WIN=$(parse_win "$TAB")
        TIDX=$(parse_tab "$TAB")
        
        ESCAPED_CONTENT=$(echo "$CONTENT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        
        JS_CODE="
(async function() {
    const apiBase = 'https://datadoghq.atlassian.net/wiki/api/v2';
    
    // Get current version
    const getResp = await fetch(apiBase + '/pages/${PAGE_ID}', {
        credentials: 'include'
    });
    const current = await getResp.json();
    
    const content = {
        representation: 'storage',
        value: '<p>' + decodeURIComponent('${ESCAPED_CONTENT}').replace(/\n\n/g, '</p><p>').replace(/\n/g, '<br/>') + '</p>'
    };
    
    const payload = {
        id: '${PAGE_ID}',
        status: 'current',
        title: current.title,
        body: content,
        version: {
            number: current.version.number + 1,
            message: 'Updated via automation'
        }
    };
    
    const response = await fetch(apiBase + '/pages/${PAGE_ID}', {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        },
        credentials: 'include',
        body: JSON.stringify(payload)
    });
    
    if (!response.ok) {
        const err = await response.text();
        return 'ERROR: ' + response.status + ' - ' + err;
    }
    
    const result = await response.json();
    return 'UPDATED: ' + result.id + ' | ' + result._links.webui;
})();
        "
        
        chrome_js "$WIN" "$TIDX" "$JS_CODE"
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
        
        JS_CODE="
(async function() {
    const apiBase = 'https://datadoghq.atlassian.net/wiki/api/v2';
    const response = await fetch(apiBase + '/pages/${PAGE_ID}?body-format=storage', {
        credentials: 'include'
    });
    
    if (!response.ok) {
        return 'ERROR: ' + response.status;
    }
    
    const result = await response.json();
    return result.title + ' | ' + result.body.storage.value;
})();
        "
        
        chrome_js "$WIN" "$TIDX" "$JS_CODE"
        ;;
    
    help|*)
        cat >&2 <<EOF
Confluence API via Chrome JS

Usage: confluence-api.sh <command> [args...]

Commands:
  tab                                    Find Confluence tab in Chrome
  create-page <parent_id> <title> <content>   Create child page
  update-page <page_id> <content>       Update page content
  get-page <page_id>                    Get page content

Prerequisites:
  - Chrome must have an active Confluence session on datadoghq.atlassian.net/wiki
  - "Allow JavaScript from Apple Events" must be enabled in Chrome (Developer menu)

Examples:
  # Create a RAG entry
  confluence-api.sh create-page 6310658850 "[JMX/Kafka] Missing metrics" "## Symptoms..."
  
  # Update existing page
  confluence-api.sh update-page 1234567890 "Updated content..."
EOF
        exit 1
        ;;
esac
