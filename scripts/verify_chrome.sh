#!/bin/sh
# RIVA Festival Chrome Binary Verifier
# Run this script on the speaker via SSH to verify file integrity
# Usage: sh verify_chrome.sh

CHROME_DIR="/system/chrome"
ERRORS=0

echo "=== RIVA Festival Chrome Binary Verifier ==="
echo "Checking files in $CHROME_DIR..."
echo ""

# Function to check file size
check_file() {
    local file="$1"
    local expected_size="$2"
    local description="$3"
    
    if [ ! -f "$file" ]; then
        echo "ERROR: $description is MISSING"
        echo "  File: $file"
        echo "  Expected size: $expected_size bytes"
        echo "  -> Fix: Apply delta patch or full sync (Stage 6)"
        echo ""
        ERRORS=$((ERRORS + 1))
        return 1
    fi
    
    local actual_size=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
    
    if [ "$actual_size" != "$expected_size" ]; then
        echo "ERROR: $description has WRONG size"
        echo "  File: $file"
        echo "  Expected: $expected_size bytes"
        echo "  Actual:   $actual_size bytes"
        echo "  -> Fix: Apply delta patch or full sync (Stage 6)"
        echo ""
        ERRORS=$((ERRORS + 1))
        return 1
    fi
    
    echo "OK: $description ($actual_size bytes)"
    return 0
}

# Check critical files
echo "[1/6] Checking snapshot_blob.bin (V8 snapshot)..."
check_file "$CHROME_DIR/snapshot_blob.bin" "49927" "snapshot_blob.bin"

echo "[2/6] Checking icudtl.dat (Unicode tables)..."
check_file "$CHROME_DIR/icudtl.dat" "5049344" "icudtl.dat"

echo "[3/6] Checking chrome-sandbox (SUID binary)..."
check_file "$CHROME_DIR/chrome-sandbox" "22176" "chrome-sandbox"

echo "[4/6] Checking assets/cast_shell.pak (UI resources)..."
check_file "$CHROME_DIR/assets/cast_shell.pak" "5210730" "assets/cast_shell.pak"

echo "[5/6] Checking for obsolete natives_blob.bin..."
if [ -f "$CHROME_DIR/natives_blob.bin" ]; then
    echo "ERROR: natives_blob.bin is PRESENT (should be deleted)"
    echo "  File: $CHROME_DIR/natives_blob.bin"
    echo "  -> Fix: rm -f $CHROME_DIR/natives_blob.bin"
    echo ""
    ERRORS=$((ERRORS + 1))
else
    echo "OK: natives_blob.bin is absent (correct)"
fi

echo "[6/6] Checking chromecast_locales/ directory..."
if [ ! -d "$CHROME_DIR/chromecast_locales" ]; then
    echo "ERROR: chromecast_locales/ directory is MISSING"
    echo "  -> Fix: Apply delta patch or full sync (Stage 6)"
    echo ""
    ERRORS=$((ERRORS + 1))
else
    local locale_count=$(ls -1 "$CHROME_DIR/chromecast_locales/" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$locale_count" -lt "100" ]; then
        echo "WARNING: chromecast_locales/ has only $locale_count files (expected ~106)"
        echo "  -> Fix: Apply delta patch or full sync (Stage 6)"
        echo ""
    else
        echo "OK: chromecast_locales/ has $locale_count files"
    fi
fi

echo ""
echo "=== Verification Complete ==="
if [ "$ERRORS" -eq "0" ]; then
    echo "RESULT: All checks PASSED. Chrome binaries are correct."
    echo ""
    echo "Next steps:"
    echo "  1. Ensure permissions are correct (Stage 7)"
    echo "  2. Reboot speaker: sync && sync && reboot"
    echo "  3. Test Cast discovery (Stage 9)"
else
    echo "RESULT: $ERRORS error(s) found. Chrome binaries need repair."
    echo ""
    echo "Next steps:"
    echo "  1. Apply delta patch: RECOVERY_GUIDE_v2.md Stage 6, Option A"
    echo "  2. Fix permissions: RECOVERY_GUIDE_v2.md Stage 7"
    echo "  3. Reboot speaker: sync && sync && reboot"
fi