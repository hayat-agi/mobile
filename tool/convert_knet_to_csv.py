#!/usr/bin/env python3
"""
KNET / KiK-net ASCII → 25 Hz CSV converter for earthquake replay testing.

KNET is Japan's free strong-motion network (k-net.bosai.go.jp).
Each event produces three ASCII text files per station:
  YYYYMMDDHHMMSS.NS   (North-South  → acc_x)
  YYYYMMDDHHMMSS.EW   (East-West    → acc_y)
  YYYYMMDDHHMMSS.UD   (Up-Down      → acc_z, gravity added)

KiK-net surface files use the same format with .NS2 / .EW2 / .UD2 suffixes.

Usage
-----
    pip install numpy scipy        # obspy is NOT required
    python convert_knet_to_csv.py <input_dir> <output_dir>

Download data
-------------
  1. Go to https://www.kyoshin.bosai.go.jp/
  2. Register for a free account (instant approval).
  3. Search by date/area or event ID; select "KNET" instrument.
  4. Download "ASCII" format — each event is a zip with many station files.
  5. Extract and point <input_dir> at the extracted folder.

Recommended events for diverse testing
---------------------------------------
  2011-03-11 Mw 9.0  Tohoku-Oki  — many near-field M8+ records
  2016-04-14 Mw 6.5  Kumamoto    — moderate event, varied distances
  2024-01-01 Mw 7.6  Noto        — recent, dense coverage
  2004-10-23 Mw 6.6  Niigata     — shallow crustal

The output CSV format is identical to convert_sac_to_csv.py output:
    acc_x,acc_y,acc_z    (m/s², 25 Hz, gravity on z-axis)

Example
-------
    python convert_knet_to_csv.py ~/Downloads/knet_kumamoto \\
           ../test/fixtures/earthquake
"""

import argparse
import sys
from collections import defaultdict
from math import gcd
from pathlib import Path

try:
    import numpy as np
    from scipy.signal import resample_poly
except ImportError as e:
    sys.exit(
        f"Missing dependency: {e}\n"
        "Run:  pip install numpy scipy"
    )

TARGET_HZ = 25  # must match EarthquakeConfig.samplesPerSecond

# KNET channel extension → axis role
_EXT_ROLE: dict[str, str] = {
    # KNET
    ".NS":  "N",   # North-South  → acc_x
    ".EW":  "E",   # East-West    → acc_y
    ".UD":  "Z",   # Up-Down      → acc_z
    # KiK-net surface borehole (same format, different suffix)
    ".NS2": "N",
    ".EW2": "E",
    ".UD2": "Z",
    # Older KNET variants
    ".N":   "N",
    ".E":   "E",
    ".U":   "Z",
}


# ── KNET ASCII parser ─────────────────────────────────────────────────────────

class KnetRecord:
    """Parsed contents of a single KNET ASCII channel file."""

    def __init__(self) -> None:
        self.station:      str   = ""
        self.channel_role: str   = ""   # "N", "E", or "Z"
        self.sampling_hz:  float = 100.0
        self.scale_factor: float = 1.0
        self.data_gal:     np.ndarray = np.array([], dtype=np.float64)

    @property
    def data_ms2(self) -> np.ndarray:
        """Data converted from gal (cm/s²) to m/s²."""
        return self.data_gal * 0.01


def _parse_knet_ascii(path: Path, role: str) -> KnetRecord | None:
    """
    Parse one KNET/KiK-net ASCII file.

    Header format (16 lines):
        Origin Time         YYYY/MM/DD HH:MM:SS.SS
        Lat.               32.7420Lon.              130.8100
        Depth(km)          ...
        Mag.               ...
        Station Code       AOMH04
        Station Lat.       ...
        Station Lon.       ...
        Station Height(m)  ...
        Record Time        YYYY/MM/DD HH:MM:SS.SSS
        Sampling Freq(Hz)  100
        Samples            18000
        Scale Factor       1.0000e+02
        Max Acc(gal)       219.79
        Last Correction    ...
        Memo
        Memo
    Followed by whitespace-separated integer data values.
    """
    rec = KnetRecord()
    rec.channel_role = role

    try:
        text = path.read_text(errors="replace")
    except OSError as e:
        print(f"[!] Cannot read {path.name}: {e}")
        return None

    lines = text.splitlines()
    header_end = 0
    raw_ints: list[int] = []

    for idx, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("Station Code"):
            rec.station = stripped.split()[-1]
        elif stripped.startswith("Sampling Freq"):
            try:
                rec.sampling_hz = float(stripped.split()[-1])
            except ValueError:
                pass
        elif stripped.startswith("Scale Factor"):
            try:
                rec.scale_factor = float(stripped.split()[-1])
            except ValueError:
                pass
        elif stripped.startswith("Memo"):
            header_end = idx + 1
            break

    # Everything after the last "Memo" line is data
    for line in lines[header_end:]:
        for token in line.split():
            try:
                raw_ints.append(int(token))
            except ValueError:
                pass

    if not raw_ints:
        print(f"[!] No data parsed from {path.name}")
        return None

    # Convert: raw / scale_factor = gal
    rec.data_gal = np.array(raw_ints, dtype=np.float64) / rec.scale_factor
    return rec


# ── resampler (shared with convert_sac_to_csv.py approach) ───────────────────

def _resample(data: np.ndarray, src_hz: float, dst_hz: int) -> np.ndarray:
    if abs(src_hz - dst_hz) < 0.001:
        return data.astype(np.float64)
    src = round(src_hz * 1000)
    dst = dst_hz * 1000
    g   = gcd(src, dst)
    return resample_poly(data.astype(np.float64), dst // g, src // g)


# ── directory converter ───────────────────────────────────────────────────────

def convert_directory(input_dir: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    # Collect all recognised KNET files
    knet_files: list[Path] = []
    for p in sorted(input_dir.rglob("*")):
        if p.is_file() and p.suffix.upper() in {e.upper() for e in _EXT_ROLE}:
            knet_files.append(p)

    if not knet_files:
        print(f"[!] No KNET ASCII files found in {input_dir}")
        print(f"    Expected extensions: {list(_EXT_ROLE.keys())}")
        return

    # Group by (parent_dir, base_stem) so that NS/EW/UD files for the same
    # station/event are processed together.
    # e.g.  2016041421260003.NS + .EW + .UD  →  same group
    groups: dict[tuple[Path, str], dict[str, Path]] = defaultdict(dict)
    for p in knet_files:
        # Normalise extension to upper-case for lookup
        ext_upper = p.suffix.upper()
        role = next(
            (v for k, v in _EXT_ROLE.items() if k.upper() == ext_upper), None
        )
        if role is None:
            continue
        key = (p.parent, p.stem)
        groups[key][role] = p

    written = 0
    for (parent, stem), role_map in sorted(groups.items()):
        # Parse available channels
        records: dict[str, KnetRecord] = {}
        for role, fpath in role_map.items():
            rec = _parse_knet_ascii(fpath, role)
            if rec is not None:
                records[role] = rec

        if not records:
            continue

        # Determine station name (use stem if not in header)
        station = next(iter(records.values())).station or stem

        east  = records.get("E")
        north = records.get("N")
        vert  = records.get("Z")

        def _resamp(rec: KnetRecord) -> np.ndarray:
            return _resample(rec.data_ms2, rec.sampling_hz, TARGET_HZ)

        if east and north and vert:
            e_d = _resamp(east)
            n_d = _resamp(north)
            z_d = _resamp(vert)
            n   = min(len(e_d), len(n_d), len(z_d))
            acc_x = e_d[:n]
            acc_y = n_d[:n]
            # Add gravity so (sqrt(x²+y²+z²) − 9.81) works like phone
            acc_z = z_d[:n] + 9.81
            label = "3c"
        elif east:
            d = _resamp(east)
            n = len(d)
            acc_x = d
            acc_y = np.zeros(n)
            acc_z = np.full(n, 9.81)
            label = "E"
        elif north:
            d = _resamp(north)
            n = len(d)
            acc_x = d
            acc_y = np.zeros(n)
            acc_z = np.full(n, 9.81)
            label = "N"
        elif vert:
            d = _resamp(vert)
            n = len(d)
            acc_x = d
            acc_y = np.zeros(n)
            acc_z = np.full(n, 9.81)
            label = "Z"
        else:
            continue

        safe_station = station.replace(".", "_").replace("/", "_").replace(" ", "_")
        out_name = f"KNET_{safe_station}_{stem}_{label}_{TARGET_HZ}hz.csv"
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
        description="Convert KNET/KiK-net ASCII recordings to 25 Hz CSV for replay tests.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "input_dir",
        type=Path,
        help="Directory (searched recursively) containing KNET ASCII files.",
    )
    parser.add_argument(
        "output_dir",
        type=Path,
        help="Directory where CSV fixtures will be written.",
    )
    args = parser.parse_args()

    if not args.input_dir.exists():
        sys.exit(f"Input directory not found: {args.input_dir}")

    print(f"Converting KNET files in:  {args.input_dir}")
    print(f"Writing CSV fixtures to:   {args.output_dir}\n")
    convert_directory(args.input_dir, args.output_dir)


if __name__ == "__main__":
    main()
