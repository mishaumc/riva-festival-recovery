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

echo "[1/2] Downloading firmware image (83_IMAGE_NETWORK, ~36 MB)..."
curl -L -o "$OUTDIR/83_IMAGE_NETWORK" "$OTA_BASE/83_IMAGE_NETWORK"
echo "  SHA256: $(sha256sum "$OUTDIR/83_IMAGE_NETWORK" | cut -d' ' -f1)"

echo "[2/2] Downloading Cast OTA package (~43 MB)..."
curl -L -o "$OUTDIR/cast_receiver_signed.zip" "$OTA_BASE/cast_receiver_signed_1.52at.272222_NEON_GM2.zip"
echo "  SHA256: $(sha256sum "$OUTDIR/cast_receiver_signed.zip" | cut -d' ' -f1)"

echo ""
echo "=== Download Complete ==="
echo ""
echo "To extract Cast OTA and apply to speaker:"
echo "  1. unzip $OUTDIR/cast_receiver_signed.zip -d $OUTDIR/cast_ota"
echo "  2. Follow RECOVERY_GUIDE_v2.md Stage 6, Option C"
echo ""
echo "Legal: These files are from a publicly accessible OTA server."
echo "Use only for restoration of legally owned RIVA Festival devices."
