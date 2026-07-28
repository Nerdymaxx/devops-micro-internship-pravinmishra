---
name: linux-triage
description: Runs the read-only Linux & Nginx health-check script and explains the results — service status, port, HTTP response, disk usage, and system load. Use for /linux-triage.
allowed-tools: Bash, Read, Grep
disable-model-invocation: true
---

# Linux Triage Skill

This skill gathers read-only evidence about this server's health and explains it. It
never modifies system state and never has file-write access.

## What to do

1. Run `bash scripts/linux-triage.sh reports/<label>-report.txt`, where `<label>`
   reflects the situation (e.g. `healthy`, `incident-failure`, `recovery`). If the user
   doesn't specify a label, default to `reports/linux-triage-report.txt`.
2. Read the report you just produced with `Read` (or `grep` specific lines with `Grep`
   if you only need to check one check's result — don't read files you didn't just
   generate).
3. Report back:
   - **Overall status** (HEALTHY / WARN / FAIL), quoted directly from the report.
   - **Evidence for every failed or warning check**, quoted directly from the report —
     never paraphrase the evidence away from what the report actually says.
   - **Most likely cause**, reasoned only from the evidence above.
   - **Suggested recovery command**, presented as text for the human to review and run
     themselves. Never execute it.

## Safety Rules

- No `Write` tool access — this skill cannot create, edit, or delete files. The triage
  script itself writes the report; the skill only reads it back.
- Never run a command that changes system state (no `systemctl start/stop/restart`,
  no `rm`, no config edits, no `sudo`). Only the triage script and other read-only
  commands (`cat`, `grep`, `ls`) may be run.
- Never claim a cause the evidence doesn't support. If the evidence is inconclusive,
  say so explicitly instead of guessing.
- `disable-model-invocation: true` means this skill only runs when a human explicitly
  invokes `/linux-triage` — Claude will not decide on its own to run a health check or
  "fix" something proactively.
