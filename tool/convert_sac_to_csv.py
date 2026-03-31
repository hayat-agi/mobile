#!/usr/bin/env python3
"""
SAC/ASC → 25 Hz CSV converter for AFAD earthquake replay testing.

Usage
-----
    pip install -r requirements.txt
    python convert_sac_to_csv.py <input_dir> <output_dir>

What it does
------------
1. Walks <input_dir> recursively for *.SAC / *.sac files.
2. Groups files from the same station/event by their channel suffix
   (E/N/U  or  HN1/HN2/HNZ, etc.).
3. For each station group:
   - 3-component group (E+N+U or similar): uses all three axes.
     Adds 9.81 to the vertical channel so that (sqrt(x²+y²+z²) - 9.81)
     matches what the phone accelerometer reports at rest.
   - Single-component fallback: puts the channel in acc_x,
     sets acc_y=0, acc_z=9.81.
4. Resamples each channel to exactly 25 Hz.
5. Writes one CSV per station to <output_dir>:
       acc_x,acc_y,acc_z
       0.12,0.05,9.83
       ...

Zenodo dataset
--------------
Download Wu_etal_JGR_StrongMotionData.zip from
https://zenodo.org/records/16930394 (11.7 MB, no login required),
extract it, then point <input_dir> at the extracted folder.

Example
-------
    python convert_sac_to_csv.py ~/Downloads/StrongMotionData \
           ../test/fixtures/earthquake
"""

import argparse
import os
import sys
from pathlib import Path
from collections import defaultdict

try:
    import numpy as np
    from obspy import read
    from scipy.signal import resample_poly
    from math import gcd
except ImportError as e:
    sys.exit(
        f"Missing dependency: {e}\n"
        "Run:  pip install -r requirements.txt"
    )

TARGET_HZ = 25  # must match EarthquakeConfig.samplesPerSecond

# Channel suffixes recognised as East / North / Vertical (order matters for
# the x/y/z assignment in the CSV).
_EAST_TAGS    = {"E", "HNE", "HLE", "BHE", "1", "HN1", "HL1"}
_NORTH_TAGS   = {"N", "HNN", "HLN", "BHN", "2", "HN2", "HL2"}
_VERTICAL_TAGS = {"Z", "HNZ", "HLZ", "BHZ", "U", "HNU", "HLU"}


def _channel_role(channel: str) -> str | None:
    """Return 'E', 'N', or 'Z' for a known channel code, else None."""
    ch = channel.upper().lstrip("BH").lstrip("L")  # strip band/instrument prefix
    if channel.upper() in _EAST_TAGS or ch in {"E", "1"}:
        return "E"
    if channel.upper() in _NORTH_TAGS or ch in {"N", "2"}:
        return "N"
    if channel.upper() in _VERTICAL_TAGS or ch in {"Z", "U"}:
        return "Z"
    return None


def _resample(data: np.ndarray, src_hz: float, dst_hz: int) -> np.ndarray:
    """Resample data from src_hz to dst_hz using integer up/down factors."""
    if abs(src_hz - dst_hz) < 0.001:
        return data.astype(np.float64)
    src = round(src_hz * 1000)
    dst = dst_hz * 1000
    g = gcd(src, dst)
    up, down = dst // g, src // g
    resampled = resample_poly(data.astype(np.float64), up, down)
    return resampled


def _station_key(tr) -> str:
    """Unique station identifier from a Trace's stats."""
    s = tr.stats
    return f"{s.network}.{s.station}.{s.location}"


def _safe_name(key: str) -> str:
    return key.replace(".", "_").replace("/", "_").replace(" ", "_")


def convert_directory(input_dir: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    # Collect all SAC files
    sac_files = sorted(
        p for p in input_dir.rglob("*")
        if p.suffix.upper() in {".SAC", ".ASC", ""}
        and p.is_file()
        and not p.name.startswith(".")
    )

    if not sac_files:
        print(f"[!] No SAC files found in {input_dir}")
        return

    # Group traces by station key
    station_traces: dict[str, list] = defaultdict(list)
    for sac_path in sac_files:
        try:
            st = read(str(sac_path))
            for tr in st:
                station_traces[_station_key(tr)].append(tr)
        except Exception as exc:
            print(f"[!] Cannot read {sac_path.name}: {exc}")

    written = 0
    for station_key, traces in station_traces.items():
        # Map channel role → trace (last wins if duplicates)
        role_map: dict[str, object] = {}
        for tr in traces:
            role = _channel_role(tr.stats.channel)
            if role:
                role_map[role] = tr

        # Resample all available channels
        def _get(role: str) -> np.ndarray | None:
            tr = role_map.get(role)
            if tr is None:
                return None
            return _resample(tr.data, tr.stats.sampling_rate, TARGET_HZ)

        east = _get("E")
        north = _get("N")
        vert = _get("Z")

        if east is not None and north is not None and vert is not None:
            # True 3-component: align lengths
            n = min(len(east), len(north), len(vert))
            acc_x = east[:n]
            acc_y = north[:n]
            # Add 9.81 so (sqrt(x²+y²+z²) - 9.81) works like phone gravity
            acc_z = vert[:n] + 9.81
            label = "3c"
        elif east is not None:
            n = len(east)
            acc_x = east
            acc_y = np.zeros(n)
            acc_z = np.full(n, 9.81)
            label = "E"
        elif north is not None:
            n = len(north)
            acc_x = north
            acc_y = np.zeros(n)
            acc_z = np.full(n, 9.81)
            label = "N"
        elif vert is not None:
            # Vertical-only: treat as X
            n = len(vert)
            acc_x = vert
            acc_y = np.zeros(n)
            acc_z = np.full(n, 9.81)
            label = "Z"
        else:
            # No recognized channel — fall back to first trace
            if not traces:
                continue
            tr0 = traces[0]
            data = _resample(tr0.data, tr0.stats.sampling_rate, TARGET_HZ)
            n = len(data)
            acc_x = data
            acc_y = np.zeros(n)
            acc_z = np.full(n, 9.81)
            label = "raw"

        out_name = f"{_safe_name(station_key)}_{label}_{TARGET_HZ}hz.csv"
        out_path = output_dir / out_name

        with open(out_path, "w") as fh:
            fh.write("acc_x,acc_y,acc_z\n")
            for x, y, z in zip(acc_x, acc_y, acc_z):
                fh.write(f"{x:.6f},{y:.6f},{z:.6f}\n")

        print(f"  [{label:3s}] {out_name}  ({n} samples @ {TARGET_HZ} Hz)")
        written += 1

    print(f"\nDone — {written} CSV file(s) written to {output_dir}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert SAC earthquake recordings to 25 Hz CSV for replay tests.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "input_dir",
        type=Path,
        help="Directory (searched recursively) containing SAC files.",
    )
    parser.add_argument(
        "output_dir",
        type=Path,
        help="Directory where CSV fixtures will be written.",
    )
    args = parser.parse_args()

    if not args.input_dir.exists():
        sys.exit(f"Input directory not found: {args.input_dir}")

    print(f"Converting SAC files in:  {args.input_dir}")
    print(f"Writing CSV fixtures to:  {args.output_dir}\n")
    convert_directory(args.input_dir, args.output_dir)


if __name__ == "__main__":
    main()
