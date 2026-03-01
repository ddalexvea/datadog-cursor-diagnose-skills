#!/bin/bash
# Glean Chat Import via Chrome JS — extract conversations from app.glean.com
# Usage: glean-chat-api.sh <command> [args...]
#
# Commands:
#   tab                    Find Glean tab index in Chrome
#   list                   List chat conversations from sidebar
#   fetch [chat_id]        Scrape current (or navigated-to) chat as markdown
#   save <chat_id> <dir>   Fetch + save as markdown file to directory

set -euo pipefail

COMMAND="${1:-help}"
shift || true

find_tab() {
    osascript -e 'tell application "Google Chrome"
        set tabIndex to -1
        repeat with w in windows
            set tabCount to count of tabs of w
            repeat with i from 1 to tabCount
                if URL of tab i of w contains "glean.com/chat" then
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

chrome_js_file() {
    local tab_index="$1"
    local js_file="$2"
    local js_code
    js_code=$(cat "$js_file" | tr '\n' ' ' | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
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
        echo "ERROR: No Glean Chat tab found in Chrome. Open app.glean.com/chat first." >&2
        exit 1
    fi
    echo "$tab"
}

sanitize_filename() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-60
}

case "$COMMAND" in
    tab)
        find_tab
        ;;

    list)
        TAB=$(require_tab)
        chrome_js "$TAB" "var container = document.querySelector('._1xr2hzv1j') || document.querySelector('._1ibi0s3di'); if (!container) { 'ERROR: No chat history container found'; } else { var links = container.querySelectorAll('a[href*=\\\"/chat/\\\"]'); var result = 'TOTAL:' + links.length + '\\\\n'; var seen = {}; for (var i = 0; i < links.length; i++) { var href = links[i].href.split('?')[0]; var id = href.split('/chat/')[1]; if (id && !seen[id] && id.indexOf('/') === -1 && id !== 'agents') { seen[id] = true; var title = links[i].textContent.trim().substring(0, 100); result += id + ' | ' + title + '\\\\n'; } } result; }"
        ;;

    fetch)
        CHAT_ID="${1:-}"
        TAB=$(require_tab)

        if [ -n "$CHAT_ID" ]; then
            CURRENT_URL=$(chrome_js "$TAB" "window.location.href;")
            CURRENT_ID=$(echo "$CURRENT_URL" | sed 's|.*/chat/||' | sed 's|?.*||')

            if [ "$CURRENT_ID" != "$CHAT_ID" ]; then
                QE=$(echo "$CURRENT_URL" | grep -o 'qe=[^&]*' || echo "")
                chrome_js "$TAB" "window.location.href = '/chat/${CHAT_ID}${QE:+?$QE}'; 'OK';" > /dev/null
                sleep 3

                RETRIES=0
                while [ $RETRIES -lt 5 ]; do
                    HAS_CONTENT=$(chrome_js "$TAB" "document.querySelector('.wgjulhk') ? 'YES' : 'NO';")
                    if [ "$HAS_CONTENT" = "YES" ]; then
                        break
                    fi
                    sleep 2
                    RETRIES=$((RETRIES + 1))
                done
            fi
        fi

        TMPJS=$(mktemp /tmp/glean-fetch-XXXXXX.js)
        cat > "$TMPJS" << 'JSEOF'
var turns = document.querySelectorAll('.wgjulhk');
var id = 'unknown';
var m = window.location.pathname.match(/\/chat\/([a-f0-9]+)/);
if (m) id = m[1];
var title = document.title.replace(/ \| Glean/,'').replace(/^\(\d+\) /,'').trim() || 'Untitled Glean Chat';
var titleEl = document.querySelector('.zfjwhl5');
if (titleEl) title = titleEl.textContent.trim();
var md = '# ' + title + '\n\n';
md += '> Source: Glean Chat | Chat ID: ' + id + '\n';
md += '> Imported: ' + new Date().toISOString().split('T')[0] + '\n\n';
for (var t = 0; t < turns.length; t++) {
    var turn = turns[t];
    var userQ = turn.querySelector('.wehdmg1') || turn.querySelector('pre');
    var aiResp = turn.querySelector('._1bdmgj40');
    var sources = turn.querySelector('._745pmg0');
    if (userQ) md += '## User\n\n' + userQ.innerText.trim() + '\n\n';
    md += '## Assistant\n\n';
    var aiText = aiResp ? aiResp.innerText.trim() : '';
    if (aiText) md += aiText + '\n\n';
    if (sources) {
        var srcLinks = sources.querySelectorAll('a[href]');
        if (srcLinks.length > 0) {
            md += '**Sources:**\n';
            for (var s = 0; s < srcLinks.length; s++) {
                var st = srcLinks[s].textContent.trim().substring(0, 100);
                var sh = srcLinks[s].href;
                if (st && sh.indexOf('javascript') === -1) md += '- ' + st + '\n';
            }
            md += '\n';
        }
    }
}
if (turns.length === 0) md += '*No messages found in this chat.*\n';
md;
JSEOF
        chrome_js_file "$TAB" "$TMPJS"
        rm -f "$TMPJS"
        ;;

    save)
        CHAT_ID="${1:?Usage: glean-chat-api.sh save <chat_id> <directory>}"
        DEST_DIR="${2:?Usage: glean-chat-api.sh save <chat_id> <directory>}"

        mkdir -p "$DEST_DIR"

        CONTENT=$("$0" fetch "$CHAT_ID")

        if echo "$CONTENT" | grep -q "^ERROR:"; then
            echo "$CONTENT" >&2
            exit 1
        fi

        TITLE=$(echo "$CONTENT" | head -1 | sed 's/^# //')
        SAFE_NAME=$(sanitize_filename "$TITLE")
        DATE=$(date +%Y-%m-%d)
        FILENAME="${DATE}-${SAFE_NAME}.md"

        echo "$CONTENT" > "${DEST_DIR}/${FILENAME}"
        echo "SAVED: ${DEST_DIR}/${FILENAME}"
        ;;

    help|*)
        echo "Glean Chat Import via Chrome JS"
        echo ""
        echo "Usage: glean-chat-api.sh <command> [args...]"
        echo ""
        echo "Commands:"
        echo "  tab                    Find Glean Chat tab index"
        echo "  list                   List chat conversations from sidebar"
        echo "  fetch [chat_id]        Fetch chat as markdown (current if no ID)"
        echo "  save <chat_id> <dir>   Fetch + save to directory"
        echo ""
        echo "Requires: Chrome + Glean Chat tab + JS from Apple Events enabled"
        ;;
esac
