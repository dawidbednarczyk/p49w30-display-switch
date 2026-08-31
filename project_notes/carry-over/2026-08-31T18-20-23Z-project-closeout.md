# Carry-over 2026-08-31T18:20:23Z — P49w-30 display-switch closeout
Previous: none

## Goal
No active implementation goal; preserve the accepted final state and exact pending Cisco laptop actions.

## State — verbatim command output

```text
2026-08-31T18:20:23Z
48921d5 fix: activate Mac P49w-30 toggle hotkey
85f775d feat: add safe Windows P49w-30 pane toggle
27d412b Fix stale 'right pane' titles — the laptop toggles the LEFT pane
8f9d7ac eKVM verified: double-Shift works; port diagram; independence ruling
0fea961 Correct pane sides (Mac=right/USB-C, laptop=left HDMI-DP) + document eKVM triggers
7b44244 P49w-30 right-pane switch: standing instructions + implementation guide
main
```

Final hardware checks:

```text
hotkey=true
4401,4401
```

## Done and verified

- User confirmed Ctrl+Command+Shift+D works.
- Live Hammerspoon reports the exact `⌘⌃⇧D` binding enabled.
- Physical transitions `3889 → 4401` and `4401 → 3889` succeeded through BetterDisplay.
- Closeout restored and re-read `4401,4401` (HDMI 1); the 16-bit low byte remains 49.
- Repository contract suite passed five tests before closeout.
- Mac implementation commit `48921d5` was pushed to `origin/main`.

## In flight

None. No background tasks, unread command results, or unverified edited project files.

## Dead ends — do not retry

- The original failure was not a modifier-order issue: the live Hammerspoon configuration had
  no D binding at all. Merely changing documentation cannot activate the shortcut.
- `betterdisplaycli --help`/an incomplete `get` invocation hung. Use the documented complete
  direct-DDC form with `get|set`, `-name=P49w-30`, `-feature=ddc`, and `-vcp=0x60`.
- Reads immediately after a write can return `Failed.` even when the switch succeeded. Do not
  weaken the six-second stable-read guard; wait through the post-switch interval and re-read.

## Decisions and the why

- Ctrl+Command+Shift+D toggles full values `4401 ↔ 3889` → this is the accepted user behavior.
- Only exact full values are valid → preserves the Mac pane's low byte and rejects stale/garbage reads.
- KVM stays independent → the monitor's native physical double-Shift trigger already works; no listener exists.
- The user’s latest physical-layout correction is authoritative → laptop toggle target is documented as the right pane.

## Next action

No project action. If resuming for laptop deployment, start with `STATUS.md` and execute the
six pending Cisco laptop steps in order.

## Open questions for the user

None.
