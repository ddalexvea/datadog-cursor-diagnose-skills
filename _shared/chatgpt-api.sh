#!/bin/bash
# ChatGPT Chat Import via Chrome JS — extract conversations from chatgpt.com
# Usage: chatgpt-api.sh <command> [args...]
#
# Commands:
#   tab                    Find ChatGPT tab index in Chrome
#   list [limit]           List conversations from sidebar (default: 30)
#   fetch <conv_id>        Navigate to conversation, scrape messages, return markdown
#   save <conv_id> <dir>   Fetch + save as markdown file to directory

set -euo pipefail

COMMAND="${1:-help}"
shift || true

find_tab() {
    osascript -e 'tell application "Google Chrome"
        set winIndex to -1
        set tabIndex to -1
        set wIdx to 0
        repeat with w in windows
            set wIdx to wIdx + 1
            set tabCount to count of tabs of w
            repeat with i from 1 to tabCount
                if URL of tab i of w contains "chatgpt.com" then
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
        echo "ERROR: No ChatGPT tab found in Chrome" >&2
        exit 1
    fi
    echo "$win_index:$tab_index"
}

parse_win() { echo "${1%%:*}"; }
parse_tab() { echo "${1##*:}"; }

sanitize_filename() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-60
}

case "$COMMAND" in
    tab)
        find_tab
        ;;

    list)
        LIMIT="${1:-30}"
        TAB=$(require_tab)
        chrome_js "$(parse_win "$TAB")" "$(parse_tab "$TAB")" "var links = document.querySelectorAll('nav a[href*=\\\"/c/\\\"]'); var result = 'TOTAL:' + links.length + '\\\\n'; for (var i = 0; i < Math.min(links.length, ${LIMIT}); i++) { var href = links[i].href; var id = href.split('/c/')[1].split('?')[0]; var title = links[i].textContent.trim().substring(0, 100); result += id + ' | ' + title + '\\\\n'; } result;"
        ;;

    fetch)
        CONV_ID="${1:?Usage: chatgpt-api.sh fetch <conversation_id>}"
        TAB=$(require_tab)
        W=$(parse_win "$TAB")
        T=$(parse_tab "$TAB")

        ORIGINAL_URL=$(chrome_js "$W" "$T" "window.location.href;")

        chrome_js "$W" "$T" "window.location.href = 'https://chatgpt.com/c/${CONV_ID}'; 'OK';" > /dev/null

        sleep 4

        RETRIES=0
        while [ $RETRIES -lt 5 ]; do
            MSG_COUNT=$(chrome_js "$W" "$T" "document.querySelectorAll('[data-message-author-role]').length;")
            if [ "$MSG_COUNT" -gt 0 ] 2>/dev/null; then
                break
            fi
            sleep 2
            RETRIES=$((RETRIES + 1))
        done

        if [ "$MSG_COUNT" -le 0 ] 2>/dev/null; then
            echo "ERROR: No messages found after waiting. Page may not have loaded." >&2
            chrome_js "$W" "$T" "window.location.href = '${ORIGINAL_URL}'; 'OK';" > /dev/null
            exit 1
        fi

        TITLE=$(chrome_js "$W" "$T" "var h = document.querySelector('h1') || document.querySelector('title'); h ? h.textContent.trim() : 'Untitled';")

        chrome_js "$W" "$T" "var msgs = document.querySelectorAll('[data-message-author-role]'); var title = document.title.replace(' | ChatGPT','').replace(' - ChatGPT','').trim() || 'Untitled'; var md = '# ' + title + '\\\\n\\\\n'; md += '> Source: ChatGPT | Conversation ID: ${CONV_ID}\\\\n'; md += '> Imported: ' + new Date().toISOString().split('T')[0] + '\\\\n\\\\n'; for (var i = 0; i < msgs.length; i++) { var role = msgs[i].getAttribute('data-message-author-role'); var text = msgs[i].innerText; if (role === 'user') { md += '## User\\\\n\\\\n' + text + '\\\\n\\\\n'; } else { md += '## Assistant\\\\n\\\\n' + text + '\\\\n\\\\n'; } } md;"

        chrome_js "$W" "$T" "window.location.href = '${ORIGINAL_URL}'; 'OK';" > /dev/null
        ;;

    save)
        CONV_ID="${1:?Usage: chatgpt-api.sh save <conversation_id> <directory>}"
        DEST_DIR="${2:?Usage: chatgpt-api.sh save <conversation_id> <directory>}"

        mkdir -p "$DEST_DIR"

        CONTENT=$("$0" fetch "$CONV_ID")

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
        echo "ChatGPT Chat Import via Chrome JS"
        echo ""
        echo "Usage: chatgpt-api.sh <command> [args...]"
        echo ""
        echo "Commands:"
        echo "  tab                    Find ChatGPT tab index"
        echo "  list [limit]           List conversations from sidebar"
        echo "  fetch <conv_id>        Fetch conversation as markdown"
        echo "  save <conv_id> <dir>   Fetch + save to directory"
        echo ""
        echo "Requires: Chrome + ChatGPT tab + JS from Apple Events enabled"
        ;;
esac
