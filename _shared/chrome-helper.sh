#!/bin/bash
# Robust Chrome tab finder — handles multiple Chrome/Chromium instances
#
# Problem: When a second Google Chrome process exists (e.g. CDP, Playwright),
# macOS routes Apple Events to it instead of the user's real browser.
# This causes `tell application "Google Chrome"` to see 0 windows.
#
# Solution: Try direct first. If 0 windows detected, terminate conflicting
# Chrome instances (those with --remote-debugging-port or --user-data-dir=/tmp)
# which are always tool-launched, never user-launched. Then retry.
#
# Note: Chromium (Playwright, Electron) has a different bundle ID and does NOT
# interfere with Apple Events routing to Google Chrome. Only duplicate Google
# Chrome main processes cause this issue.
#
# Usage:
#   source chrome-helper.sh
#   chrome_find_tab "zendesk.com"          → "winIndex:tabIndex" or "-1:-1"
#   chrome_exec_js <win> <tab> "<js>"      → JS result
#   chrome_exec_js_file <win> <tab> <file> → JS result from file

_chrome_window_count() {
    osascript -e 'tell application "Google Chrome" to count of windows' 2>/dev/null || echo "0"
}

_chrome_kill_conflicts() {
    local pids
    pids=$(ps -eo pid,command | grep "[M]acOS/Google Chrome" | grep -v "Helper" | grep -v "Framework" | grep -E "\-\-remote-debugging-port|\-\-user-data-dir=/tmp" | awk '{print $1}')

    if [ -z "$pids" ]; then
        return 1
    fi

    for pid in $pids; do
        kill "$pid" 2>/dev/null
    done
    sleep 1
    return 0
}

_chrome_ensure_target() {
    local win_count
    win_count=$(_chrome_window_count)

    if [ "$win_count" -gt 0 ]; then
        return 0
    fi

    _chrome_kill_conflicts || return 1

    win_count=$(_chrome_window_count)
    [ "$win_count" -gt 0 ]
}

chrome_find_tab() {
    local url_pattern="${1:?Usage: chrome_find_tab <url_pattern>}"

    _chrome_ensure_target || { echo "-1:-1"; return; }

    osascript -e "tell application \"Google Chrome\"
        set winIndex to -1
        set tabIndex to -1
        set wIdx to 0
        repeat with w in windows
            set wIdx to wIdx + 1
            set tabCount to count of tabs of w
            repeat with i from 1 to tabCount
                if URL of tab i of w contains \"${url_pattern}\" then
                    set winIndex to wIdx
                    set tabIndex to i
                    exit repeat
                end if
            end repeat
            if tabIndex > -1 then exit repeat
        end repeat
        return (winIndex as text) & \":\" & (tabIndex as text)
    end tell" 2>/dev/null
}

chrome_exec_js() {
    local win_index="$1"
    local tab_index="$2"
    local js_code="$3"

    _chrome_ensure_target || { echo "ERROR: Cannot reach Chrome"; return 1; }

    osascript -e "tell application \"Google Chrome\"
        tell tab ${tab_index} of window ${win_index}
            return (execute javascript \"${js_code}\")
        end tell
    end tell" 2>/dev/null
}

chrome_exec_js_file() {
    local win_index="$1"
    local tab_index="$2"
    local js_file="$3"
    local js_code
    js_code=$(cat "$js_file" | tr '\n' ' ' | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

    _chrome_ensure_target || { echo "ERROR: Cannot reach Chrome"; return 1; }

    osascript -e "tell application \"Google Chrome\"
        tell tab ${tab_index} of window ${win_index}
            return (execute javascript \"${js_code}\")
        end tell
    end tell" 2>/dev/null
}
