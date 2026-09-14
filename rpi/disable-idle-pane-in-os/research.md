# Research — disable the idle PBP half in macOS while the other machine owns it

Date: 2026-09-14. Machine: `DBEDNARC-M-472T` (MacBook Pro `Mac16,8`, MDM `macmdm.cisco.com`).

## Problem Context

Pressing ⌃⌘⇧D hands the monitor's right PBP window to the other machine by writing VCP `0x60`
high byte `0x11` (HDMI 1). The monitor stops showing our DisplayPort stream for that window —
but **macOS keeps the display enumerated**, because the DP link from the OWC hub stays trained.
Windows left on that half become invisible and unreachable.

Reproduced read-only at 16:20 CEST with the register already in the handed-away state:

```text
betterdisplaycli get -name="P49w-30" -feature=ddc -vcp=0x60 -value   →  4401,4401   (high byte 17 = HDMI 1)
system_profiler SPDisplaysDataType | grep -c "P49w-30"               →  2           (both halves still enumerated)
```

## Machine identity — corrects the repo

`hostname` = `DBEDNARC-M-472T`, `profiles status` = enrolled to `macmdm.cisco.com`. **This machine
is the Cisco laptop.** The repo (and `CISCO-LAPTOP-INSTRUCTIONS.md`) calls it "the Mac mini" and
assumes the Cisco laptop is a separate Windows box on HDMI 1. The byte map that actually holds:

| VCP `0x60` byte | Value | Physical | Owner |
|---|---|---|---|
| low (left PBP window) | `49` | USB-C / Thunderbolt | this Cisco MacBook Pro |
| high (right PBP window) | `15` | DisplayPort via OWC TB5 hub | this Cisco MacBook Pro |
| high (right PBP window) | `17` | HDMI 1 | the other machine ("Mac Mini") |

So the high byte is a **hand-off** bit: `15` = we keep the right half, `17` = we give it away.
The user's report ("my Cisco laptop still thinks it has two screens") is the `17` case.

## Affected Files

- `P49w30DisplaySwitch.lua:1-176` — the hotkey. `M.toggle()` writes `0x60` and stops there
  (`P49w30DisplaySwitch.lua:154-171`); nothing touches the macOS display list.
- `tests/test_toggle_contract.py:1-120` — contract tests, string-asserts against the Lua.
- `GUIDE.md`, `STATUS.md` — operator docs.
- `P49w30DisplaySwitch.ahk`, `p49w30-switch.ini.example`, `CISCO-LAPTOP-INSTRUCTIONS.md` —
  Windows artefacts for a machine that is not in this topology. Untouched.

## Code Examples

Current terminal state of the hotkey — the write is the last thing that happens:

```lua
runBetterDisplay({ "set", "-name=" .. MONITOR_NAME, "-feature=ddc", "-vcp=0x60",
                   "-value=" .. tostring(nextValue) }, function(exitCode, _, errorOutput)
    M.busy = false
    if exitCode ~= 0 then notify("BetterDisplay write failed: " .. errorOutput) return end
    notify(successMessage)
end)
```

## Mechanism found (verified live, not inferred)

BetterDisplay 4.3.6 CLI can disconnect a **real** display and macOS drops it:

```text
betterdisplaycli set -uuid=0DD21F99-3585-4C25-9A87-85A02B905151 -connected=off
  → P49w-30 count in system_profiler: 2 → 1
betterdisplaycli set -uuid=…                                    -connected=on
  → back to 2
```

Both directions exercised and the baseline (`2` displays, `0x60 = 4401`) was restored.

Per-display selectors that work: `-uuid=`, `-tagID=`. `-id=` is **ignored** (returns all
displays). `-name="P49w-30 2"` (the `originalName`) returns `Failed.`.

BetterDisplay's `UUID` field equals the macOS `CGDisplay` UUID that Hammerspoon reports, so the
Lua side can resolve the target without a hard-coded table:

```text
P49w-30 (2) | uuid=569B2955-7199-400F-9E4D-FF021630EA19 | x=1512  ← left half
P49w-30 (1) | uuid=0DD21F99-3585-4C25-9A87-85A02B905151 | x=4072  ← right half
```

## Testing Strategy

1. Pure logic: the "which connection state does this `0x60` value imply" rule gets a reference
   model in `tests/test_toggle_contract.py`, mirroring the existing `toggle_value` pattern.
2. Contract: string-assert the new Lua symbols so the Mac script cannot silently lose the step.
3. Hardware: press ⌃⌘⇧D in both directions and count `P49w-30` in `system_profiler` — expect
   `1` while the other machine owns the half, `2` after reclaiming.

## Potential Design Pattern Recommendations

- **Follow-the-write**: derive the desired macOS connection state from the value that was just
  written, so one rule serves both the `toggle` and the `restore` path.
- **Learn-when-observable**: the right-hand screen's UUID can only be derived while both halves
  are enumerated; cache it (`hs.settings`) and refuse to re-learn from a single-screen view.
- Sequence write-then-disconnect, never disconnect-then-write, so a failed DDC write cannot
  leave macOS a display short.

## FAR Scale Output

| Dimension | Score | Basis |
|---|---|---|
| Factual | 5 | Every claim above is a command output captured this session, including the disconnect/reconnect round trip. |
| Actionable | 4 | Exact CLI flags, exact UUIDs, exact insertion point in the Lua. |
| Relevant | 5 | Directly the reported symptom; no adjacent refactors pulled in. |
| **Mean** | **4.67** | ≥ 4.00 → pass |

## Assumptions

- **The high byte drives the RIGHT PBP window** (macOS screen at the larger x origin, uuid
  `0DD21F99…`). Basis: low byte = PBP main window, high byte = PBP sub window, and the sub window
  is the right one on this panel. Not provable from software — if it is reversed the wrong half
  vanishes on the next hotkey press, which is visible in one second and reverted by flipping the
  comparison in `rightPaneUUID()`. Chosen over asking, per the RPI autonomy directive.
- The other machine ("Mac Mini") has the mirror-image phantom when it gives the half back. Not
  reachable from here; out of scope.
- `betterdisplaycli -connected=off` persists across a BetterDisplay restart. Treated as true, so
  a documented one-line recovery is required.

## Out of Scope

- `P49w30DisplaySwitch.ahk` and the Windows install path — no Windows machine in this topology.
- The other machine's side of the same problem.
- eKVM / double-Shift, and OSD-driven input changes that bypass the hotkey (no polling added).
- Re-pointing the project's `4401`-is-home default, tracked separately in `STATUS.md`.
