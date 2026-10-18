---
name: ❓ Help Request (Need guidance)
about: Ask a question if you are stuck at a specific stage or unsure about the next steps.
title: "[Help] "
labels: help-wanted, question
assignees: ''
---

**Where are you stuck?**
(e.g., "Cannot connect via SSH", "Stage 4 gives a JSON error", "Unsure how to download the delta patch")

**Error output or command**
If you have an error, run the command and paste the result here:

# Paste your error or command output here

**What have you already tried?**
Describe your actions so we don't suggest things you've already checked.

**Network Context**
- Is the speaker connected to 2.4 GHz or 5 GHz Wi-Fi?
- Are you using a Mesh system or a complex router (client isolation might be active)?

**Important Reminder**
Remember that the RIVA Festival runs on BusyBox 1.24.1.
- DO NOT use `chown -R` (it will fail with "No such user").
- DO NOT use `systemctl` or `chattr`.
- Always use individual commands as specified in the Recovery Guide.