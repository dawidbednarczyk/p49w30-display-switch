# ThinkVision P49w-30 — PBP input switch + eKVM triggers (Cisco laptop, Windows)

**For:** the agent on Dawid's Cisco laptop. **From:** master-manager (Mac mini), 2026-08-31.
**Goal:** a keyboard shortcut on the laptop that toggles its PBP pane between **HDMI 1** and
**DisplayPort** — the mirror of the Mac mini's ⌃⇧⌘D shortcut (live and verified).

## Layout (as physically arranged)

- **Left half = Mac mini**, fed by USB-C (input value `49` / 0x31). This pane must NEVER change.
- **Right half = Cisco laptop**, fed by HDMI 1 (home) or DisplayPort — both cables from the laptop side.

## The mechanism (empirically verified on this exact monitor, not from documentation)

DDC/CI **VCP code 0x60** (Input Source) is **16-bit** on this model — this is the trap that
breaks every standard tool:

| byte | meaning | values |
|------|---------|--------|
| **low byte** | the **Mac mini USB-C input** (left half) | `49` (0x31) — **always preserve, never write anything else here** |
| **high byte** | the **laptop input** (right half) | `0x0F` (15) = DisplayPort 1 · `0x11` (17) = HDMI 1 |

Verified full values: **4401** = laptop on HDMI 1 (home) · **3889** = laptop on DisplayPort.
An 8-bit write (what normal tools send) lands in the low byte and clobbers the Mac's pane.

**Toggle logic (mandatory read-modify-write):**
read 0x60 → keep `low = v % 256` → flip `high`: 0x11→0x0F or 0x0F→0x11 → write `low + high*256`.

## Mac mini hotkey

`P49w30DisplaySwitch.lua` binds **Ctrl+Command+Shift+D** in Hammerspoon and uses the
installed BetterDisplay CLI to read and write VCP `0x60`. It applies the same safety
contract as the Windows implementation: only `4401`/`3889` are accepted, two identical
reads six seconds apart are required, and the low byte is preserved.

The live Hammerspoon configuration loads the repository module directly. BetterDisplay must
remain running with CLI integration enabled. The binding and both hardware transitions were
verified on the Mac mini on 2026-08-31; the monitor was left at HDMI 1 (`4401`).

## Windows installation

Tools (both free, no install order dependency):
1. **ControlMyMonitor** (NirSoft) — DDC CLI. Put it e.g. in `C:\Tools\ControlMyMonitor\`.
2. **AutoHotkey v2** — for the hotkey.

1. Install **AutoHotkey v2** (not v1).
2. Download ControlMyMonitor from NirSoft and place `ControlMyMonitor.exe` in
   `C:\Tools\ControlMyMonitor\` (or another approved local directory).
3. Copy `P49w30DisplaySwitch.ahk` and `p49w30-switch.ini.example` from this repository to a
   stable local folder. Rename the example file to `p49w30-switch.ini`.
4. In `p49w30-switch.ini`, set `ControlMyMonitorPath` and set `MonitorTarget` to the exact
   P49w-30 identifier returned by `/MonitorEnum`. Avoid `Primary` if it is ambiguous.
5. Double-click the `.ahk` file, then press **Ctrl+Alt+D**. The safety check takes six
   seconds before a write; this is intentional.

Commands to run in `cmd.exe` before enabling startup:
```
ControlMyMonitor.exe /MonitorEnum                       :: find the monitor name; "Primary" usually works
ControlMyMonitor.exe /GetValueValue Primary 60 /stext %TEMP%\ddc60.txt   :: read — expect 4401 or 3889
ControlMyMonitor.exe /SetValue Primary 60 3889          :: laptop pane -> DisplayPort
ControlMyMonitor.exe /SetValue Primary 60 4401          :: laptop pane -> HDMI 1
```

The shipped script accepts only the exact full values `4401` and `3889`, deletes the old
read file before every query, checks command success, and requires two identical reads six
seconds apart. A missing, malformed, unexpected, or changing read aborts without a write.

## Start automatically

1. Press **Win+R**, enter `shell:startup`, and press Enter.
2. Create a shortcut there to the stable copy of `P49w30DisplaySwitch.ahk`.
3. Sign out and back in. Confirm the AutoHotkey tray icon appears and test **Ctrl+Alt+D**.

Do not place a second copy in startup: `#SingleInstance Force` prevents duplicate instances,
but one canonical shortcut is easier to troubleshoot.

## Troubleshooting

- **“ControlMyMonitor was not found”**: correct `ControlMyMonitorPath` in the INI beside the
  script. Do not add quotes inside the INI value.
- **Wrong/no monitor reacts**: run `/MonitorEnum`, copy the exact P49w-30 identifier into
  `MonitorTarget`, and keep DDC/CI enabled in the monitor OSD.
- **Unsafe/not-stable read notification**: do not force a write. Wait at least six seconds
  and retry. Check the raw `/GetValueValue` command; only `4401` or `3889` is accepted.
- **Hotkey does nothing**: confirm AutoHotkey v2 is running, only one script instance exists,
  and corporate endpoint policy has not blocked AutoHotkey or ControlMyMonitor.
- **Mac/left pane changes**: stop immediately and exit the script. Restore the monitor with
  its joystick and verify this unmodified script is being used; an 8-bit VCP write is unsafe.

Hardware-free logic check on Windows:
`AutoHotkey64.exe P49w30DisplaySwitch.ahk --self-test`.

## Caveats (all observed on the real setup)
- DDC commands travel over the machine's own video cable and work **regardless of which
  input the pane is currently showing** — the toggle works from either machine, any state.
- For ~5 s after a switch, reads return 0/garbage — that's why the script retries-protects.
- DDC/CI must stay enabled in the monitor OSD (it is today; a 10 s hold on OSD-exit toggles it).
- If "Primary" targets the wrong display, use the exact monitor name from `/MonitorEnum`.

## eKVM — how KVM switching actually works on this monitor

**There is no mouse-edge/screen-roaming switching.** The eKVM triggers are:
1. **Double-tap Shift within 0.5 s** (enable: OSD → Port Settings → KVM Setting → eKVM → Keyboard On)
2. **Hold both mouse buttons (left+right) for 3 s** (enable: same menu → Mouse On)

**Status 31.08: VERIFIED on this unit — double-tap Shift switches the KVM.** Dawid confirmed
by experiment and adopted it as the standard way to move keyboard+mouse.

Requirements (manual + verified in practice):
- KVM enabled in OSD → Port Settings → **KVM Setting**. **KVM On = switches USB *and* video
  together; KVM Off = USB only.**
- Keyboard/mouse must be plugged into **the specific USB port on the back designated for eKVM
  detection** — see the next section for which one that is on this desk.
- Both upstream cables connected: USB-C (Mac mini) and USB-B (laptop).

### Which rear port is the eKVM port

- Numbered rear-panel diagram: **[images/p49w30-rear-ports.png](images/p49w30-rear-ports.png)**
  (from the PSREF; legend: 1=USB-C · 2/4/5=USB-A · 3=audio · 6=RJ-45 · 7=TB4 Out · 8=TB4 In ·
  9=USB-B · 10/11=HDMI · 12=DP). Lenovo's eKVM hookup drawing:
  **[images/ekvm-hookup-lenovo.png](images/ekvm-hookup-lenovo.png)**.
- The manual names no port number — the designated port is marked with an icon printed on the
  plastic next to it. **Empirically on this desk:** the **Logitech Unifying receiver** (keyboard
  + mouse) sits in a rear USB-A port on the monitor's root hub (downstream port 2; `ioreg`
  locationID 0x03120000) — and since double-Shift works, **that port IS the eKVM port. Do not
  move the receiver.** Occupancy of the hub: port 1 = internal Realtek LAN, port 2 = Logitech
  receiver (eKVM), port 3 = sub-hub with the TIE microphone + Cisco Desk Camera 1080p,
  port 4 = internal monitor HID.
- If the receiver is ever moved and double-Shift stops working, move it back — the failure
  mode is exactly "trigger dead because the receiver left the designated port".

### Independence ruling (Dawid, 31.08) — do not re-couple

The pane toggle (⌃⌘⇧D on Mac / Ctrl+Alt+D on the laptop) and the KVM (double-Shift) are
**deliberately independent**: sometimes he wants to change screens without moving the
keyboard+mouse. A Hammerspoon listener that fired the pane toggle on double-Shift was built
briefly and removed at his request. Also, **synthetic Shift-taps from the OS can never trigger
the eKVM** — HID traffic flows keyboard → monitor → computer, never back up — so no software
shortcut can move the KVM. Double-tap the physical Shift key; that is the only way.

## Acceptance test (pane toggle)
1. With PBP active and the Mac visible on the left, `GetValueValue 60` returns exactly
   `4401` or `3889` for the configured target.
2. Press Ctrl+Alt+D once. After the six-second safety check, the laptop's right pane switches;
   the left Mac pane never changes.
3. Wait at least six more seconds and re-read: `3889` means laptop DisplayPort; `4401` means
   laptop HDMI 1.
4. Press the hotkey again and confirm the reverse transition and unchanged Mac/left pane.
5. During a post-switch interval, press the hotkey and confirm an unsafe/not-stable read
   produces a notification and no additional display switch.
6. Before finishing, leave the laptop's right pane on **HDMI 1** (`4401`).

If the Mac/left pane ever changes: **STOP** — the write was 8-bit; re-check that the installed
script is unmodified and uses `lowByte + nextHighByte*256`.

These hardware checks must be performed on the Cisco laptop and physical P49w-30. They
cannot be truthfully completed from the Mac-side repository.
