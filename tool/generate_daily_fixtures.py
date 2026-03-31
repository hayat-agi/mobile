#!/usr/bin/env python3
"""
Generate synthetic daily-activity CSV fixtures for false-positive testing.

Each scenario is carefully designed so the earthquake detection algorithm
(STA/LTA + gate + 2-of-3 Layer 2) does NOT fire.  Run the flutter test
afterwards to confirm:

    python generate_daily_fixtures.py [output_dir]
    flutter test test/earthquake_replay_test.dart

Default output: ../test/fixtures/daily/  (relative to this script)

Scenarios
---------
  table_still        – phone face-up on desk, sensor noise only
  walking_normal     – 1.8 Hz gait, moderate vertical bounce
  walking_fast       – 2.2 Hz gait, higher amplitude
  bus_vibration      – broadband road + engine vibration
  phone_pickup       – 0.3 s sharp impulse after 60 s of stillness
  typing_desk        – micro-keypress impacts at ~4 Hz
  pocket_walk        – phone in trouser pocket, dampened walk signal
  staircase          – heavier step impacts, ~1.5 Hz
  car_highway        – sustained highway road noise
  sudden_jog         – walking then 30 s of jogging then walking

Why these don't trigger
-----------------------
  table_still / typing_desk / phone_pickup:
      LTA average stays below minLtaAverage (0.05 m/s²) — ratio is never
      computed, so the gate can never be met.

  All walking / bus / car / jog scenarios:
      The LTA (30-second window) builds up to match the ambient activity level.
      Once the LTA is warm, ratio ≈ STA/LTA ≈ 1.0–2.0 throughout, well below
      the 3.0 threshold.  Even a sudden jog from a walking baseline only drives
      the ratio to ~2.0–2.5 for a few seconds before the LTA catches up.

Algorithm constants assumed (from earthquake_config.dart):
  samplesPerSecond   = 25
  staWindowSamples   = 25   (1 s)
  ltaWindowSamples   = 750  (30 s)
  staLtaTriggerThreshold = 3.5
  minLtaAverage      = 0.03
  noiseFloorMs2      = 0.03
  triggerWindowSamples   = 50  (2 s)
  minTriggersInWindow    = 20  (40 %)
  stationarityVarianceThreshold = 0.005
"""

import math
import random
import sys
from pathlib import Path

SAMPLE_RATE = 25  # Hz — must match EarthquakeConfig.samplesPerSecond
G = 9.81          # m/s²


# ── helpers ──────────────────────────────────────────────────────────────────

def _noise(scale: float) -> float:
    return random.gauss(0.0, scale)


def _write_csv(path: Path, samples: list[tuple[float, float, float]]) -> None:
    with open(path, "w") as fh:
        fh.write("acc_x,acc_y,acc_z\n")
        for x, y, z in samples:
            fh.write(f"{x:.6f},{y:.6f},{z:.6f}\n")
    print(f"  Written: {path.name}  ({len(samples)} samples @ {SAMPLE_RATE} Hz)")


# ── scenario generators ───────────────────────────────────────────────────────

def gen_table_still(duration_s: float = 120.0) -> list[tuple[float, float, float]]:
    """
    Phone face-up on a desk.  Sensor noise ≈ 0.008–0.012 m/s² RMS.
    Net-acc ≈ 0.01 m/s²  →  LTA avg << minLtaAverage (0.05)  →  no ratio computed.
    """
    n = int(duration_s * SAMPLE_RATE)
    return [(_noise(0.008), _noise(0.008), G + _noise(0.010)) for _ in range(n)]


def gen_walking_normal(duration_s: float = 120.0) -> list[tuple[float, float, float]]:
    """
    Casual walk, ~1.8 Hz step frequency.
    Net-acc oscillates 0 → 0.55 m/s² at twice step frequency.
    LTA avg ≈ 0.35 m/s²,  max STA/LTA ≈ 1.6  →  no trigger.
    """
    n = int(duration_s * SAMPLE_RATE)
    f = 1.8
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Vertical bounce: always positive, peaking at each footfall
        z_ac = 0.55 * abs(math.sin(math.pi * f * t))
        x = 0.25 * math.sin(2 * math.pi * f * t + 0.3) + _noise(0.03)
        y = 0.15 * math.sin(2 * math.pi * f * t + 1.2) + _noise(0.02)
        z = G + z_ac + _noise(0.03)
        samples.append((x, y, z))
    return samples


def gen_walking_fast(duration_s: float = 120.0) -> list[tuple[float, float, float]]:
    """
    Brisk walk at ~2.2 Hz, higher vertical amplitude.
    Max STA/LTA ≈ 1.7  →  no trigger.
    """
    n = int(duration_s * SAMPLE_RATE)
    f = 2.2
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        z_ac = 0.80 * abs(math.sin(math.pi * f * t))
        x = 0.40 * math.sin(2 * math.pi * f * t + 0.5) + _noise(0.04)
        y = 0.20 * math.sin(2 * math.pi * f * t + 1.5) + _noise(0.03)
        z = G + z_ac + _noise(0.04)
        samples.append((x, y, z))
    return samples


def gen_bus_vibration(duration_s: float = 120.0) -> list[tuple[float, float, float]]:
    """
    City bus: low-frequency road bumps + broadband engine noise.
    LTA adapts to ~0.14 m/s².  Ratio ≈ 1.1–1.4  →  no trigger.
    """
    n = int(duration_s * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        road  = 0.12 * math.sin(2 * math.pi * 1.5 * t + 0.7)
        road += 0.08 * math.sin(2 * math.pi * 2.3 * t + 1.2)
        road += 0.05 * math.sin(2 * math.pi * 0.8 * t + 2.1)
        x = road * 0.40 + _noise(0.03)
        y = road * 0.25 + _noise(0.02)
        z = G + road + _noise(0.03)
        samples.append((x, y, z))
    return samples


def gen_phone_pickup(duration_s: float = 120.0) -> list[tuple[float, float, float]]:
    """
    Phone still → single 0.3 s pickup impulse at t=60 s → still again.
    During the still segments: LTA avg ≈ 0.01 < minLtaAverage  →  no ratio.
    The 7-sample impulse is far too short to fill the 50-sample gate window.
    """
    n           = int(duration_s * SAMPLE_RATE)
    pickup_at   = int(60 * SAMPLE_RATE)
    pickup_len  = int(0.30 * SAMPLE_RATE)   # ~7 samples
    samples = []
    for i in range(n):
        if pickup_at <= i < pickup_at + pickup_len:
            phase   = (i - pickup_at) / pickup_len
            impulse = 4.0 * math.sin(math.pi * phase)   # bell-shaped spike
            x = impulse * 0.8 + _noise(0.05)
            y = impulse * 0.5 + _noise(0.05)
            z = G - impulse * 0.3 + _noise(0.05)
        else:
            x = _noise(0.008)
            y = _noise(0.008)
            z = G + _noise(0.010)
        samples.append((x, y, z))
    return samples


def gen_typing_desk(duration_s: float = 120.0) -> list[tuple[float, float, float]]:
    """
    Laptop keyboard typing next to the phone, ~4 keystroke impacts/s.
    Net-acc ≈ 0.015–0.025 m/s²  →  LTA avg < minLtaAverage  →  no trigger.
    """
    n = int(duration_s * SAMPLE_RATE)
    f = 4.0
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        key = 0.04 * max(0.0, math.sin(2 * math.pi * f * t))
        x = _noise(0.007) + key * 0.10
        y = _noise(0.007) + key * 0.10
        z = G + key + _noise(0.008)
        samples.append((x, y, z))
    return samples


def gen_pocket_walk(duration_s: float = 120.0) -> list[tuple[float, float, float]]:
    """
    Phone in trouser pocket: walk signal dampened by body + fabric.
    Max STA/LTA ≈ 1.4  →  no trigger.
    """
    n = int(duration_s * SAMPLE_RATE)
    f = 1.9
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        z_ac = 0.30 * abs(math.sin(math.pi * f * t))
        x = 0.15 * math.sin(2 * math.pi * f * t)       + _noise(0.02)
        y = 0.08 * math.sin(2 * math.pi * f * t + 1.0) + _noise(0.02)
        z = G + z_ac + _noise(0.025)
        samples.append((x, y, z))
    return samples


def gen_staircase(duration_s: float = 120.0) -> list[tuple[float, float, float]]:
    """
    Stair climbing: heavier vertical impacts at ~1.5 Hz, irregular rhythm.
    LTA avg ≈ 0.50 m/s².  Max STA/LTA ≈ 1.8  →  no trigger.
    """
    n = int(duration_s * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Slight irregularity in step timing
        f_local = 1.5 + 0.1 * math.sin(2 * math.pi * 0.08 * t)
        z_ac = 0.70 * abs(math.sin(math.pi * f_local * t))
        x = 0.30 * math.sin(2 * math.pi * f_local * t + 0.4) + _noise(0.04)
        y = 0.20 * math.sin(2 * math.pi * f_local * t + 1.3) + _noise(0.03)
        z = G + z_ac + _noise(0.04)
        samples.append((x, y, z))
    return samples


def gen_car_highway(duration_s: float = 120.0) -> list[tuple[float, float, float]]:
    """
    Highway driving: sustained broadband vibration, slightly higher than city bus.
    LTA adapts to ~0.18 m/s².  Ratio ≈ 1.0–1.3  →  no trigger.
    """
    n = int(duration_s * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Road surface + engine harmonics
        vib  = 0.10 * math.sin(2 * math.pi * 3.5 * t + 0.1)
        vib += 0.08 * math.sin(2 * math.pi * 7.0 * t + 0.9)
        vib += 0.06 * math.sin(2 * math.pi * 1.2 * t + 1.5)
        x = vib * 0.5 + _noise(0.03)
        y = vib * 0.3 + _noise(0.02)
        z = G + vib + _noise(0.03)
        samples.append((x, y, z))
    return samples


def gen_sudden_jog(duration_s: float = 150.0) -> list[tuple[float, float, float]]:
    """
    Walk (30 s) → jog (30 s) → walk (90 s).
    Worst-case ratio at walk→jog transition ≈ 2.3  →  gate never fills  →  no trigger.
    During jogging the LTA catches up quickly (30-s window), keeping ratio ≈ 1.5.
    """
    n       = int(duration_s * SAMPLE_RATE)
    jog_start = int(30 * SAMPLE_RATE)
    jog_end   = int(60 * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        if i < jog_start or i >= jog_end:
            f, az, ax = 1.8, 0.55, 0.25
        else:
            f, az, ax = 2.8, 1.20, 0.55  # jogging: higher freq, larger amp
        z_ac = az * abs(math.sin(math.pi * f * t))
        x = ax * math.sin(2 * math.pi * f * t + 0.3) + _noise(0.04)
        y = ax * 0.6 * math.sin(2 * math.pi * f * t + 1.2) + _noise(0.03)
        z = G + z_ac + _noise(0.04)
        samples.append((x, y, z))
    return samples


def gen_hand_holding_still(duration_s: float = 120.0) -> list[tuple[float, float, float]]:
    """
    Phone held still in hand for 120 seconds — the primary FP scenario.
    Postural micro-sway (0.3–0.8 Hz) + physiological tremor (8–12 Hz).
    Net-acc variance ≈ 0.01–0.02  →  stationarity gate blocks trigger.
    Even without stationarity gate, LTA variance is high  →  LTA stability guard blocks.
    """
    n = int(duration_s * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Postural sway: slow, low-freq drift
        sway_x = 0.06 * math.sin(2 * math.pi * 0.4 * t + 0.3)
        sway_y = 0.04 * math.sin(2 * math.pi * 0.55 * t + 1.8)
        sway_z = 0.03 * math.sin(2 * math.pi * 0.35 * t + 0.7)
        # Physiological tremor: small, high-freq component
        tremor = 0.015 * math.sin(2 * math.pi * 9.0 * t)
        x = sway_x + tremor * 0.8 + _noise(0.012)
        y = sway_y + tremor * 0.5 + _noise(0.010)
        z = G + sway_z + tremor + _noise(0.015)
        samples.append((x, y, z))
    return samples


def gen_hand_holding_walk(duration_s: float = 120.0) -> list[tuple[float, float, float]]:
    """
    Phone held in hand while walking (e.g. looking at screen).
    Combination of walk gait + hand sway. Higher net-acc variance than
    hand_holding_still. Stationarity gate + gyroscope veto should catch this.
    """
    n = int(duration_s * SAMPLE_RATE)
    f = 1.8  # walking frequency
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Walking component (dampened by arm)
        z_ac = 0.35 * abs(math.sin(math.pi * f * t))
        walk_x = 0.20 * math.sin(2 * math.pi * f * t + 0.3)
        walk_y = 0.10 * math.sin(2 * math.pi * f * t + 1.2)
        # Hand sway component
        sway_x = 0.08 * math.sin(2 * math.pi * 0.5 * t + 0.9)
        sway_y = 0.05 * math.sin(2 * math.pi * 0.6 * t + 2.1)
        x = walk_x + sway_x + _noise(0.025)
        y = walk_y + sway_y + _noise(0.020)
        z = G + z_ac + _noise(0.030)
        samples.append((x, y, z))
    return samples


# ── registry ─────────────────────────────────────────────────────────────────

SCENARIOS: list[tuple[str, object]] = [
    ("table_still",        gen_table_still),
    ("walking_normal",     gen_walking_normal),
    ("walking_fast",       gen_walking_fast),
    ("bus_vibration",      gen_bus_vibration),
    ("phone_pickup",       gen_phone_pickup),
    ("typing_desk",        gen_typing_desk),
    ("pocket_walk",        gen_pocket_walk),
    ("staircase",          gen_staircase),
    ("car_highway",        gen_car_highway),
    ("sudden_jog",         gen_sudden_jog),
    ("hand_holding_still", gen_hand_holding_still),
    ("hand_holding_walk",  gen_hand_holding_walk),
]


def main() -> None:
    script_dir = Path(__file__).parent
    default_out = script_dir / ".." / "test" / "fixtures" / "daily"

    output_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else default_out
    output_dir = output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    random.seed(42)  # reproducible builds

    print(f"Generating synthetic daily-activity fixtures\n→ {output_dir}\n")
    for name, gen_fn in SCENARIOS:
        samples = gen_fn()
        out_path = output_dir / f"synthetic_{name}_25hz.csv"
        _write_csv(out_path, samples)

    print(f"\nDone — {len(SCENARIOS)} fixture(s) written.")
    print("\nVerify with:")
    print("  flutter test test/earthquake_replay_test.dart")


if __name__ == "__main__":
    main()
