#!/bin/bash
# RIVA Festival OTA Downloader (Level A)
# Downloads firmware from the public OTA server
# Usage: bash download_ota.sh [output_directory]

set -e

OTA_BASE="http://dev.hansong-china.com/OTA/Riva/Festival"
OUTDIR="${1:-./ota_downloads}"

echo "=== RIVA Festival OTA Downloader ==="
echo "Source: $OTA_BASE"
echo "Output: $OUTDIR"
echo ""

mkdir -p "$OUTDIR"

# Function to download and verify basic integrity
download_and_check() {
    local url="$1"
    local outfile="$2"
    local min_size="$3"
    
    echo "Downloading: $(basename "$outfile")..."
    # -f ensures curl fails on HTTP errors (like 404 or 500)
    curl -f -L -o "$outfile" "$url"
    
    # Check if file exists
    if [ ! -f "$outfile" ]; then
        echo "ERROR: Download failed, file not found."
        exit 1
    fi
    
    # Check file size (POSIX-compliant way to get size in bytes)
    local actual_size=$(wc -c < "$outfile" | tr -d ' ')
    if [ "$actual_size" -lt "$min_size" ]; then
        echo "ERROR: Downloaded file is too small ($actual_size bytes). It might be an error page (e.g., 404)."
        exit 1
    fi
    
    # Calculate and display SHA256 for manual verification against DNA.md
    local hash=$(sha256sum "$outfile" | cut -d' ' -f1)
    echo "  Downloaded size: $actual_size bytes"
    echo "  SHA256: $hash"
    echo "  -> Please verify this hash starts with the expected value in DNA.md Section 8."
    echo ""
}

echo "[1/2] Downloading firmware image (83_IMAGE_NETWORK, ~36 MB)..."
# Minimum size check: 30 MB (30000000 bytes)
download_and_check "$OTA_BASE/83_IMAGE_NETWORK" "$OUTDIR/83_IMAGE_NETWORK" 30000000

echo "[2/2] Downloading Cast OTA package (~43 MB)..."
# Minimum size check: 40 MB (40000000 bytes)
download_and_check "$OTA_BASE/cast_receiver_signed_1.52at.272222_NEON_GM2.zip" "$OUTDIR/cast_receiver_signed.zip" 40000000

echo "=== Download Complete ==="
echo ""
echo "To extract Cast OTA and apply to speaker:"
echo "  1. unzip $OUTDIR/cast_receiver_signed.zip -d $OUTDIR/cast_ota"
echo "  2. Follow RECOVERY_GUIDE_v2.md Stage 6, Option C"
echo ""
echo "Legal: These files are from a publicly accessible OTA server."
echo "Use only for restoration of legally owned RIVA Festival devices."
