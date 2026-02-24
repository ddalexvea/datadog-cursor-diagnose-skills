#!/bin/bash
# Verify Snagit screen recording prerequisites

echo "=== Snagit Screen Record Setup Check ==="
echo ""

PASS=0
FAIL=0

# Check Snagit installed
if [ -d "/Applications/Snagit 2024.app" ]; then
    echo "[OK] Snagit 2024 installed"
    PASS=$((PASS + 1))
else
    echo "[FAIL] Snagit 2024 not found in /Applications"
    FAIL=$((FAIL + 1))
fi

# Check SnagitHelper running
if pgrep -f "SnagitHelper2024" > /dev/null 2>&1; then
    echo "[OK] SnagitHelper2024 is running"
    PASS=$((PASS + 1))
else
    echo "[WARN] SnagitHelper2024 is not running"
    echo "       -> Open Snagit 2024 to start the capture helper"
    FAIL=$((FAIL + 1))
fi

# Check capture type (2 = video)
CAPTURE_TYPE=$(defaults read com.techsmith.snagit.capturehelper2024 CurrentCaptureType 2>/dev/null)
if [ "$CAPTURE_TYPE" = "2" ]; then
    echo "[OK] Snagit is in Video capture mode"
    PASS=$((PASS + 1))
else
    echo "[INFO] Snagit capture mode is '$CAPTURE_TYPE' (will auto-switch to video)"
    PASS=$((PASS + 1))
fi

# Check Accessibility permissions
ACCESSIBILITY_DB="/Library/Application Support/com.apple.TCC/TCC.db"
if sqlite3 "$ACCESSIBILITY_DB" "SELECT client FROM access WHERE service='kTCCServiceAccessibility' AND client LIKE '%cursor%';" 2>/dev/null | grep -qi cursor; then
    echo "[OK] Cursor has Accessibility permissions"
    PASS=$((PASS + 1))
else
    echo "[WARN] Cannot verify Cursor Accessibility permissions"
    echo "       -> System Settings > Privacy & Security > Accessibility"
    echo "       -> Ensure Cursor is listed and enabled"
    echo "       -> Opening settings now..."
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null
    FAIL=$((FAIL + 1))
fi

# Check Screen Recording permission
if sqlite3 "$ACCESSIBILITY_DB" "SELECT client FROM access WHERE service='kTCCServiceScreenCapture' AND client LIKE '%snagit%';" 2>/dev/null | grep -qi snagit; then
    echo "[OK] Snagit has Screen Recording permission"
    PASS=$((PASS + 1))
else
    echo "[INFO] Cannot verify Snagit Screen Recording permission via CLI"
    echo "       -> If recording fails, check: System Settings > Privacy & Security > Screen Recording"
    PASS=$((PASS + 1))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL issues ==="

if [ $FAIL -eq 0 ]; then
    echo "Setup looks good! Try:"
    echo "  bash ~/.cursor/skills/snagit-screen-record/scripts/record.sh start"
else
    echo "Please fix the issues above, then run this script again."
fi
