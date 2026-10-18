---
name: 🐛 Bug Report (Cast is broken)
about: Report a problem if the Recovery Guide instructions didn't help or something went wrong.
title: "[Bug] "
labels: bug, needs-triage
assignees: ''
---

**Describe the bug**
A clear and concise description of what the bug is (e.g., "Visible in Cast menu, but no audio when streaming from phone" or "cast_shell crashes immediately after start").

**Diagnostic Data (MANDATORY)**
Please connect via SSH and run the following commands. Paste the output in the code block below:

cat /lsync/data1/chrome/.eureka.conf | grep -E 'setup-state|tos-accepted'
ls -la /system/chrome/snapshot_blob.bin /system/chrome/icudtl.dat /system/chrome/chrome-sandbox
cat /lsync/data1/chrome/initial_error

**Steps Taken**
Check the stages you completed from the Recovery Guide v2.0:
- [ ] Stage 3: Verified phone/PC and speaker are on the same Wi-Fi network (and same 2.4/5 GHz band).
- [ ] Stage 4: Applied patch to .eureka.conf (killed processes beforehand).
- [ ] Stage 6: Applied delta patch or fully synced /system/chrome/.
- [ ] Stage 7: Checked permissions (chmod 4755 for chrome-sandbox) and rebooted.

**Additional context**
- Device model: RIVA Festival
- Firmware version (if known): 
- Any other details: 