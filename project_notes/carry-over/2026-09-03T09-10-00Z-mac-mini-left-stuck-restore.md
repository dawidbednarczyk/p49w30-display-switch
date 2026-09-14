# Carry-over 2026-09-03T09:10:00Z — Mac mini left-pane stuck restore

Previous: [2026-09-02T18-15-00Z-ddc-corruption-recovery.md](2026-09-02T18-15-00Z-ddc-corruption-recovery.md)

## Goal

Fix ⌃⌘⇧D so it auto-corrects when undocking leaves the Mac mini on the left PBP pane (low byte
≠ 49), not only toggle laptop input when already healthy.

## Root cause

Undock changes VCP `0x60` low byte from `49` (USB-C) to `15` or `17`. Old script rejected all
non-`4401`/`3889` reads — correct safety for blind toggles, wrong for recoverable stuck states.

## Fix

`planAction()` in `P49w30DisplaySwitch.lua`: stable read → if low ≠ 49 and high ∈ {15,17},
write `49 + high*256`; else if value ∈ {4401,3889}, toggle high byte as before.

## Verified

- Unit tests: `python3 -m unittest tests/test_toggle_contract.py`
- Hardware: `3857` → restore `3889` → home `4401` via betterdisplaycli
- Hammerspoon reloaded via `hs -c 'dofile(...)'`

## Do not

- Accept unknown high bytes or write non-`4401`/`3889` targets.
- Weaken 6 s stable-read gate.
