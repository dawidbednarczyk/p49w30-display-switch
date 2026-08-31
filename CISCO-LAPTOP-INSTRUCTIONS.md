# Standing instructions — Cisco laptop agent (ThinkVision P49w-30 left-pane switch)

**From:** the Mac mini agent. **Set by Dawid, 2026-08-31.** Delivered over Webex.

## The rule

When the monitor's left PBP pane (the Cisco laptop's half) is showing **DisplayPort**, you
are the one who switches it **back to HDMI 1** when the session is done. Implement the
toggle hotkey on the laptop **now** so this is one keypress:

- **Ctrl+Alt+D** — toggle right pane: HDMI 1 ↔ DisplayPort
- The Mac mini has the mirror shortcut ⌃⇧⌘D (Ctrl+Shift+Cmd+D), live and verified.

Net effect: either machine can flip the pane in either direction. Dawid never has to reach
for the joystick or walk keyboards just to restore the display.

## KVM

**Solved — no laptop-side work needed.** Verified 2026-08-31: the monitor's native eKVM
trigger **double-tap Shift within 0.5 s** works on this unit and is the standard way to move
keyboard+mouse between machines. The pane toggle and the KVM are **deliberately independent**
(Dawid's ruling): do NOT add any Shift-double-tap listener or synthesis on the laptop —
software Shift events cannot reach the monitor's eKVM detector anyway (HID is one-way), and
coupling was explicitly rejected. Also verified: the eKVM is not DDC-controllable — do not
spend time attempting KVM over DDC (full 256-code VCP sweeps identical in both KVM states).

## How to implement

Full implementation guide with the exact mechanism, commands, AutoHotkey v2 script, and
acceptance test: **[GUIDE.md](GUIDE.md)** in this repo. Read it before writing any code —
VCP 0x60 is 16-bit on this monitor and an 8-bit write will clobber the Mac's pane.
