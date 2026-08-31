# p49w30-display-switch

Lenovo ThinkVision P49w-30 desk setup: switch the PBP **right pane** between HDMI 1 and
DisplayPort by keyboard shortcut, from either machine.

| Machine | Hotkey | State |
|---|---|---|
| Mac mini (left pane, USB-C) | ⌃⇧⌘D (Ctrl+Shift+Cmd+D) | live since 2026-08-31, Hammerspoon |
| Cisco laptop (right pane inputs) | Ctrl+Alt+D | to be implemented by the laptop agent |

- **[CISCO-LAPTOP-INSTRUCTIONS.md](CISCO-LAPTOP-INSTRUCTIONS.md)** — standing rule for the
  laptop agent: switch the pane back to HDMI 1 when done; KVM stays manual for now.
- **[GUIDE.md](GUIDE.md)** — full implementation guide: the 16-bit VCP 0x60 mechanism,
  ControlMyMonitor commands, AutoHotkey v2 script, acceptance test.

Mechanism in one line: VCP 0x60 is 16-bit — low byte = left pane (Mac, always `49`), high
byte = right pane (`0x0F` DisplayPort / `0x11` HDMI 1) — toggle via read-modify-write
(`4401` = right HDMI 1, `3889` = right DisplayPort).

KVM is out of scope: verified not DDC-controllable on this monitor (2026-08-31).
