# p49w30-display-switch

Lenovo ThinkVision P49w-30 desk setup: switch the laptop's PBP **left pane** between HDMI 1
and DisplayPort by keyboard shortcut, from either machine.

| Machine | Hotkey | State |
|---|---|---|
| Mac mini (right pane, USB-C) | ⌃⇧⌘D (Ctrl+Shift+Cmd+D) | live since 2026-08-31, Hammerspoon |
| Cisco laptop (left pane, HDMI 1 ↔ DisplayPort) | Ctrl+Alt+D | to be implemented by the laptop agent |

- **[CISCO-LAPTOP-INSTRUCTIONS.md](CISCO-LAPTOP-INSTRUCTIONS.md)** — standing rule for the
  laptop agent: switch the pane back to HDMI 1 when done; KVM stays manual for now.
- **[GUIDE.md](GUIDE.md)** — full implementation guide: the 16-bit VCP 0x60 mechanism,
  ControlMyMonitor commands, AutoHotkey v2 script, acceptance test.

Mechanism in one line: VCP 0x60 is 16-bit — low byte = the Mac's USB-C input (always `49`,
right half), high byte = the laptop's input (`0x0F` DisplayPort / `0x11` HDMI 1, left half)
— toggle via read-modify-write (`4401` = laptop HDMI 1, `3889` = laptop DisplayPort).

KVM: **solved natively — double-tap Shift within 0.5 s** (the monitor's eKVM trigger,
verified working 2026-08-31). Not DDC-controllable; pane shortcuts and KVM are deliberately
independent (Dawid's ruling 31.08). Rear-port diagram + which port is the eKVM port:
[GUIDE.md](GUIDE.md) · [images/p49w30-rear-ports.png](images/p49w30-rear-ports.png).
