# RIVA Festival Cast Recovery

**Your RIVA Festival speaker lost Google Cast after a factory reset or firmware update? This guide will fix it.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub Release](https://img.shields.io/badge/Release-v2.0-blue.svg)](../../releases)

## The Problem

After a factory reset, firmware reflash, or failed OTA update, RIVA Festival speakers lose Google Cast functionality. Symptoms include:

- Speaker not visible in Chrome/YouTube Cast menu
- Cast connects from PC but mobile streaming (SoundCloud, Spotify, YouTube) produces no audio
- `setup_state=63` and `tos_accepted=false` in Cast configuration
- Logcat error: `Version mismatch between V8 binary and snapshot`

## Root Causes

Our reverse-engineering analysis identified **three independent problems** that must all be resolved:

| # | Problem | Symptom | Fix |
|---|---------|---------|-----|
| 1 | Setup state stuck | `setup_state=63`, `tos_accepted=false` | Patch `.eureka.conf` |
| 2 | V8 snapshot mismatch | Mobile Cast no audio, PC works | Sync `/system/chrome/` binaries |
| 3 | mDNS isolation | Speaker invisible in Cast menu | Same Wi-Fi band |

## Quick Start

### Prerequisites
- Windows PC with **Python 3.x** and **OpenSSH** installed
- RIVA Festival speaker powered on and connected to Wi-Fi
- Speaker IP address (check your router admin page)

### Step 1: SSH into the speaker
```bash
ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa root@<SPEAKER_IP>
```
Password: empty (press Enter).

### Step 2: Diagnose
```bash
cat /lsync/data1/chrome/.eureka.conf | grep -E 'setup-state|tos-accepted'
ls -la /system/chrome/snapshot_blob.bin /system/chrome/icudtl.dat /system/chrome/chrome-sandbox
```

### Step 3: Fix
Follow the full [Recovery Guide v2.0](RECOVERY_GUIDE_v2.md) for step-by-step instructions covering all three root causes.

## Firmware Files

This repository provides three levels of firmware recovery:

| Level | Method | Size | Location |
|-------|--------|------|----------|
| A | OTA download script | ~79 MB | `scripts/download_ota.sh` |
| B | Delta patch (5 critical files) | 5.5 MB | `patches/delta-chrome-5files.tar.gz` |
| C | Full system image | 75 MB | [GitHub Releases](../../releases) |

**Recommended:** Start with Level A (fully legal, downloads from public OTA server). Use Level B if OTA is unavailable. Level C is a last resort.

## Documentation

- [Recovery Guide v2.0](RECOVERY_GUIDE_v2.md) — Complete 15-stage recovery procedure
- [Troubleshooting](TROUBLESHOOTING.md) — Decision tree and FAQ
- [Streaming Services](STREAMING_SERVICES.md) — Cast, AirPlay, Spotify, DLNA reference
- [DNA](DNA.md) — Full technical knowledge base (device specs, commands, file sizes)
- [Disclaimer](DISCLAIMER.md) — Legal information

## Device Information

| Specification | Value |
|--------------|-------|
| Product | RIVA Festival (2018) |
| SoC | Libre Wireless LS9 (ARM Cortex-A7) |
| OS | Embedded Linux (Buildroot), kernel 3.10.x |
| Shell | BusyBox 1.24.1 |
| Cast Stack | Chromium cast_shell (V8 8.6) |
| Streaming | Google Cast, AirPlay, Spotify Connect, DLNA, Bluetooth |

## Contributing

Contributions are welcome! Please read the following before submitting:
- Open an issue to discuss the problem before creating a pull request
- Include diagnostic output from your speaker when reporting issues
- Test your changes on a real RIVA Festival device

## Acknowledgments

Special thanks to **Dylan**, technical engineer at RIVA Audio, who provided custom firmware builds, acknowledged our reverse-engineering analysis, and forwarded our findings to the RIVA engineering team.

## Legal

This project is for **restoration of legally owned devices only**. All firmware binaries belong to RIVA Audio / Libre Wireless / Google LLC. See [DISCLAIMER.md](DISCLAIMER.md) for full legal information.

## Keywords

RIVA Festival, Chromecast fix, Cast broken, Libre Wireless LS9, V8 snapshot mismatch, smart speaker recovery, embedded Linux, Buildroot, BusyBox, cast_shell, eureka.conf, setup_state
