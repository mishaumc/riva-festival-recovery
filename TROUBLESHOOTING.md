# RIVA Festival Troubleshooting Guide

## Decision Tree

Start from the top and follow the arrows:

### Q1: Can you SSH into the speaker?
- **YES** -> Go to Q2
- **NO** ->
  - Is the speaker powered on? Check LED status.
  - Is the speaker connected to Wi-Fi? Check router admin page for its IP.
  - Is the speaker in Away/hotspot mode? Connect to its Wi-Fi hotspot (RIVA_xxxx), then SSH to 192.168.200.1.
  - Try scanning: `nmap -p 22 192.168.0.0/24` (adjust subnet)
  - If SSH port is closed, the speaker may need a factory reset (hold Bluetooth + Volume Down for 10 seconds)

### Q2: What is the setup_state in .eureka.conf?
Run: `cat /lsync/data1/chrome/.eureka.conf`
- **setup_state=63, tos_accepted=false** -> Root Cause #1. Go to Stage 4 in Recovery Guide.
- **setup_state=0** -> Speaker needs initial setup. Use RIVA VOICE app or write wpa_supplicant.conf (Stage 5).
- **setup_state=1** -> Setup in progress. Wait or reboot.
- **setup_state=60** -> Setup complete but Cast may not be initialized. Check tos_accepted and once-reach flags.

### Q3: Is cast_shell process running?
Run: `ps | grep cast_shell`
- **Running** -> Go to Q4
- **Not running** ->
  - Check `cat /lsync/data1/chrome/initial_error` for crash reason
  - If 'Version mismatch between V8 binary and snapshot' -> Root Cause #2. Go to Stage 6.
  - If 'Permission denied' on chrome-sandbox -> Fix permissions (Stage 7).
  - If 'No space left on device' -> `df -h` and clean up /tmp or /lsync/data1/
  - Try manual start: `cd /system/chrome && ./cast_shell --no-sandbox &` and watch for errors

### Q4: Is the speaker visible in Chrome/YouTube Cast menu?
- **YES** -> Go to Q5
- **NO** ->
  - Root Cause #3: mDNS isolation
  - Check: `curl http://<IP>:8008/setup/eureka_info` from PC. If it returns JSON, Cast HTTP is working but mDNS is blocked.
  - Fix: Connect PC/phone to same Wi-Fi band as speaker (2.4 GHz or 5 GHz)
  - Fix: Enable IGMP Snooping on router
  - Fix: Disable AP Isolation on router
  - Check Avahi: `ps | grep avahi` on speaker. If not running, `avahi-daemon -D`

### Q5: Does PC Cast work (Chrome tab, YouTube from PC)?
- **YES** -> Go to Q6
- **NO** ->
  - Check firewall on PC (allow outbound TCP 8008, 8009)
  - Check `initial_error` log on speaker
  - Verify cast_shell is running and port 8008 is listening: `netstat -tlnp | grep 8008`

### Q6: Does mobile Cast work (SoundCloud, Spotify, YouTube from phone)?
- **YES** -> Recovery complete! All three root causes resolved.
- **NO (connects but no audio)** ->
  - Root Cause #2: V8 snapshot mismatch
  - Check: `ls -la /system/chrome/snapshot_blob.bin`
  - If size is 712,032 bytes -> WRONG (2017 version). Must be 49,927 bytes (2020 version).
  - Check: `ls -la /system/chrome/chrome-sandbox`
  - If size is 722,964 bytes -> WRONG. Must be 22,176 bytes.
  - Check: `ls -la /system/chrome/icudtl.dat`
  - If missing -> WRONG. Must be 5,049,344 bytes.
  - Fix: Apply delta patch or full sync (Stage 6 in Recovery Guide)
- **NO (does not connect at all)** ->
  - Check phone is on same Wi-Fi network and band
  - Restart phone Wi-Fi
  - Reboot speaker

## FAQ

### Q: I reflashed firmware p15647 from Dylan. Cast works from PC but not from phone. Why?
A: Firmware p15647 updates cast_shell to 2020 version but does NOT update the supporting binaries (snapshot_blob.bin, icudtl.dat, chrome-sandbox, cast_shell.pak). The V8 engine in the new cast_shell expects a 2020 snapshot, but the old 2017 snapshot is still on disk. Apply the delta patch (Stage 6) to fix.

### Q: I applied the eureka.conf patch but it reverted after reboot. Why?
A: You did not kill cast_shell before editing. The running cast_shell process keeps a copy of the config in RAM and writes it back to disk periodically. Always run `killall -9 cast_shell process_manager castlucicomm` BEFORE editing .eureka.conf.

### Q: Can I use the Google Home app to set up the speaker?
A: Only if setup_state is 0 or 1. After the eureka.conf patch (setup_state=60), the Google Home app will not recognize the speaker as needing setup. Use the SSH method (Stage 5) instead.

### Q: The speaker shows up in Cast menu but disconnects immediately. What is wrong?
A: This usually means the Cast receiver app crashes on startup. Check `cat /lsync/data1/chrome/initial_error`. Common causes: V8 mismatch, missing icudtl.dat, wrong chrome-sandbox permissions.

### Q: AirPlay works but Cast does not. Is this normal?
A: Yes, AirPlay and Cast are completely independent systems. AirPlay uses Shairport (separate process), while Cast uses cast_shell (Chromium). A Cast failure does not affect AirPlay.

### Q: Spotify Connect does not appear in the Spotify app. How to fix?
A: Spotify Connect requires a Spotify Premium account. Also check that the speaker is on the same network as your phone. The Spotify Connect daemon (librespot or Spotify SDK) runs as a separate process from Cast.

### Q: I accidentally deleted files from /system/chrome/. Can I recover?
A: Yes. Download the Cast OTA package from http://dev.hansong-china.com/OTA/Riva/Festival/cast_receiver_signed_1.52at.272222_NEON_GM2.zip, extract it, and copy the files back via SSH. Or apply the full image from GitHub Releases.

### Q: The speaker is bricked after a failed firmware update. What can I do?
A: If SSH still works, you can reflash using the OTA image: download 83_IMAGE_NETWORK and use the speaker's update_engine. If SSH does not work, you may need UART/serial access to the LS9 board (advanced hardware modification).

### Q: Can I use this guide for RIVA Arena or RIVA Concert?
A: This guide is specifically for RIVA Festival (LS9 platform). RIVA Arena and Concert use different SoCs and may have different file paths and binary versions. The general approach (eureka.conf + binary sync) may apply, but file sizes and paths will differ.

## Error Messages Reference

| Error Message | Meaning | Fix |
|--------------|---------|-----|
| Version mismatch between V8 binary and snapshot | snapshot_blob.bin does not match cast_shell V8 version | Stage 6: sync binaries |
| Permission denied: chrome-sandbox | chrome-sandbox not SUID root | Stage 7: chmod 4755, chown root:chrome |
| Failed to load ICU data | icudtl.dat missing or corrupt | Stage 6: sync binaries |
| setup_state=63 | Cast setup incomplete | Stage 4: patch eureka.conf |
| tos_accepted=false | Terms of service not accepted | Stage 4: patch eureka.conf |
| No space left on device | /system or /data partition full | Clean /tmp, /lsync/data1/cache |
| Connection refused on port 8008 | cast_shell not running | Check initial_error, restart cast_shell |
| mDNS registration failed | Avahi daemon not running or network issue | Start avahi-daemon, check network |
