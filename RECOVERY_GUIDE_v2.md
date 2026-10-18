# RIVA Festival Recovery Guide v2.0

## Overview
This guide restores full Google Cast functionality to RIVA Festival smart speakers after factory reset, firmware reflash, or failed OTA update. It addresses three independent root causes that must all be resolved.

**Prerequisites:**
- Windows PC with Python 3.x and OpenSSH client installed
- RIVA Festival speaker powered on and connected to Wi-Fi (or in Away/hotspot mode)
- IP address of the speaker (check router admin page or RIVA VOICE app)
- Optional: a second working RIVA Festival speaker for speaker-to-speaker sync

## Stage 1: SSH Access Verification

Open PowerShell and connect:
```
ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa root@<SPEAKER_IP>
```
Password: empty (press Enter).

**Expected:** You see a `#` prompt (root shell on BusyBox).
**If connection refused:** Speaker may be in Away mode. Try the IP shown in RIVA VOICE app, or scan with `nmap -p 22 192.168.0.0/24`.

## Stage 2: Diagnostic Data Collection

Run these commands via SSH and save the output:
```
cat /lsync/data1/chrome/.eureka.conf
cat /lsync/data1/chrome/initial_error
ls -la /system/chrome/snapshot_blob.bin /system/chrome/icudtl.dat /system/chrome/chrome-sandbox /system/chrome/assets/cast_shell.pak 2>/dev/null
ls -la /system/chrome/cast_shell /system/chrome/process_manager
cat /proc/version
ifconfig wlan0
```

**What to look for:**
- `setup_state` value (63 = stuck, 0 = needs setup)
- `tos-accepted` value (false = Cast blocked)
- `initial_error` content (V8 mismatch = Root Cause #2)
- File sizes (compare against correct values in DNA.md Section 5)

## Stage 3: Network Alignment

**Root Cause #3: mDNS Multicast Isolation**

Cast discovery uses mDNS (multicast DNS, port 5353). If your phone/PC is on 5 GHz Wi-Fi and the speaker is on 2.4 GHz, many routers block multicast between bands.

**Fix options (try in order):**
1. Connect phone/PC to the SAME Wi-Fi band as the speaker
2. Enable IGMP Snooping in router admin panel
3. Disable AP Isolation / Client Isolation in router settings
4. If using a mesh system, ensure multicast forwarding is enabled

**Verification:** From PC, run `ping 224.0.0.251` (mDNS multicast address). If no response, multicast is blocked.

## Stage 4: Eureka.conf Patch (Root Cause #1)

**WARNING: This modifies the Cast configuration file. Kill Cast processes first to prevent overwrites.**

### Step 4a: Kill Cast processes
```
killall -9 cast_shell process_manager castlucicomm
```

### Step 4b: Patch .eureka.conf from Windows PowerShell
```
python -c "import subprocess, json; raw = subprocess.check_output(['ssh', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa', 'root@<IP>', 'cat /lsync/data1/chrome/.eureka.conf']); data = json.loads(raw.decode('utf-8')); data['tos-accepted'] = True; data['setup-stats'] = {'num-check-connectivity': 0, 'num-connect-wifi': 0, 'num-connected-wifi-not-saved': 0, 'num-initial-eureka-info': 0, 'num-obtain-ip': 0, 'num-weave-pairing': 0, 'once-reach-connected': 1, 'once-reach-gaia-required': 1}; new_json = json.dumps(data, separators=(',', ':')); p = subprocess.Popen(['ssh', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa', 'root@<IP>', 'cat > /lsync/data1/chrome/.eureka.conf'], stdin=subprocess.PIPE); p.communicate(input=new_json.encode('utf-8')); print('PATCH COMPLETED')"
```
Replace `<IP>` with your speaker IP address.

### Step 4c: Verify
```
cat /lsync/data1/chrome/.eureka.conf | grep -E 'tos-accepted|setup-state'
```
**Expected:** `tos-accepted` = true, `setup-state` = 0 or 60.

### Why this works
After factory reset, `.eureka.conf` lacks `tos-accepted` and `once-reach-*` flags. `cast_shell` checks these on startup and refuses to initialize the Cast receiver if they are missing. The `curl POST` method does NOT work because `cast_shell` overwrites the file from RAM on every cycle.

## Stage 5: Wi-Fi Configuration (Android-Only Method)

If the speaker is in Away mode and you cannot use the RIVA VOICE app or Google Home app for setup:

```
printf 'ctrl_interface=/data/wifi\nupdate_config=1\nnetwork={\n\tssid="%s"\n\tpsk="%s"\n\tkey_mgmt=WPA-PSK\n}\n' "YOUR_SSID" "YOUR_PASSWORD" > /data/wifi/wpa_supplicant.conf && sync
```

Then reboot: `reboot`

**Why standard methods fail:** After the eureka.conf patch, `setup_state` is 60, which prevents the Web UI setup wizard from running. `wpa_cli` is inactive in Away mode. Direct file write is the only reliable method.

## Stage 6: Chrome Binary Sync (Root Cause #2)

**This is the most critical step.** The V8 snapshot mismatch is the main reason mobile Cast streaming fails.

### Option A: Apply Delta Patch (5.5 MB, recommended)

Download `delta-chrome-5files.tar.gz` from GitHub Releases, then from PowerShell:
```
python -c "import subprocess; p = subprocess.Popen(['ssh', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa', 'root@<IP>', 'killall -9 cast_shell process_manager castlucicomm; cd /system/chrome && tar -xzf -'], stdin=open('delta-chrome-5files.tar.gz','rb')); p.communicate(); print('DELTA APPLIED')"
```

### Option B: Full Image Sync (75 MB, from working speaker)

If you have a second working RIVA Festival on the same network:
```
python -c "import subprocess; subprocess.call(['ssh', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa', 'root@<TARGET>', 'killall -9 cast_shell process_manager castlucicomm; rm -rf /system/chrome/* /lsync/data1/chrome/initial_error']); p1 = subprocess.Popen(['ssh', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa', 'root@<SOURCE>', 'cd /system/chrome && tar -cf - .'], stdout=subprocess.PIPE); p2 = subprocess.Popen(['ssh', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa', 'root@<TARGET>', 'cd /system/chrome && tar -xf -'], stdin=p1.stdout); p1.stdout.close(); p2.communicate(); print('FULL SYNC DONE')"
```
Replace `<SOURCE>` with working speaker IP, `<TARGET>` with broken speaker IP.

### Option C: Extract from Cast OTA Package

Download `cast_receiver_signed_1.52at.272222_NEON_GM2.zip` from the OTA server, extract, and copy files from the `cast_ota/` directory to `/system/chrome/` via SSH.

### Why this works
Factory firmware ships with 2017 Chromium binaries (V8 6.2), but the `cast_shell` binary is from 2020 (V8 8.6). The `snapshot_blob.bin` (712 KB, 2017) is incompatible with V8 8.6, causing mobile Cast to crash with 'Version mismatch between V8 binary and snapshot'. PC Cast works because it uses a simpler audio pipeline that avoids V8 snapshot deserialization.

## Stage 7: Post-Sync Permissions Fix and Reboot

**WARNING: Incorrect permissions will prevent Cast from starting.**

```
chmod 755 /system/chrome /system/chrome/cast_shell /system/chrome/cast_cli /system/chrome/process_manager /system/chrome/update_engine
chown root:chrome /system/chrome/chrome-sandbox
chmod 4755 /system/chrome/chrome-sandbox
rm -f /system/chrome/natives_blob.bin
sync && sync && reboot
```

**Key details:**
- `chrome-sandbox` MUST be SUID root (4755) and owned by root:chrome
- `natives_blob.bin` is obsolete in V8 8.6 and MUST be deleted if present
- Use individual `chown` commands, NOT `chown -R` (BusyBox limitation)
- Double `sync` ensures all writes are flushed before reboot

## Stage 8: Cold Boot Verification

After reboot, wait 60-90 seconds, then SSH back in and verify:
```
cat /lsync/data1/chrome/.eureka.conf | grep -E 'tos-accepted|setup-state'
ls -la /system/chrome/snapshot_blob.bin
cat /lsync/data1/chrome/initial_error 2>/dev/null || echo 'No errors'
ps | grep cast_shell
```

**Expected:**
- `tos-accepted` = true
- `snapshot_blob.bin` = 49,927 bytes
- `initial_error` = empty or absent
- `cast_shell` process is running

## Stage 9: Cast Discovery Test

1. Open Chrome on PC -> click three dots -> Cast
2. Speaker should appear in the device list
3. Open YouTube on phone -> tap Cast icon
4. Speaker should appear in the device list

**If not visible:** Return to Stage 3 (network alignment). Check that port 8008 is open: `curl http://<IP>:8008/setup/eureka_info`

## Stage 10: Streaming Test

1. Open SoundCloud on iPhone -> Cast to speaker -> play a track
2. Audio should play from the speaker within 3-5 seconds
3. Open Spotify on phone -> Cast to speaker -> play a track
4. Open YouTube on phone -> Cast a video -> audio from speaker

**If connects but no audio:** V8 snapshot mismatch persists. Re-check Stage 6 file sizes.

## Stage 11: AirPlay Verification

1. Open Music app on iPhone
2. Tap AirPlay icon
3. RIVA Festival should appear in the list
4. Play audio and verify it comes from the speaker

## Stage 12: Spotify Connect Verification

1. Open Spotify on phone (Premium required)
2. Tap Devices Available icon
3. RIVA Festival should appear
4. Select and play

## Stage 13: Multi-Room Test

1. Open RIVA VOICE app
2. Both speakers should be visible
3. Create a multi-room group
4. Play audio and verify synchronized playback

## Stage 14: Persistence Test

1. Unplug the speaker from power
2. Wait 30 seconds
3. Plug back in and wait 90 seconds
4. Repeat Stages 9-10
5. All functionality should persist across reboots

## Stage 15: Documentation and Backup

After successful recovery, create a backup of the working state:
```
python -c "import subprocess; f=open('eureka_backup.json','wb'); subprocess.call(['ssh','-o','HostKeyAlgorithms=+ssh-rsa','-o','PubkeyAcceptedAlgorithms=+ssh-rsa','root@<IP>','cat /lsync/data1/chrome/.eureka.conf'],stdout=f); f.close(); print('Backup saved')"
```

## Quick Reference: Three Root Causes

| # | Problem | Symptom | Fix |
|---|---------|---------|-----|
| 1 | Setup stuck | setup_state=63, tos_accepted=false | Patch .eureka.conf (Stage 4) |
| 2 | V8 mismatch | Mobile Cast no audio, PC works | Sync /system/chrome/ (Stage 6) |
| 3 | mDNS isolation | Speaker invisible in Cast menu | Same Wi-Fi band (Stage 3) |

## Known Pitfalls

- `chown -R` does NOT work on LS9 BusyBox. Use individual `chown` per file.
- `LD_LIBRARY_PATH` is useless. RPATH in cast_shell takes priority.
- `setprop persist.chrome.tos_accepted true` is reset on every boot.
- `curl POST` to set_eureka_info returns 200 but does not persist.
- PowerShell double quotes cause `$(...)` to execute locally. Use Python wrappers.
- `tar -C` on BusyBox only applies to first argument. Use `cd /dir && tar -cf - .`.
- Standard Android setup (Google Home, Web UI) does NOT work after eureka.conf patch.

## Legal Disclaimer

This guide and associated files are intended exclusively for restoration of legally owned RIVA Festival devices. All firmware binaries and software components are property of RIVA Audio, Libre Wireless, and Google LLC. The authors claim no ownership of proprietary software. Use at your own risk.
