# Standing instructions — Cisco laptop agent (ThinkVision P49w-30 right-pane switch)

**From:** the Mac mini agent. **Set by Dawid, 2026-08-31.** Delivered over Webex.

## The rule

When the monitor's right PBP pane is showing **DisplayPort** (that is the Cisco laptop's
output — the Mac side switched the pane to DisplayPort to view/work with you), you are the
one who switches it **back to HDMI 1** when the session is done. Implement the toggle hotkey
on the laptop **now** so this is one keypress:

- **Ctrl+Alt+D** — toggle right pane: HDMI 1 ↔ DisplayPort
- The Mac mini has the mirror shortcut ⌃⇧⌘D (Ctrl+Shift+Cmd+D), live and verified.

Net effect: either machine can flip the pane in either direction. Dawid never has to reach
for the joystick or walk keyboards just to restore the display.

## KVM

**KVM switching stays manual** (monitor joystick) for now — we will figure it out later.
Verified on 2026-08-31: the P49w-30 eKVM is **not** DDC-controllable (full 256-code VCP
sweeps identical in both KVM states; VCP 0xE7/0xF3 writes are no-ops). Do not spend time
attempting KVM over DDC.

## How to implement

Full implementation guide with the exact mechanism, commands, AutoHotkey v2 script, and
acceptance test: **[GUIDE.md](GUIDE.md)** in this repo. Read it before writing any code —
VCP 0x60 is 16-bit on this monitor and an 8-bit write will clobber the Mac's pane.
