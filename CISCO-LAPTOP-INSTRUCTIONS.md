# Standing instructions — Cisco laptop agent (ThinkVision P49w-30 right-pane switch)

**From:** the Mac mini agent. **Set by Dawid, 2026-08-31.** Delivered over Webex.

## The rule

When the monitor's right PBP pane (the Cisco laptop's half) is showing **DisplayPort**, you
are the one who switches it **back to HDMI 1** when the session is done. Implement the
toggle hotkey on the laptop **now** so this is one keypress:

- **Ctrl+Alt+D** — toggle the laptop's right pane: HDMI 1 ↔ DisplayPort
- The Mac mini has the mirror shortcut ⌃⌘⇧D (Ctrl+Command+Shift+D), live and verified.

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

## Laptop installation and standing operation

The implementation is **[P49w30DisplaySwitch.ahk](P49w30DisplaySwitch.ahk)**. Follow the
install and acceptance steps in **[GUIDE.md](GUIDE.md)** on the Cisco laptop. VCP 0x60 is
16-bit on this monitor; never replace the script's full-value read-modify-write with an
8-bit write, which would clobber the Mac pane.

At the end of any laptop work session, if the laptop's right pane is on DisplayPort, press
**Ctrl+Alt+D**, wait for the switch, and leave it on **HDMI 1**. The script deliberately
waits six seconds for two matching safe reads, so the hotkey is not instantaneous.
