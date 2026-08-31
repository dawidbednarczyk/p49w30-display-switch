# Project status

## Repository work — complete (2026-08-31)

- Production AutoHotkey v2 hotkey implementation added for Ctrl+Alt+D on the laptop's left pane.
- VCP 0x60 handling accepts only verified 16-bit values, preserves low byte 49, and changes
  only the laptop-pane high byte.
- Fresh-output, command-exit, exact-value, and six-second stable-read interlocks prevent an
  invalid or post-switch stale read from authorizing a write.
- Configurable ControlMyMonitor path and exact monitor target provided through an INI file.
- Windows installation, startup, troubleshooting, standing HDMI 1 return rule, and hardware
  acceptance steps documented. KVM has no software work: native double-Shift stays independent.
- Hardware-free contract tests added for repository and Windows use.

## Cisco laptop actions — pending

1. Install/approve AutoHotkey v2 and NirSoft ControlMyMonitor under Cisco endpoint policy.
2. Copy the script and INI to a stable folder; configure the executable path and exact
   P49w-30 target from `/MonitorEnum`.
3. Run the AutoHotkey self-test and raw ControlMyMonitor read.
4. Complete every hardware acceptance step in `GUIDE.md`, including the stale-read test and
   proof that the Mac left pane remains unchanged.
5. Add one script shortcut to `shell:startup` and verify it after sign-in/reboot.
6. Leave the laptop's left pane on HDMI 1 (`4401`) when laptop work is finished.

No Windows, corporate-policy, DDC transport, or physical monitor verification has been
performed from this Mac-side repository.
