#!/usr/bin/env python3
"""
FDSN strong-motion downloader for earthquake replay testing.

Queries an FDSN data center for earthquakes, downloads HN* (strong-motion
accelerometer) waveforms for nearby stations, and writes 25 Hz CSV files
directly into test/fixtures/earthquake/ — no manual downloading needed.

Usage
-----
    pip install -r requirements.txt   # obspy, scipy, numpy already there
    python download_fdsn_fixtures.py [options]

Quick examples
--------------
    # 20 global M5.5+ events, past 3 years (default)
    python download_fdsn_fixtures.py

    # 30 Turkish M5+ events — good complement to existing Kahramanmaraş data
    python download_fdsn_fixtures.py --region turkey --minmag 5.0 --maxevents 30

    # Japan M6+ via IRIS
    python download_fdsn_fixtures.py --region japan --minmag 6.0 --maxevents 25

    # California M5+ via Southern California Seismic Network
    python download_fdsn_fixtures.py --region california --datacenter SCEDC

    # Custom date window
    python download_fdsn_fixtures.py --starttime 2023-01-01 --endtime 2024-01-01

Available --region values
-------------------------
    global  turkey  japan  california  chile  italy  greece  newzealand

Available --datacenter values
-----------------------------
    IRIS (default, best global coverage)
    ORFEUS   — Europe + Turkey (good for Kahramanmaraş follow-up events)
    SCEDC    — Southern California
    NCEDC    — Northern California / Pacific Northwest
    GFZ      — Germany / global
    INGV     — Italy

Algorithm requirements (earthquake_config.dart)
------------------------------------------------
    25 Hz sampling, HN* accelerometer channels, gravity added to vertical.
    LTA needs 30 s warm-up → script prepends 60 s of pre-event noise.
"""

import argparse
import sys
import time
from collections import defaultdict
from math import gcd
from pathlib import Path

try:
    import numpy as np
    from scipy.signal import resample_poly
    from obspy import UTCDateTime
    from obspy.clients.fdsn import Client
    from obspy.clients.fdsn.header import FDSNNoDataException, FDSNException
    from obspy.geodetics import locations2degrees
except ImportError as e:
    sys.exit(
        f"Missing dependency: {e}\n"
        "Run:  pip install obspy scipy numpy\n"
        "  or: pip install -r tool/requirements.txt"
    )

# ── constants ─────────────────────────────────────────────────────────────────

TARGET_HZ      = 25    # must match EarthquakeConfig.samplesPerSecond
G              = 9.81  # m/s²
PRE_EVENT_S    = 10    # seconds before origin — enough for taper; LTA warms from eq energy
POST_EVENT_S   = 120   # seconds after origin  — captures full shaking + taper
MAX_RADIUS_DEG = 2.0   # ≈ 220 km; near-field strong motion

# Preferred channel priorities (first match wins per station)
CHANNEL_PRIORITIES = ["HN?", "HL?", "HH?"]

# Pre-defined bounding boxes: (minlat, maxlat, minlon, maxlon)
REGIONS: dict[str, tuple[float, float, float, float] | None] = {
    "global":     None,
    "turkey":     ( 35.0,  43.0,  25.0,  45.0),
    "japan":      ( 30.0,  46.0, 130.0, 146.0),
    "california": ( 32.0,  42.0, -124.0, -114.0),
    "chile":      (-55.0, -17.0,  -76.0,  -65.0),
    "italy":      ( 36.0,  47.0,   6.0,   19.0),
    "greece":     ( 35.0,  42.0,  20.0,   30.0),
    "newzealand": (-47.0, -34.0, 166.0,  178.0),
}

DATA_CENTERS: dict[str, str] = {
    "IRIS":    "IRIS",
    "ORFEUS":  "ORFEUS",
    "SCEDC":   "SCEDC",
    "NCEDC":   "NCEDC",
    "GFZ":     "GFZ",
    "INGV":    "INGV",
}


# ── helpers ───────────────────────────────────────────────────────────────────

def _resample(data: np.ndarray, src_hz: float, dst_hz: int) -> np.ndarray:
    if abs(src_hz - dst_hz) < 0.001:
        return data.astype(np.float64)
    src = round(src_hz * 1000)
    dst = dst_hz * 1000
    g   = gcd(src, dst)
    return resample_poly(data.astype(np.float64), dst // g, src // g)


def _channel_role(channel: str) -> str | None:
    """Map the last character of a channel code to E / N / Z."""
    last = channel[-1].upper()
    if last in ("E", "1"):
        return "E"
    if last in ("N", "2"):
        return "N"
    if last in ("Z", "3"):
        return "Z"
    return None


def _safe(s: str) -> str:
    return s.replace(".", "_").replace("/", "_").replace(" ", "_")


def _write_csv(
    path: Path,
    acc_x: np.ndarray,
    acc_y: np.ndarray,
    acc_z: np.ndarray,
) -> None:
    with open(path, "w") as fh:
        fh.write("acc_x,acc_y,acc_z\n")
        for x, y, z in zip(acc_x, acc_y, acc_z):
            fh.write(f"{x:.6f},{y:.6f},{z:.6f}\n")


# ── core download logic ───────────────────────────────────────────────────────

def _best_channels(client: Client, net: str, sta: str, loc: str,
                   t0: UTCDateTime, t1: UTCDateTime) -> list[str]:
    """Return the highest-priority channel set available for a station."""
    for pattern in CHANNEL_PRIORITIES:
        try:
            inv = client.get_stations(
                network=net, station=sta, location=loc,
                channel=pattern, starttime=t0, endtime=t1,
                level="channel",
            )
            channels = [
                ch.code
                for net_ in inv for sta_ in net_ for ch in sta_
            ]
            if channels:
                return channels
        except FDSNException:
            continue
    return []


def _process_event(
    client: Client,
    event,
    output_dir: Path,
    max_stations: int,
    verbose: bool,
) -> int:
    """Download and convert waveforms for one earthquake. Returns files written."""
    origin = event.preferred_origin()
    mag    = event.preferred_magnitude()
    if origin is None or mag is None:
        return 0

    ev_lat = origin.latitude
    ev_lon = origin.longitude
    ev_mag = mag.mag
    t0     = origin.time - PRE_EVENT_S
    t1     = origin.time + POST_EVENT_S

    tag = (f"M{ev_mag:.1f} {origin.time.strftime('%Y%m%d_%H%M%S')} "
           f"({ev_lat:.2f},{ev_lon:.2f})")
    print(f"\n  [{tag}]")

    # ── find nearby strong-motion stations (channel-level only for discovery) ──
    disc_inventory = None
    for chan_pattern in CHANNEL_PRIORITIES:
        try:
            disc_inventory = client.get_stations(
                latitude=ev_lat, longitude=ev_lon,
                maxradius=MAX_RADIUS_DEG,
                channel=chan_pattern,
                starttime=t0, endtime=t1,
                level="channel",   # cheap — just for station list
            )
            break
        except FDSNNoDataException:
            continue
        except FDSNException as e:
            print(f"    [!] Station query failed: {e}")
            return 0

    if disc_inventory is None:
        print("    [!] No strong-motion stations within radius — skipping")
        return 0

    # Collect unique (net, sta) pairs sorted by distance, cap at max_stations
    sta_list: list[tuple[float, str, str]] = []
    for net in disc_inventory:
        for sta in net:
            dist = locations2degrees(ev_lat, ev_lon, sta.latitude, sta.longitude)
            sta_list.append((dist, net.code, sta.code))

    sta_list.sort()
    sta_list = sta_list[:max_stations]

    written = 0
    for dist_deg, net_code, sta_code in sta_list:
        dist_km = dist_deg * 111.2
        if verbose:
            print(f"    Station {net_code}.{sta_code}  ({dist_km:.0f} km)")

        # ── download waveforms ────────────────────────────────────────────────
        st = None
        for chan_pattern in CHANNEL_PRIORITIES:
            try:
                st = client.get_waveforms(
                    network=net_code, station=sta_code,
                    location="*", channel=chan_pattern,
                    starttime=t0, endtime=t1,
                )
                if len(st) > 0:
                    break
            except FDSNNoDataException:
                continue
            except FDSNException as e:
                if verbose:
                    print(f"      [!] Waveform error: {e}")
                break

        if st is None or len(st) == 0:
            if verbose:
                print("      [!] No waveforms — skipping station")
            continue

        # ── fetch per-station response inventory (exact location match) ───────
        # Using a radius-search inventory can return a mismatched location code
        # and cause remove_sensitivity to silently apply the wrong gain.
        # Fetching by network+station ensures the exact location codes that
        # appear in the downloaded waveforms are present in the inventory.
        sta_inventory = None
        actual_channels = ",".join({tr.stats.channel for tr in st})
        try:
            sta_inventory = client.get_stations(
                network=net_code, station=sta_code,
                location="*", channel=actual_channels,
                starttime=t0, endtime=t1,
                level="response",
            )
        except FDSNException as e:
            if verbose:
                print(f"      [!] Response fetch failed: {e} — skipping station")
            continue

        # ── remove instrument sensitivity → physical units (m/s²) ────────────
        try:
            st.remove_sensitivity(inventory=sta_inventory)
        except Exception as e:
            if verbose:
                print(f"      [!] Sensitivity removal failed: {e} — skipping station")
            continue

        st.taper(max_percentage=0.05)
        st.merge(fill_value=0)

        # ── group traces by component role ────────────────────────────────────
        role_map: dict[str, np.ndarray] = {}
        hz_map:   dict[str, float]      = {}
        for tr in st:
            role = _channel_role(tr.stats.channel)
            if role and role not in role_map:
                role_map[role] = tr.data
                hz_map[role]   = tr.stats.sampling_rate

        if not role_map:
            continue

        # ── resample ──────────────────────────────────────────────────────────
        resampled: dict[str, np.ndarray] = {
            role: _resample(data, hz_map[role], TARGET_HZ)
            for role, data in role_map.items()
        }

        east  = resampled.get("E")
        north = resampled.get("N")
        vert  = resampled.get("Z")

        if east is not None and north is not None and vert is not None:
            n     = min(len(east), len(north), len(vert))
            acc_x = east[:n]
            acc_y = north[:n]
            acc_z = vert[:n] + G   # add gravity so |√(x²+y²+z²) − 9.81| works
            label = "3c"
        elif east is not None:
            n     = len(east)
            acc_x = east
            acc_y = np.zeros(n)
            acc_z = np.full(n, G)
            label = "E"
        elif north is not None:
            n     = len(north)
            acc_x = north
            acc_y = np.zeros(n)
            acc_z = np.full(n, G)
            label = "N"
        elif vert is not None:
            n     = len(vert)
            acc_x = vert
            acc_y = np.zeros(n)
            acc_z = np.full(n, G)
            label = "Z"
        else:
            continue

        # ── write CSV ─────────────────────────────────────────────────────────
        ev_tag  = origin.time.strftime("%Y%m%d_%H%M%S")
        out_name = (f"FDSN_{_safe(net_code)}_{_safe(sta_code)}_"
                    f"M{ev_mag:.1f}_{ev_tag}_{label}_{TARGET_HZ}hz.csv")
        out_path = output_dir / out_name

        _write_csv(out_path, acc_x, acc_y, acc_z)
        print(f"      → {out_name}  ({n} samples @ {TARGET_HZ} Hz, {dist_km:.0f} km)")
        written += 1

        time.sleep(0.3)   # be polite to the server

    return written


# ── main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    script_dir  = Path(__file__).parent
    default_out = (script_dir / ".." / "test" / "fixtures" / "earthquake").resolve()

    parser = argparse.ArgumentParser(
        description="Download FDSN strong-motion waveforms as 25 Hz CSV fixtures.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--datacenter", default="IRIS",
        choices=list(DATA_CENTERS.keys()),
        help="FDSN data center (default: IRIS)",
    )
    parser.add_argument(
        "--region", default="global",
        choices=list(REGIONS.keys()),
        help="Geographic region filter (default: global)",
    )
    parser.add_argument(
        "--minmag", type=float, default=5.5,
        help="Minimum magnitude (default: 5.5)",
    )
    parser.add_argument(
        "--maxmag", type=float, default=9.5,
        help="Maximum magnitude (default: 9.5)",
    )
    parser.add_argument(
        "--starttime", default=None,
        help="Start of event search window, YYYY-MM-DD (default: 3 years ago)",
    )
    parser.add_argument(
        "--endtime", default=None,
        help="End of event search window, YYYY-MM-DD (default: today)",
    )
    parser.add_argument(
        "--maxevents", type=int, default=20,
        help="Maximum number of earthquakes to process (default: 20)",
    )
    parser.add_argument(
        "--maxstations", type=int, default=5,
        help="Maximum stations per event (default: 5, nearest first)",
    )
    parser.add_argument(
        "--output", type=Path, default=default_out,
        help=f"Output directory (default: {default_out})",
    )
    parser.add_argument(
        "--verbose", action="store_true",
        help="Print per-station details",
    )
    args = parser.parse_args()

    # ── time window ───────────────────────────────────────────────────────────
    endtime   = UTCDateTime(args.endtime)   if args.endtime   else UTCDateTime()
    starttime = UTCDateTime(args.starttime) if args.starttime else endtime - 3 * 365 * 86400

    # ── bounding box ──────────────────────────────────────────────────────────
    bbox = REGIONS[args.region]
    bbox_kwargs: dict = {}
    if bbox is not None:
        minlat, maxlat, minlon, maxlon = bbox
        bbox_kwargs = dict(
            minlatitude=minlat, maxlatitude=maxlat,
            minlongitude=minlon, maxlongitude=maxlon,
        )

    args.output.mkdir(parents=True, exist_ok=True)

    print(f"FDSN Earthquake Fixture Downloader")
    print(f"  Data center : {args.datacenter}")
    print(f"  Region      : {args.region}")
    print(f"  Magnitude   : M{args.minmag}–M{args.maxmag}")
    print(f"  Window      : {starttime.strftime('%Y-%m-%d')} → {endtime.strftime('%Y-%m-%d')}")
    print(f"  Max events  : {args.maxevents}  (up to {args.maxstations} stations each)")
    print(f"  Output      : {args.output}\n")

    client = Client(DATA_CENTERS[args.datacenter])

    # ── event catalog ─────────────────────────────────────────────────────────
    print("Fetching event catalog…")
    try:
        catalog = client.get_events(
            starttime=starttime,
            endtime=endtime,
            minmagnitude=args.minmag,
            maxmagnitude=args.maxmag,
            orderby="magnitude",   # largest first → best chance of HN records
            **bbox_kwargs,
        )
    except FDSNNoDataException:
        sys.exit("No events found matching your criteria.")
    except FDSNException as e:
        sys.exit(f"Catalog query failed: {e}")

    events = list(catalog)[:args.maxevents]
    print(f"  Found {len(catalog)} events; processing {len(events)}.\n")

    total_written = 0
    for i, event in enumerate(events, 1):
        print(f"Event {i}/{len(events)}", end="")
        try:
            n = _process_event(
                client, event, args.output, args.maxstations, args.verbose
            )
            total_written += n
        except Exception as e:
            print(f"\n    [!] Unexpected error: {e}")
        time.sleep(1.0)   # pause between events

    print(f"\n{'─'*60}")
    print(f"Done — {total_written} CSV file(s) written to {args.output}")
    if total_written > 0:
        print("\nVerify with:")
        print("  flutter test test/earthquake_replay_test.dart")


if __name__ == "__main__":
    main()
