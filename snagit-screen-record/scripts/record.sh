#!/bin/bash
# Control Snagit video recording via AppleScript
# Usage: record.sh [start|stop|toggle]

ACTION="${1:-toggle}"

ensure_snagit_running() {
    if ! pgrep -f "SnagitHelper2024" > /dev/null 2>&1; then
        echo "Starting Snagit..."
        open -a "Snagit 2024"
        sleep 3
    fi
}

start_recording() {
    ensure_snagit_running

    OUTPUT=$(osascript -e '
        tell application "System Events"
            -- Shift+Control+C triggers Snagit All-in-One capture
            key code 8 using {shift down, control down}
        end tell
    ' 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo "Snagit capture triggered."
        echo "Select the recording area, then click Record."
    elif echo "$OUTPUT" | grep -q "1002"; then
        echo "ERROR: Accessibility permission required."
        echo ""
        echo "Fix: System Settings > Privacy & Security > Accessibility"
        echo "     -> Add or enable Cursor"
        echo "     -> Restart Cursor after granting access"
        return 1
    else
        echo "Failed to trigger capture: $OUTPUT"
        return 1
    fi
}

stop_recording() {
    OUTPUT=$(osascript -e '
        tell application "System Events"
            -- Shift+Control+C again stops the recording
            key code 8 using {shift down, control down}
        end tell
    ' 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo "Stop signal sent. Recording should open in Snagit Editor."
    else
        echo "Failed to stop: $OUTPUT"
        echo "Try clicking the Snagit stop button manually."
        return 1
    fi
}

case "$ACTION" in
    start)
        start_recording
        ;;
    stop)
        stop_recording
        ;;
    toggle)
        start_recording
        ;;
    *)
        echo "Usage: record.sh [start|stop|toggle]"
        exit 1
        ;;
esac
