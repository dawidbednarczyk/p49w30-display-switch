# Project status

## 2026-09-16 (later) — stranded windows are now rescued after the hand-off

**Reported:** Dawid: *"I used the shortcut again, but it did not disable the screen. Again, I had
some windows that I couldn't reach."* Live state on inspection: `0x60 = 4401`, one `P49w-30`
half in macOS — so the disconnect itself had worked.

**Cause, reproduced:** disabling the half through `CGSConfigureDisplayEnabled` removes the screen
but does not move its windows. TextEdit and the Hammerspoon console parked at x=4200/5300 and a
real Chrome window at x=4072 all stayed there, beyond every remaining screen, invisible and
unreachable. The 2026-09-14 claim that windows "evacuate" only held for BetterDisplay's own
disconnect, which relocates windows itself; the licence-free helper does not. Two-half state looks
identical from the user's chair, hence "it did not disable the screen".

**Fix:** `M.rescueStrandedWindows()` in `P49w30DisplaySwitch.lua` — every window with fewer than
40px on any live screen is placed 40px inside the surviving `P49w-30` half, size preserved. Runs
2s after each hand-off and from an `hs.screen.watcher` on any screen-set change, so eKVM/OSD/wake
paths are covered too. `hs.window:moveToScreen(..., ensureInScreenBounds)` was tried first and
left windows with one pixel showing at x=4071; explicit `setFrame` replaced it. Notifications are
now also printed to the Hammerspoon console with timestamps.

**Verified through the hotkey path:** park TextEdit at x=4200 → hand off → `0x60 = 4401`, one half,
TextEdit at x=1552 on the surviving half. Contract suite 10 assertions, OK.

**Open:** one press at 16:40 (via IPC, before the console logging existed) changed nothing and
left no trace; the next such press will show its reason in the console.

Left at `4401` with one half, matching the state Dawid was in.

## 2026-09-16 — disconnect restored without BetterDisplay Pro (trial expired)

**Reported:** Dawid: *"recently we tried to disable second part of the screen when switching to
mac mini -> it is not working now"*. Found with `0x60 = 4401` (right pane on HDMI 1) and both
`P49w-30` halves still enumerated in macOS.

**Cause:** `betterdisplaycli get -proAvailable` → `off`. Display connect/disconnect is a
BetterDisplay **Pro** feature. The cask was installed 2026-08-31 17:45 and the Pro trial lapsed
around 2026-09-14 17:45, about an hour after the 16:40 acceptance. Since then every
`-connected` get or set returns `Failed.` and the Lua ignored that silently.

**Fix:** `tools/pane-connect.swift` — a tiny Swift CLI that calls the private
`CGSConfigureDisplayEnabled` (what BetterDisplay uses underneath) on a CGDirectDisplayID. The Lua
now runs it after each `0x60` write, caches `hs.screen:id()` of the right half
(`P49w30DisplaySwitch.rightPaneID` = `3`) instead of the UUID, because a disabled display cannot
be resolved by UUID, and appends `WARNING: ...` to the hotkey notification when the macOS step
fails instead of claiming success. DDC stays on the free `betterdisplaycli`.

**Hardware-verified through the real hotkey path (`_G.P49w30DisplaySwitch.toggle()` via hs IPC):**

```text
3889 → 4401   halves 2 → 1    (hand off; right half disabled by pane-connect 3 off)
4401 → 3889   halves 1 → 2    (reclaim; pane-connect 3 on; x=4072 back)
```

Left at `3889`, both halves connected. Contract suite 8/8 with `/opt/homebrew/bin/python3.14`.
Binary is gitignored; build with `swiftc -O -o tools/pane-connect tools/pane-connect.swift`.

**Recovery now:** `tools/pane-connect 3 on` (or replug USB-C). The old
`betterdisplaycli ... -connected=on` recovery command no longer works without Pro.

**User acceptance — 2026-09-16 16:05 CEST.** Dawid: *"save project status"* after the round trip
above. State at acceptance:

```text
betterdisplaycli get -name="P49w-30" -feature=ddc -vcp=0x60 -value   →  3889,3889
betterdisplaycli get -proAvailable                                    →  off
system_profiler SPDisplaysDataType | grep -c "P49w-30"               →  2
hs.settings P49w30DisplaySwitch.rightPaneID                           →  3
```

**Alternative not taken:** buying BetterDisplay Pro would have restored the old path unchanged.
The helper removes the licence dependency entirely, so that purchase is now optional.

## 2026-09-14 — idle PBP half is now disabled in macOS (RPI `disable-idle-pane-in-os`)

**Reported:** after handing the right half to the other machine, this laptop still enumerated two
screens, so windows on the handed-away half were invisible and unreachable.

**Cause:** the OWC hub's DisplayPort link stays trained after the monitor switches that PBP window
to HDMI 1. macOS never sees a disconnect, so the framebuffer survives with nothing showing it.

**Fix:** `P49w30DisplaySwitch.lua` now follows every successful `0x60` write with
`betterdisplaycli set -uuid=<right half> -connected=on|off` — `off` for high byte `17` (HDMI 1,
other machine), `on` for high byte `15` (DisplayPort, this machine). The UUID is learned from the
larger-x `P49w-30` screen while both halves are enumerated and cached in `hs.settings`
(`P49w30DisplaySwitch.rightPaneUUID` = `0DD21F99-3585-4C25-9A87-85A02B905151`).

**Hardware-verified, three consecutive hotkey presses:**

```text
4401 → 3889   displays 2 → 2    (reclaim; both halves connected)
3889 → 4401   displays 2 → 1    (hand off; right half disconnected)
4401 → 3889   displays 1 → 2    (reclaim from the disconnected state; x=4072 restored)
```

Left at `3889` with both halves connected. Contract suite: 8/8 (`python3.14 -m unittest
tests.test_toggle_contract`; the system python 3.9 cannot parse the file's `int | None` hints).

**Machine-identity correction — closes carry-over item 4.** `hostname` = `DBEDNARC-M-472T`,
`profiles status` = enrolled to `macmdm.cisco.com`. The machine running Hammerspoon **is the Cisco
laptop**, a MacBook Pro `Mac16,8`. It owns the left half over USB-C (`49`) and the right half over
the hub's DisplayPort (`15`). **HDMI 1 (`17`) is the other machine** — the one the user calls the
"Mac Mini". The repo's "Mac mini vs Windows Cisco laptop" split is wrong; `P49w30DisplaySwitch.ahk`,
`p49w30-switch.ini.example` and `CISCO-LAPTOP-INSTRUCTIONS.md` target a machine not in this topology.

**Recovery if a half goes missing:** `betterdisplaycli set -name="P49w-30" -connected=on`.

**User acceptance — 2026-09-14 16:40 CEST.** Dawid: *"great, save project status, works so far"*.
Accepted in normal use, not only in the scripted round trip. State at acceptance:

```text
betterdisplaycli get -name="P49w-30" -feature=ddc -vcp=0x60 -value   →  3889,3889
betterdisplaycli get -name="P49w-30" -connected                      →  on,on
system_profiler SPDisplaysDataType | grep -c "P49w-30"               →  2
```

**Known gap:** OSD- or eKVM-driven input changes bypass the hotkey and will strand windows again;
one press of Ctrl+Command+Shift+D resynchronises. No poller was added.


## Repository work — complete (2026-08-31)

- Production AutoHotkey v2 hotkey implementation added for Ctrl+Alt+D on the laptop's right pane.
- VCP 0x60 handling accepts only verified 16-bit values, preserves low byte 49, and changes
  only the laptop-pane high byte.
- Fresh-output, command-exit, exact-value, and six-second stable-read interlocks prevent an
  invalid or post-switch stale read from authorizing a write.
- Configurable ControlMyMonitor path and exact monitor target provided through an INI file.
- Windows installation, startup, troubleshooting, standing HDMI 1 return rule, and hardware
  acceptance steps documented. KVM has no software work: native double-Shift stays independent.
- Hardware-free contract tests added for repository and Windows use.
- Mac Ctrl+Command+Shift+D Hammerspoon binding added using the installed BetterDisplay CLI;
  it shares the exact-value and six-second stable-read safety contract. Both directions were
  hardware-verified on 2026-08-31 and the final state was restored to HDMI 1 (`4401`).
- User acceptance completed on 2026-08-31: Ctrl+Command+Shift+D works as intended. Closeout
  re-read confirmed `4401,4401`, leaving the laptop/right pane on HDMI 1.

## 2026-09-03 10:01 CET — WORKING STATE + model correction (read-only capture)

Register now, three consecutive read-only reads:

```bash
/opt/homebrew/bin/betterdisplaycli get -name="P49w-30" -feature=ddc -vcp=0x60 -value
3889,3889     # two values because TWO display records now match "P49w-30"
```

`3889` = low `49` (Thunderbolt/USB-C) + high `15` (DisplayPort). **This is the working value.**

### The working scenario: the Mac drives BOTH halves

macOS enumerates **two** P49w-30 targets, side by side, together covering the full 5120x1440:

| Persistent screen id | Resolution | Origin |
|----------------------|------------|--------|
| `3B54F630-6BF2-4231-A87C-AE8C9DA0DA55` | 2560x1440 | `(1512,-583)` |
| `6F285CA3-924B-45E3-A6E0-90D5C64D0694` | 2560x1440 | `(4072,-899)` |

`1512` is the built-in screen width and `1512 + 2560 = 4072`, so the two halves are adjacent.
`system_profiler SPDisplaysDataType` likewise lists `P49w-30` twice at 2560x1440 @ 60Hz.

Cabling that produces this (from `SPThunderboltDataType`): MacBook Pro → **OWC Thunderbolt 5
Hub** (80 Gb/s) → P49w-30 (that hop negotiates 20 Gb/s). The hub feeds the monitor over **two**
paths — Thunderbolt/USB-C (input `49`) **and** DisplayPort (input `15`). Each PBP half is a
separate 2560x1440 virtual display owned by the Mac. The Cisco laptop sits on **HDMI 1**
(`17`), which is **not** assigned to either half while `0x60 = 3889`.

### What actually happened (root cause of the black half)

The earlier sessions' documented "emergency restore" to **`4401`** re-assigned the second half
from DisplayPort (`15`, the Mac's own second stream) to HDMI 1 (`17`, the Cisco laptop). With
the laptop not driving HDMI 1 at that moment, that half went black — and the Mac lost half its
desktop. Symptomatically this reads exactly like "Thunderbolt stopped sending video," which is
how it was reported, but the Mac's link was never down: DDC reads/writes kept succeeding over
it throughout, and macOS never dropped the display.

Recovery was a single write of `3889`, which restored the Mac's second half.

### Model correction — supersedes the byte table below

The pre-existing model treated the high byte as "the laptop's pane, toggled DP ↔ HDMI 1" and
`4401` as the safe home value. With this cabling that is wrong:

| Byte | Old reading | Actual with current cabling |
|------|-------------|------------------------------|
| low `49` | Mac pane (USB-C) | Mac half via Thunderbolt — correct |
| high `15` (DP) | laptop on DisplayPort | **Mac's second half** via the OWC hub's DP output |
| high `17` (HDMI 1) | laptop on HDMI 1 | Cisco laptop — hands a Mac half to the laptop |

Consequences:

- **`3889` is home, not `4401`.** `4401` costs the Mac half its desktop whenever the laptop is
  not actively driving HDMI 1. The "standing HDMI 1 return rule" is harmful in this cabling.
- The values previously filed as 8-bit *corruption* deserve re-reading. `3857` (low `17`, high
  `15`) and `4367` (low `15`, high `17`) are both consistent with the Mac's **Thunderbolt**
  input being dropped from the pair while its DisplayPort stream stayed assigned — a plausible
  real assignment, not necessarily a mangled write.

### Known fragility

`3889` holds steady when left alone (verified over 20 s of polling). It reverted to `4401` by
itself the moment the Mac's video link retrained (triggered by a resolution change). The
monitor appears to re-pin its second window to HDMI 1 on a link event — most likely because
OSD → **USB-B Source** is set to `Auto` or `HDMI`. Any DisplayPort assignment should therefore
be treated as fragile across sleep/wake, undock, and mode changes.

### Open items (no monitor writes performed; read-only per user request)

1. Confirm in the OSD whether the OWC hub's DisplayPort cable is the source of input `15`, and
   what **USB-B Source** is set to.
2. Decide the intended home value. If the Mac should own the whole panel by default, `3889` is
   home and `P49w30DisplaySwitch.lua` plus `GUIDE.md` need their `4401` default inverted.
3. Re-examine whether `restoreMacPane()` should treat high byte `15` as "the Mac's own second
   half" rather than "laptop input, preserve unchanged".
4. eKVM/double-Shift remains unresolved and is unrelated to `0x60` — monitor firmware only.

## Mac mini — live (2026-09-03) — SUPERSEDED, see the 10:01 section above

> The byte interpretation in this section assumes the high byte is the Cisco laptop's pane.
> Evidence captured 2026-09-03 10:01 shows the high byte `15` is the Mac's own second half via
> the OWC hub's DisplayPort output. Kept for history; do not act on its `4401` home rule.

**Incident:** After undocking the Cisco laptop, the Mac mini stayed on the **left** PBP pane and
⌃⌘⇧D only toggled the laptop high byte — it never detected or corrected a wrong Mac-pane low
byte.

**Root cause:** Undocking can change VCP `0x60` so the **low byte (Mac pane) is no longer `49`**
(USB-C). Observed values:

| Value | Low byte (Mac) | High byte (laptop) | Meaning |
|-------|----------------|--------------------|---------|
| `4401` | 49 ✓ | 17 (HDMI 1) | Home — Mac right/USB-C, laptop left/HDMI 1 |
| `3889` | 49 ✓ | 15 (DisplayPort) | Alt — Mac right/USB-C, laptop left/DP |
| `3857` | **17 ✗** | 15 (DisplayPort) | **Stuck Mac-left** (Mac pane on HDMI 1 input) |
| `3855` | **15 ✗** | 15 (DisplayPort) | **Stuck Mac-left** (Mac pane on DP input) |
| `4369` | **17 ✗** | 17 (HDMI 1) | **Stuck Mac-left** (both bytes HDMI-class) |

The old script rejected any value outside `4401`/`3889`, so the hotkey showed *"Unsafe or invalid
read"* and did nothing — even though the fix is a **restore** (set low byte back to `49`,
preserve laptop high byte), not a blind toggle.

**Fix (2026-09-03):** `P49w30DisplaySwitch.lua` now decodes both bytes on every press:

1. Stable 6 s double-read (unchanged).
2. If low byte `= 49` and value is `4401` or `3889` → toggle laptop input (unchanged).
3. If low byte `≠ 49` but laptop high byte is `15` or `17` → **restore** to `3889` or `4401`
   (Mac back to USB-C/right; laptop input unchanged).
4. Otherwise refuse (unknown bytes, no write).

**Hardware verification (2026-09-03 ~09:10 CET):**

```bash
# Before fix — stuck state after undock
/opt/homebrew/bin/betterdisplaycli get -name="P49w-30" -feature=ddc -vcp=0x60 -value
3857

# Restore path (script logic; manual CLI equivalent)
/opt/homebrew/bin/betterdisplaycli set -name="P49w-30" -feature=ddc -vcp=0x60 -value=3889
# after 7 s settle → 3889

# Home state restored
/opt/homebrew/bin/betterdisplaycli set -name="P49w-30" -feature=ddc -vcp=0x60 -value=4401
# after 7 s settle → 4401
```

Hammerspoon module reloaded; ⌃⌘⇧D hotkey active.

**Emergency restore command** (if hotkey shows byte error or Mac is stuck on left):

```bash
/opt/homebrew/bin/betterdisplaycli set -name="P49w-30" -feature=ddc -vcp=0x60 -value=4401
```

Never use 8-bit DDC writes (`… 60 17` or similar). Only full 16-bit values `4401` or `3889`.

### Prior incident (2026-09-02)

Same corruption signature (`3857`, low byte `17`). Recovered manually to `4401`; hotkey worked
again until the undock regression above. See
`project_notes/carry-over/2026-09-02T18-15-00Z-ddc-corruption-recovery.md`.

## Cisco laptop actions — pending

1. Install/approve AutoHotkey v2 and NirSoft ControlMyMonitor under Cisco endpoint policy.
2. Copy the script and INI to a stable folder; configure the executable path and exact
   P49w-30 target from `/MonitorEnum`.
3. Run the AutoHotkey self-test and raw ControlMyMonitor read.
4. Complete every hardware acceptance step in `GUIDE.md`, including the stale-read test and
   proof that the Mac left pane remains unchanged.
5. Add one script shortcut to `shell:startup` and verify it after sign-in/reboot.
6. Leave the laptop's right pane on HDMI 1 (`4401`) when laptop work is finished.

The Windows runtime, Cisco corporate policy, and laptop-originated DDC path remain unverified.
The Mac BetterDisplay path and physical `3889 ↔ 4401` transitions have been verified (2026-08-31
and recovered again 2026-09-02).

## Closeout

Project implementation is complete and accepted. The repository has no active work except
the explicitly listed Cisco laptop installation and hardware acceptance steps above.
