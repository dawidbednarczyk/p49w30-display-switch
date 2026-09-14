# Carry-over 2026-09-02T18:15:00Z — P49w-30 DDC corruption recovery

Previous: [2026-08-31T18-20-23Z-project-closeout.md](2026-08-31T18-20-23Z-project-closeout.md)

## Goal

Diagnose and recover from a broken pane-switch state where Mac mini appeared stuck on the left
half and ⌃⌘⇧D stopped working.

## State at investigation

```text
betterdisplaycli get -name="P49w-30" -feature=ddc -vcp=0x60 -value
3857
```

Decoded: low byte **17** (should be **49** for Mac USB-C), high byte **15** (DisplayPort).
Classic 8-bit write corruption — the safety script correctly rejected toggles.

## Recovery performed

```bash
/opt/homebrew/bin/betterdisplaycli set -name="P49w-30" -feature=ddc -vcp=0x60 -value=4401
# re-read after settle → 4401,4401
```

Post-status-save re-read: `3889` (user or hotkey toggled right pane to DisplayPort; low byte OK).

## Done and verified

- Root cause identified: corrupted 16-bit VCP value, not a Hammerspoon/BetterDisplay outage.
- Hammerspoon and BetterDisplay were running; `~/.hammerspoon/init.lua` loads the repo module.
- Manual restore to `4401` succeeded; hotkey safety contract behaved as designed.
- `STATUS.md` updated with incident, recovery command, and current state.

## Dead ends — do not retry

- Do not weaken the exact-value guard to accept `3857` or other corrupted reads.
- Do not use 8-bit ControlMyMonitor/BetterDisplay writes to VCP `0x60`.
- Pane toggle (⌃⌘⇧D) and KVM (double-Shift) remain independent — do not re-couple.

## Next action

- When done with DisplayPort session, toggle back to HDMI 1 (`4401`) via ⌃⌘⇧D or emergency
  `betterdisplaycli set … -value=4401`.
- Cisco laptop install steps in `STATUS.md` remain pending when that machine is in scope.

## Open questions for the user

- What tool or manual step produced the `3857` corruption? (Likely an 8-bit DDC experiment
  during troubleshooting — not yet confirmed.)
