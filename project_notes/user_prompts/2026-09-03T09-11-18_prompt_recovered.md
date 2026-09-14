# User Prompt (recovered from transcript) — 2026-09-03T09-11-18

**Session**: 11e4c54c-5e83-4c6e-9591-c67011f67c37
**Source**: Cursor stop-hook transcript-sweep

---

User report (2026-09-03): Mac mini screen-switch regression.

**Symptom:** When Dawid undocks/unplugs the Cisco laptop, the Mac mini takes over the LEFT pane of the P49w-30. After that the Mac mini STAYS permanently on the left screen — it never returns to the RIGHT screen. The existing hotkey/command only toggles laptop-pane inputs; it does NOT detect or correct this Mac-mini-left stuck state.

**Required fix:** Update the Mac-side command (Hammerspoon + BetterDisplay CLI — see P49w30DisplaySwitch.lua, STATUS.md, GUIDE.md) so it ALWAYS:
1. Reads current VCP 0x60 and validates both bytes (low=Mac pane, high=laptop pane — see STATUS.md corruption table).
2. Detects the bad state: Mac mini stuck on LEFT when it should be on RIGHT (user expectation: Mac mini belongs on RIGHT pane; laptop on LEFT when docked).
3. Auto-corrects that state — not just blind HDMI1/DP toggle of the laptop high byte.
4. Still preserves all existing safety interlocks (16-bit only, known values 4401/3889, 6s stable read, refuse corrupted low byte ≠ 49).

**Also:** Re-test after fix with hardware read (`betterdisplaycli get -name=P49w-30 -feature=ddc -vcp=0x60 -value`). Update STATUS.md with root cause + fix. Ship working hotkey.

Autonomy: implement + test without asking. This is a repeat incident class (see 2026-09-02 DDC corruption recovery in STATUS.md).
