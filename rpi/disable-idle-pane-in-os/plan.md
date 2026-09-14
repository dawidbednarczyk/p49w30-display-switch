# Plan — disable the idle PBP half in macOS while the other machine owns it

Input: `research.md` (FAR 4.67).

## Implementation Overview

Make the hotkey own the macOS display list as well as the monitor register: after a successful
`0x60` write, set the right-hand `P49w-30` screen's BetterDisplay `connected` state to match the
new high byte — `off` when the half went to the other machine (`0x11`), `on` when we took it back
(`0x0F`). The target screen is resolved by UUID, learned while both halves are visible and cached
in `hs.settings` so it survives the period when the screen is gone.

## Task Breakdown

### Phase A — logic
- [x] Add `M.paneConnectionState(value)` to `P49w30DisplaySwitch.lua`: pure, returns `"on"` /
      `"off"` / `nil` from the high byte.
- [x] Add `rightPaneUUID()` to `P49w30DisplaySwitch.lua`: picks the largest-x `P49w-30` screen,
      caches it in `hs.settings`, only re-learns when ≥ 2 halves are enumerated.
- [x] Add `applyPaneConnection(value, callback)` to `P49w30DisplaySwitch.lua`: one
      `betterdisplaycli set -uuid=… -connected=…` call, failures are non-fatal.

### Phase B — wiring
- [x] Call `applyPaneConnection` from the `0x60` write callback in `M.toggle()`, after a zero
      exit code, before the success notification.
- [x] Correct the misleading machine names in the Lua's constants and header comment
      (`LAPTOP_DP_BYTE`/`LAPTOP_HDMI_BYTE` → `PANE_MINE_BYTE`/`PANE_OTHER_BYTE`).

### Phase C — tests
- [x] Add `pane_connection_state()` reference model + assertions to
      `tests/test_toggle_contract.py`.
- [x] Add the new Lua symbols to the existing contract string-assert list.

### Phase D — docs
- [x] Document the behaviour, the recovery one-liner, and the corrected byte map in `GUIDE.md`.
- [x] Append the 2026-09-14 finding + machine-identity correction to `STATUS.md`.

### Phase E — verification
- [x] `python3 -m unittest tests.test_toggle_contract -v`
- [x] Reload Hammerspoon, press ⌃⌘⇧D in both directions, count `P49w-30` in `system_profiler`.
- [x] Leave `0x60` and the display count in a coherent state and report it.

## Code References

- `P49w30DisplaySwitch.lua:8-22` — constants to rename.
- `P49w30DisplaySwitch.lua:154-171` — the write callback to extend.
- `tests/test_toggle_contract.py:96-120` — the contract string list.

## Testing Plan

| Task | Test |
|---|---|
| `paneConnectionState` | `4401 → "off"`, `3889 → "on"`, `4145`/garbage → `None` |
| `rightPaneUUID` | not unit-testable (live screens); covered by the hardware check |
| wiring | contract assert on `applyPaneConnection(nextValue` inside the write callback |
| end-to-end | `system_profiler … | grep -c P49w-30` = `1` handed away, `2` reclaimed |

## Dependencies & Sequencing

A → B → C → D. E last. Phase C's contract asserts will fail until B lands, so C follows B.

## FACTS Scale Output

| Dimension | Score | Basis |
|---|---|---|
| Focused | 4 | One behaviour; the rename is the only adjacent edit and it is a documented incident cause. |
| Atomic | 4 | Each task is one function or one file section. |
| Complete | 4 | Logic, wiring, tests, docs, hardware verification. |
| Testable | 4 | Pure rule unit-tested; wiring string-asserted; end-to-end has a numeric expectation. |
| Sequenced | 5 | Strict A→B→C→D→E, stated blockers. |
| **Mean** | **4.20** | ≥ 3.00 → pass |

## Risk Mitigation

- **Wrong half disconnected** (the one live assumption). Visible in one second; fix is flipping
  the comparison in `rightPaneUUID()`. Chosen autonomously per the RPI directive rather than
  stopping to ask.
- **Disconnect survives a restart and the user loses half the panel.** Mitigated by documenting
  `betterdisplaycli set -name="P49w-30" -connected=on` in `GUIDE.md`, and by the hotkey itself
  re-asserting the correct state on every press.
- **Connection call fails.** Non-fatal: the DDC write already succeeded and the notification
  still fires. Worst case is today's behaviour.
- **Fork decision — no polling.** Input changes made from the OSD or the monitor's eKVM bypass
  the hotkey and will still strand windows. Rejected a `0x60` poller as unrequested background
  load; the hotkey resyncs on the next press.
- **Fork decision — Windows side untouched.** `P49w30DisplaySwitch.ahk` targets a machine that
  research shows is not in this topology.

## Rollback Strategy

`git checkout -- P49w30DisplaySwitch.lua tests/test_toggle_contract.py` and
`betterdisplaycli set -name="P49w-30" -connected=on`. Every file the plan touches is tracked
(gitignore pre-flight run: 6/6 tracked), so per-file revert is the rollback path.
