# RIVA Festival Recovery Project — DNA

## 1. Project Identity
- **Repository:** riva-festival-recovery (GitHub)
- **Purpose:** Restore full functionality to RIVA Festival smart speakers with broken Google Cast, including mobile streaming (SoundCloud, Spotify, YouTube from phones)
- **Author:** Community reverse-engineering effort, acknowledged by RIVA Audio engineering (Dylan, technical engineer)
- **License:** Recovery tools and documentation are MIT. All firmware binaries belong to RIVA Audio / Libre Wireless / Google LLC.

## 2. Device Profile
- **Product:** RIVA Festival (smart speaker, 2018)
- **SoC:** Libre Wireless LS9 (ARM Cortex-A7, quad-core)
- **OS:** Embedded Linux (Buildroot-based), kernel 3.10.x
- **Shell:** BusyBox 1.24.1 (limited command set — NO chattr, NO chown -R, NO find -exec)
- **Cast Stack:** Chromium-based cast_shell (V8 engine), process_manager, castlucicomm
- **Cast Port:** 8008 (HTTP), 8009 (HTTPS)
- **mDNS:** Avahi (port 5353)
- **Audio:** ALSA, multi-room via RIVA VOICE app
- **Streaming Protocols:** Google Cast, AirPlay (Shairport), Spotify Connect, DLNA
- **SSH Access:** ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa root@<IP> (password: empty)
- **Key Paths:**
  - /system/chrome/ — Cast binaries and libraries
  - /system/oem_cast_shlib/ — OEM Cast shared libraries (dummy stubs on LS9)
  - /lsync/data1/chrome/.eureka.conf — Cast configuration (JSON)
  - /lsync/data1/chrome/initial_error — error log from cast_shell startup
  - /data/wifi/wpa_supplicant.conf — Wi-Fi credentials
  - /oem_cast_shlib/ — symlink target for RPATH resolution

## 3. Problem History
1. Speaker factory-reset or firmware-reflashed then Cast stops working
2. Standard recovery (RIVA VOICE app, Google Home app) fails to restore Cast
3. Custom firmware p15647 (from Dylan/RIVA) partially fixes Cast: PC audio works, mobile streaming crashes
4. Root cause analysis revealed THREE independent problems (see below)
5. Full fix requires: config patch + binary sync + network alignment

## 4. Three Root Causes (CRITICAL)

### Root Cause #1: Setup State Stuck at 63
- **Symptom:** setup_state=63, tos_accepted=false in .eureka.conf
- **Cause:** After reset/reflash, .eureka.conf lacks tos-accepted and once-reach-* flags. cast_shell refuses to start Cast service.
- **Fix:** Kill Cast processes, patch .eureka.conf via Python/JSON, reboot.
- **Key detail:** curl POST to set_eureka_info does NOT persist because cast_shell overwrites from RAM. Must edit file directly with processes killed.

### Root Cause #2: V8 Snapshot Mismatch (THE MAIN BUG)
- **Symptom:** Mobile Cast connects but no audio. Logcat: Version mismatch between V8 binary and snapshot 8.6.395.52 vs 6.2.414.46
- **Cause:** Factory firmware ships with 2017 Chromium binaries (V8 6.2), but cast_shell binary is 2020 (V8 8.6). snapshot_blob.bin (712,032 bytes, 2017) is incompatible. Also: chrome-sandbox is 722,964 bytes (2017) vs correct 22,176 bytes (2020). icudtl.dat is missing entirely. cast_shell.pak is in wrong location (root vs assets/).
- **Fix:** Full binary sync of /system/chrome/ from a working speaker, or apply delta patch with 5 critical file categories.
- **Why PC worked but mobile did not:** PC Cast uses simpler audio pipeline that does not trigger V8 snapshot deserialization. Mobile Cast (SoundCloud, YouTube) uses V8 for media session handling, which crashes on mismatch.

### Root Cause #3: mDNS Multicast Isolation
- **Symptom:** Speaker not visible in Chrome/YouTube Cast menu despite port 8008 being open
- **Cause:** Router isolates multicast traffic between 2.4 GHz and 5 GHz Wi-Fi bands
- **Fix:** Connect all devices to same band, or enable IGMP Snooping on router

## 5. Critical File Sizes (Working Speaker)

| File | Correct Size | Broken Size | Notes |
|------|-------------|-------------|-------|
| snapshot_blob.bin | 49,927 | 712,032 | V8 snapshot, MUST match cast_shell |
| icudtl.dat | 5,049,344 | missing | Unicode tables |
| chrome-sandbox | 22,176 | 722,964 | SUID binary |
| cast_shell.pak | 5,210,730 (in assets/) | 4,461,819 (in root) | UI resources |
| cast_shell | 57,652,528 | varies | Main binary |
| process_manager | 369,976 | varies | Process supervisor |
| natives_blob.bin | absent | 394,778 | Obsolete in V8 8.6, DELETE if present |
| chromecast_locales/ | 106 files (~1.1 MB) | missing | 53 languages x 2 files each |

## 6. Key Commands

### SSH Connection
ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa root@<IP>
Password: empty (press Enter).

### Kill Cast Processes
killall -9 cast_shell process_manager castlucicomm

### Eureka.conf Patch (Python from Windows PowerShell)
python -c "import subprocess, json; raw = subprocess.check_output(['ssh', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa', 'root@<IP>', 'cat /lsync/data1/chrome/.eureka.conf']); data = json.loads(raw.decode('utf-8')); data['tos-accepted'] = True; data['setup-stats'] = {'num-check-connectivity': 0, 'num-connect-wifi': 0, 'num-connected-wifi-not-saved': 0, 'num-initial-eureka-info': 0, 'num-obtain-ip': 0, 'num-weave-pairing': 0, 'once-reach-connected': 1, 'once-reach-gaia-required': 1}; new_json = json.dumps(data, separators=(',', ':')); p = subprocess.Popen(['ssh', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa', 'root@<IP>', 'cat > /lsync/data1/chrome/.eureka.conf'], stdin=subprocess.PIPE); p.communicate(input=new_json.encode('utf-8')); print('PATCH COMPLETED')"

### Full Chrome Sync (speaker-to-speaker via PC relay)
python -c "import subprocess; subprocess.call(['ssh', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa', 'root@<TARGET>', 'killall -9 cast_shell process_manager castlucicomm; rm -rf /system/chrome/* /lsync/data1/chrome/initial_error']); p1 = subprocess.Popen(['ssh', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa', 'root@<SOURCE>', 'cd /system/chrome && tar -cf - .'], stdout=subprocess.PIPE); p2 = subprocess.Popen(['ssh', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa', 'root@<TARGET>', 'cd /system/chrome && tar -xf -'], stdin=p1.stdout); p1.stdout.close(); p2.communicate(); subprocess.call(['ssh', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa', 'root@<TARGET>', 'chmod 755 /system/chrome /system/chrome/cast_shell /system/chrome/cast_cli /system/chrome/process_manager /system/chrome/update_engine; chown root:chrome /system/chrome/chrome-sandbox && chmod 4755 /system/chrome/chrome-sandbox; sync && sync && reboot'])"

### Android-Only Wi-Fi Setup (Away mode, SSH)
printf 'ctrl_interface=/data/wifi\nupdate_config=1\nnetwork={\n\tssid="%s"\n\tpsk="%s"\n\tkey_mgmt=WPA-PSK\n}\n' "SSID" "PASSWORD" > /data/wifi/wpa_supplicant.conf && sync

### Apply Delta Patch from PC
python -c "import subprocess; p1 = subprocess.Popen(['tar', '-xzf', 'delta-chrome-5files.tar.gz', '-C', '.'], stdout=subprocess.PIPE); p2 = subprocess.Popen(['ssh', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa', 'root@<IP>', 'cd /system/chrome && tar -xzf -'], stdin=p1.stdout); p2.communicate()"

## 7. Known Pitfalls
- chown -R does NOT work on LS9 BusyBox — gives "No such user '-R'". Use individual chown per file.
- LD_LIBRARY_PATH is useless because cast_shell has RPATH /oem_cast_shlib:$ORIGIN/lib:$ORIGIN which takes priority. Dummy libs in /system/oem_cast_shlib/ always load first.
- chmod 666 /dev/socket/wpa_wlan0 does not fix wpa_supplicant — it checks peer UID/GID credentials, not file permissions.
- PowerShell double-quote escaping causes $(pgrep ...) to execute locally on Windows. Use single quotes or Python subprocess wrappers.
- tar -C flag on BusyBox only applies to the first argument. Use cd /dir && tar -cf - . instead.
- setprop persist.chrome.tos_accepted true is reset to false by cast_shell on every boot.
- curl POST to set_eureka_info returns 200 but does not persist — cast_shell overwrites from RAM.
- Standard Android setup (Google Home app, Web UI in Away, wpa_cli) does NOT work after manual .eureka.conf patch because setup_state=60 prevents re-setup.

## 8. Firmware Distribution Strategy (Three Levels)

### Level A — OTA Download (Fully Legal)
Script downloads from public server:
- http://dev.hansong-china.com/OTA/Riva/Festival/83_IMAGE_NETWORK (~36 MB, SHA256 6F144E99...)
- http://dev.hansong-china.com/OTA/Riva/Festival/cast_receiver_signed_1.52at.272222_NEON_GM2.zip (~43 MB, SHA256 7E13F477...)

### Level B — Delta Patch (5.5 MB)
Only files that differ from factory and are NOT in Cast OTA:
- snapshot_blob.bin (49,927 bytes)
- icudtl.dat (5,049,344 bytes)
- chrome-sandbox (22,176 bytes)
- assets/cast_shell.pak (5,210,730 bytes)
- chromecast_locales/ (106 files, ~1.1 MB)
File: delta-chrome-5files.tar.gz

### Level C — Full Image (75.2 MB)
Complete /system/chrome/ tar archive. GitHub Release only.
File: riva-festival-chrome-full.tar
Disclaimer: For restoration of legally owned RIVA Festival devices only. All rights belong to RIVA Audio / Libre Wireless / Google LLC.

## 9. Network Topology (Reference)
- Defective speaker (recovered): 192.168.0.102, SSID Home (2.4 GHz)
- Healthy speaker: 192.168.0.103, SSID Home_5G (5 GHz)
- Both IPs DHCP-reserved in router
- mDNS requires same Wi-Fi band or IGMP Snooping enabled

## 10. Recovery Workflow Summary (15 Stages)
1. SSH access verification
2. Diagnostic data collection (.eureka.conf, initial_error, file sizes)
3. Network alignment (same Wi-Fi band)
4. [NEW] Eureka.conf patch (Python, kill processes first)
5. Wi-Fi configuration (Android: write wpa_supplicant.conf via SSH)
6. [NEW] Chrome binary sync (full or delta)
7. [NEW] Post-sync permissions fix and reboot
8. Cold boot verification
9. Cast discovery test (Chrome, YouTube, mobile)
10. Streaming test (SoundCloud, Spotify)
11. AirPlay verification
12. Spotify Connect verification
13. Multi-room test (RIVA VOICE app)
14. Persistence test (power cycle, 24h)
15. Documentation and backup

## 11. Contacts and References
- **Dylan** — RIVA Audio technical engineer (acknowledged this work, forwarding to engineering team)
- **OTA Server:** http://dev.hansong-china.com/OTA/Riva/Festival/
- **RIVA VOICE App:** iOS/Android, used for initial setup and multi-room
- **Libre Wireless LS9 SDK:** Proprietary, not publicly available
