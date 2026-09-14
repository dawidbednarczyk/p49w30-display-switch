#!/usr/bin/env python3
"""Read-only VCP snapshot for the ThinkVision P49w-30.

Reads every VCP code 0x00-0xFF via BetterDisplay and writes a TSV snapshot.
Never writes to the display, so it is safe to run in any monitor state.

Two snapshots taken in different monitor states can be diffed to locate an
undocumented control. The PBP enable code has no MCCS standard assignment and
is manufacturer specific on this panel, so a diff is the only way to find it.

Usage:
    python3 tools/vcp_sweep.py --label pbp-on
    python3 tools/vcp_sweep.py --label pbp-off
    python3 tools/vcp_sweep.py --diff snapshot_a.tsv snapshot_b.tsv
"""

from __future__ import annotations

import argparse
import datetime as dt
import pathlib
import subprocess

BETTERDISPLAY = "/opt/homebrew/bin/betterdisplaycli"
MONITOR_NAME = "P49w-30"
READ_TIMEOUT_SECONDS = 6
SNAPSHOT_DIR = pathlib.Path(__file__).resolve().parent.parent / "project_notes" / "vcp-sweeps"


def read_vcp(code: int) -> str:
    """Return the raw value for one VCP code, or a marker for no/failed read."""
    arguments = [
        BETTERDISPLAY,
        "get",
        f"-name={MONITOR_NAME}",
        "-feature=ddc",
        f"-vcp={code:#04x}",
        "-value",
    ]
    try:
        completed = subprocess.run(
            arguments, capture_output=True, text=True, timeout=READ_TIMEOUT_SECONDS
        )
    except subprocess.TimeoutExpired:
        return "TIMEOUT"

    value = (completed.stdout or "").strip().splitlines()
    if completed.returncode != 0 or not value:
        return "NONE"
    first = value[0].strip()
    return first if first else "NONE"


def sweep(label: str) -> pathlib.Path:
    SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
    path = SNAPSHOT_DIR / f"{stamp}-{label}.tsv"

    rows = []
    for code in range(256):
        value = read_vcp(code)
        rows.append((code, value))
        if value not in {"NONE", "TIMEOUT"}:
            print(f"  {code:#04x}  {value}", flush=True)

    with path.open("w", encoding="utf-8") as handle:
        handle.write(f"# P49w-30 VCP snapshot\t{stamp}\tlabel={label}\n")
        handle.write("vcp_hex\tvcp_dec\tvalue\n")
        for code, value in rows:
            handle.write(f"{code:#04x}\t{code}\t{value}\n")

    responded = sum(1 for _, value in rows if value not in {"NONE", "TIMEOUT"})
    print(f"\nWrote {path}  ({responded} codes responded)")
    return path


def load(path: pathlib.Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or line.startswith("vcp_hex"):
            continue
        parts = line.split("\t")
        if len(parts) >= 3:
            values[parts[0]] = parts[2]
    return values


def diff(path_a: pathlib.Path, path_b: pathlib.Path) -> None:
    a, b = load(path_a), load(path_b)
    print(f"A = {path_a.name}\nB = {path_b.name}\n")
    changed = [key for key in sorted(set(a) | set(b)) if a.get(key) != b.get(key)]
    if not changed:
        print("No differences. The control is not exposed over DDC on this panel.")
        return
    print(f"{'VCP':<8}{'A':<14}{'B':<14}")
    for key in changed:
        print(f"{key:<8}{a.get(key, '-'):<14}{b.get(key, '-'):<14}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", help="Snapshot label, e.g. pbp-on")
    parser.add_argument("--diff", nargs=2, metavar=("A", "B"), help="Compare two snapshots")
    args = parser.parse_args()

    if args.diff:
        diff(pathlib.Path(args.diff[0]), pathlib.Path(args.diff[1]))
        return 0
    if not args.label:
        parser.error("provide --label for a sweep, or --diff A B to compare")
    sweep(args.label)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
