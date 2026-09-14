# Carry-over 2026-09-03T10:01:00Z — both PBP halves belong to the Mac

Previous: [2026-09-03T09-10-00Z-mac-mini-left-stuck-restore.md](2026-09-03T09-10-00Z-mac-mini-left-stuck-restore.md)

## Working state at handoff (read-only capture, no writes)

```text
betterdisplaycli get -name="P49w-30" -feature=ddc -vcp=0x60 -value
3889,3889      # two records match "P49w-30"
```

`3889` = low `49` (Thunderbolt/USB-C) + high `15` (DisplayPort). Working. User asked for
read-only from 10:01 CET onward; no further monitor writes were made.

## The correction that matters

The Mac feeds the monitor over **two** paths and owns **both** PBP halves:

- Thunderbolt/USB-C → input `49`
- DisplayPort from the **OWC Thunderbolt 5 Hub** → input `15`

macOS enumerates two 2560x1440 P49w-30 targets at adjacent origins `(1512,-583)` and
`(4072,-899)`, together covering 5120x1440. The Cisco laptop is on **HDMI 1** (`17`) and is not
assigned to either half while `0x60 = 3889`.

So the high byte is **not** "the laptop's pane" as the repo assumed. `4401` hands a Mac half to
the laptop's HDMI 1 and blanks it whenever the laptop is not driving that input.

## Root cause of the reported failure

The documented "emergency restore to `4401`" is what blanked half the Mac desktop. It was
applied repeatedly across this and prior sessions. Recovery was one write of `3889`.

The Mac's Thunderbolt link was never down — DDC reads succeeded over that same link the whole
time, and macOS never dropped the display. "Thunderbolt stopped sending video" was the
symptom, not the cause.

## Dead ends — do not retry

- Do not treat `4401` as home. Invert it to `3889` for this cabling.
- Do not chase PBP over DDC. No MCCS code; BetterDisplay's `pip` is a macOS overlay, unrelated.
  `tools/vcp_sweep.py` (read-only) exists to find it by diffing snapshots around an OSD flip.
- Do not chase a Mac-side resolution fix. Each virtual half offers max 2560x1440 by design.
- eKVM / double-Shift is monitor firmware only and unrelated to `0x60`. Still unresolved.

## Next actions

1. Confirm in the OSD that input `15` is the OWC hub's DP cable, and read **USB-B Source**
   (suspected `Auto`/`HDMI`, which is why `3889` reverts to `4401` on link retrain).
2. Invert the default in `P49w30DisplaySwitch.lua` + `GUIDE.md` + `README.md` to `3889`, and
   reconsider `restoreMacPane()` treating high `15` as the Mac's own half.
3. Re-read the `3857` / `4367` "corruption" narrative — both are consistent with the Mac's
   Thunderbolt input being dropped from the pair, not a mangled 8-bit write.
4. Fix machine naming: the docs say "Mac mini" throughout, but this is a **MacBook Pro**
   (`Mac16,8`, M4 Pro) with a built-in display. The mislabel already misled one KVM diagnosis.

## Uncommitted at handoff

`GUIDE.md`, `STATUS.md`, `P49w30DisplaySwitch.lua`, `tests/test_toggle_contract.py`,
`tools/vcp_sweep.py` (new), `project_notes/vcp-sweeps/` (new). No commit was requested.
