#!/bin/bash
# Verify macOS Dictation is configured for use with Cursor

echo "=== Voice-to-Text Setup Check ==="
echo ""

PASS=0
FAIL=0

# Check macOS version
OS_VERSION=$(sw_vers -productVersion 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "[OK] macOS version: $OS_VERSION"
    PASS=$((PASS + 1))
else
    echo "[FAIL] Could not detect macOS version"
    FAIL=$((FAIL + 1))
fi

# Check if Dictation is enabled (key location varies by macOS version)
DICTATION_ENABLED=$(defaults read com.apple.HIToolbox AppleDictationAutoEnable 2>/dev/null)
DICTATION_PREFS=$(defaults read com.apple.speech.recognition.AppleSpeechRecognition.prefs 2>/dev/null)
if [ "$DICTATION_ENABLED" = "1" ] || [ -n "$DICTATION_PREFS" ]; then
    echo "[OK] Dictation appears configured"
    PASS=$((PASS + 1))
else
    echo "[WARN] Dictation may not be enabled"
    echo "       -> System Settings > Keyboard > Dictation > Toggle ON"
    echo "       -> Opening settings now..."
    open "x-apple.systempreferences:com.apple.Keyboard-Settings.extension" 2>/dev/null
    FAIL=$((FAIL + 1))
fi

# Check Fn key usage type (must be "Start Dictation", not "Emoji Picker")
FN_USAGE=$(defaults read com.apple.HIToolbox AppleFnUsageType 2>/dev/null)
if [ "$FN_USAGE" = "3" ]; then
    echo "[OK] Fn key is set to Start Dictation"
    PASS=$((PASS + 1))
else
    echo "[WARN] Fn key may be set to Emoji Picker instead of Dictation"
    echo "       -> On macOS 15+, change via UI only:"
    echo "       -> System Settings > Keyboard > 'Press fn key to' > Start Dictation"
    echo "       -> Opening settings now..."
    open "x-apple.systempreferences:com.apple.Keyboard-Settings.extension" 2>/dev/null
    FAIL=$((FAIL + 1))
fi

# Check if Cursor has Accessibility access (needed for osascript key simulation)
CURSOR_BUNDLE="com.todesktop.230313mzl4w4u92"
ACCESSIBILITY_DB="/Library/Application Support/com.apple.TCC/TCC.db"
if sqlite3 "$ACCESSIBILITY_DB" "SELECT client FROM access WHERE service='kTCCServiceAccessibility' AND client LIKE '%cursor%';" 2>/dev/null | grep -qi cursor; then
    echo "[OK] Cursor has Accessibility permissions"
    PASS=$((PASS + 1))
else
    echo "[WARN] Cannot verify Cursor Accessibility permissions"
    echo "       -> Ensure Cursor is listed and enabled"
    echo "       -> This is required for the dictation trigger script"
    echo "       -> Opening settings now..."
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null
fi

# Check microphone availability
if system_profiler SPAudioDataType 2>/dev/null | grep -q "Input"; then
    echo "[OK] Microphone detected"
    PASS=$((PASS + 1))
else
    echo "[WARN] Could not detect microphone input"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL issues ==="

if [ $FAIL -eq 0 ]; then
    echo "Setup looks good! You can trigger dictation with:"
    echo "  bash ~/.cursor/skills/voice-to-text/scripts/dictate.sh"
    echo ""
    echo "Or press Fn Fn manually in any Cursor text field."
else
    echo "Please fix the issues above, then run this script again."
fi