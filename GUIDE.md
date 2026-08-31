# ThinkVision P49w-30 — PBP input switch + eKVM triggers (Cisco laptop, Windows)

**For:** the agent on Dawid's Cisco laptop. **From:** master-manager (Mac mini), 2026-08-31.
**Goal:** a keyboard shortcut on the laptop that toggles its PBP pane between **HDMI 1** and
**DisplayPort** — the mirror of the Mac mini's ⌃⇧⌘D shortcut (live and verified).

## Layout (as physically arranged)

- **Right half = Mac mini**, fed by USB-C (input value `49` / 0x31). This pane must NEVER change.
- **Left half = Cisco laptop**, fed by HDMI 1 (home) or DisplayPort — both cables from the laptop side.

## The mechanism (empirically verified on this exact monitor, not from documentation)

DDC/CI **VCP code 0x60** (Input Source) is **16-bit** on this model — this is the trap that
breaks every standard tool:

| byte | meaning | values |
|------|---------|--------|
| **low byte** | the **Mac mini USB-C input** (right half) | `49` (0x31) — **always preserve, never write anything else here** |
| **high byte** | the **laptop input** (left half) | `0x0F` (15) = DisplayPort 1 · `0x11` (17) = HDMI 1 |

Verified full values: **4401** = laptop on HDMI 1 (home) · **3889** = laptop on DisplayPort.
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
ControlMyMonitor.exe /SetValue Primary 60 3889          :: laptop pane -> DisplayPort
ControlMyMonitor.exe /SetValue Primary 60 4401          :: laptop pane -> HDMI 1
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
    TrayTip("PBP toggle", (newHi = 0x0F) ? "Laptop pane → DisplayPort" : "Laptop pane → HDMI 1", 2)
}
```
Add the script to shell:startup so the hotkey survives reboots.

## Caveats (all observed on the real setup)
- DDC commands travel over the machine's own video cable and work **regardless of which
  input the pane is currently showing** — the toggle works from either machine, any state.
- For ~5 s after a switch, reads return 0/garbage — that's why the script retries-protects.
- DDC/CI must stay enabled in the monitor OSD (it is today; a 10 s hold on OSD-exit toggles it).
- If "Primary" targets the wrong display, use the exact monitor name from `/MonitorEnum`.

## eKVM — how KVM switching actually works on this monitor

**There is no mouse-edge/screen-roaming switching.** Per the Lenovo documentation the eKVM
triggers are:
1. **Double-tap Shift within 0.5 s** (enable: OSD → Port Settings → KVM Setting → eKVM → Keyboard On)
2. **Hold both mouse buttons (left+right) for 3 s** (enable: same menu → Mouse On)

Requirements from the manual:
- KVM enabled in OSD → Port Settings → **KVM Setting**. **KVM On = switches USB *and* video
  together; KVM Off = USB only.**
- Mouse/keyboard must be plugged into **the specific USB port(s) on the back of the monitor**
  designated for eKVM detection (check the port labels; "functionality may vary depending on
  brands of the mouse").
- Both upstream cables connected: USB-C (Mac mini) and USB-B (laptop).

**Status 31.08: triggers not yet verified on this unit.** Once verified, the laptop side
should ALSO implement Shift-double-tap synthesis (AHK: `Send +{Shift}` twice, < 0.5 s apart)
so either machine can hand keyboard+mouse to the other with one shortcut. Do not build this
until Dawid confirms the manual triggers work by hand.

## Acceptance test (pane toggle)
1. `GetValueValue 60` returns 4401 or 3889.
2. Toggle → laptop pane visibly switches within ~2 s.
3. Re-read after 5 s → value matches the new state.
4. The Mac pane (USB-C) never changes. If it ever does: STOP — the write was 8-bit; re-check
   the script uses `lo + newHi*256`.
