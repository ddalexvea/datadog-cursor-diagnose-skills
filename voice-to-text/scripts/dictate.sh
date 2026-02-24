#!/bin/bash
# Trigger macOS Dictation by simulating Fn Fn keypress

OUTPUT=$(osascript -e '
    delay 0.3
    tell application "System Events"
        key code 63
        key code 63
    end tell
' 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "Dictation activated. Speak now."
    echo "Press Fn, Escape, or click the mic icon to stop."
elif echo "$OUTPUT" | grep -q "1002"; then
    echo "Accessibility permission required."
    echo ""
    echo "Fix: System Settings > Privacy & Security > Accessibility"
    echo "     -> Click '+' and add Cursor (or grant permission if already listed)"
    echo "     -> You may need to restart Cursor after granting access"
    echo ""
    echo "Alternative: Press Fn Fn manually to start dictation."
else
    echo "Failed to trigger dictation: $OUTPUT"
    echo ""
    echo "Try pressing Fn Fn manually in any text field."
fi
