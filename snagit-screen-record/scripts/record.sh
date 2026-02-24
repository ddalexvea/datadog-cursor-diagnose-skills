#!/bin/bash
# Trigger Snagit video capture via AppleScript

if ! pgrep -f "SnagitHelper2024" > /dev/null 2>&1; then
    echo "Starting Snagit..."
    open -a "Snagit 2024"
    sleep 3
fi

OUTPUT=$(osascript -e '
    tell application "System Events"
        key code 8 using {shift down, control down}
    end tell
' 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "Snagit capture triggered."
    echo "Select the recording area, then click Record."
    echo "Use Snagit's stop button when done."
elif echo "$OUTPUT" | grep -q "1002"; then
    echo "ERROR: Accessibility permission required."
    echo ""
    echo "Fix: System Settings > Privacy & Security > Accessibility"
    echo "     -> Add or enable Cursor"
    echo "     -> Restart Cursor after granting access"
    exit 1
else
    echo "Failed to trigger capture: $OUTPUT"
    exit 1
fi
