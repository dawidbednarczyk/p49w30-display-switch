# ThinkVision P49w-30 — switch the PBP right pane from the Cisco laptop (Windows)

**For:** the agent on Dawid's Cisco laptop. **From:** master-manager (Mac mini), 2026-08-31.
**Goal:** a keyboard shortcut on the laptop that toggles the monitor's RIGHT PBP pane between
**HDMI 1** and **DisplayPort** — same behavior as the Mac mini's ⌃⇧⌘D shortcut (already live; D = display).
Pressing it must always end with **DisplayPort on the right pane** when toggled from HDMI 1.

## The mechanism (empirically verified on this exact monitor, not from documentation)

The monitor is a Lenovo ThinkVision P49w-30 running PBP. Its DDC/CI **VCP code 0x60** (Input
Source) is **16-bit** on this model — this is the trap that breaks every standard tool:

| byte | meaning | values seen |
|------|---------|-------------|
| **low byte** | LEFT pane = Mac mini via USB-C | `49` (0x31) — **always preserve, never write anything else here** |
| **high byte** | RIGHT pane | `0x0F` (15) = DisplayPort 1 · `0x11` (17) = HDMI 1 |

Verified full values: **4401** = right pane HDMI 1 · **3889** = right pane DisplayPort.
An 8-bit write (what normal tools send) lands in the low byte and clobbers the Mac's pane.

**Toggle logic (mandatory read-modify-write):**
read 0x60 → keep `low = v % 256` → flip `high`: 0x11→0x0F or 0x0F→0x11 → write `low + high*256`.

## Windows implementation

Tools (both free, no install order dependency):
1. **ControlMyMonitor** (NirSoft) — DDC CLI. Put it e.g. in `C:\Tools\ControlMyMonitor\`.
2. **AutoHotkey v2** — for the hotkey.

Commands (verify in cmd.exe first):
```
ControlMyMonitor.exe /MonitorEnum                       :: find the monitor name; "Primary" usually works
ControlMyMonitor.exe /GetValueValue Primary 60 /stext %TEMP%\ddc60.txt   :: read — expect 4401 or 3889
ControlMyMonitor.exe /SetValue Primary 60 3889          :: right pane -> DisplayPort
ControlMyMonitor.exe /SetValue Primary 60 4401          :: right pane -> HDMI 1
```

AutoHotkey v2 script (Ctrl+Alt+D — Windows has no Command key; this mirrors the Mac's ⌃⇧⌘D):
```ahk
#Requires AutoHotkey v2.0
CMM := "C:\Tools\ControlMyMonitor\ControlMyMonitor.exe"   ; adjust path
tmp := A_Temp "\ddc60.txt"

^!d:: {
    RunWait('"' CMM '" /GetValueValue Primary 60 /stext "' tmp '"', , "Hide")
    v := 0
    if RegExMatch(FileRead(tmp), "\b(\d{3,5})\b", &m)
        v := Integer(m[1])
    if (v < 256) {
        TrayTip("PBP toggle", "Bad DDC read (" v ") — retry in ~5s", 2)
        return
    }
    lo := Mod(v, 256), hi := Floor(v / 256)
    newHi := (hi = 0x0F) ? 0x11 : 0x0F
    RunWait('"' CMM '" /SetValue Primary 60 ' (lo + newHi * 256), , "Hide")
    TrayTip("PBP toggle", (newHi = 0x0F) ? "Right pane → DisplayPort" : "Right pane → HDMI 1", 2)
}
```
Add the script to shell:startup so the hotkey survives reboots.

## Caveats (all observed on the real setup)
- DDC commands travel over the laptop's own cable and work **regardless of which input the
  pane is currently showing** — the toggle works from either machine, any state.
- For ~5 s after a switch, reads return 0/garbage — that's why the script retries-protects.
- DDC/CI must stay enabled in the monitor OSD (it is today; a 10 s hold on OSD-exit toggles it).
- If "Primary" targets the wrong display (a second monitor is attached at the Mac desk),
  use the exact monitor name from `/MonitorEnum`.

## Acceptance test
1. `GetValueValue 60` returns 4401 or 3889.
2. Toggle → right pane visibly switches within ~2 s.
3. Re-read after 5 s → value matches the new state.
4. Left pane (Mac mini) never changes. If it ever does: STOP — the write was 8-bit; re-check
   the script uses `lo + newHi*256`.
