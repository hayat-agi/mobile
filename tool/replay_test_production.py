"""
Earthquake detection replay test — production threshold values.
Mirrors the Dart pipeline exactly (StaLtaCalculator + FeatureExtractor + rolling gate).

Production thresholds (from earthquake_config.dart comments):
  staLtaTriggerThreshold : 2.8
  minTriggersInWindow    : 18  (of 50)
  iqrThreshold           : 0.35
  zcThreshold            : 4.0
  cavThreshold           : 0.55
  kurtosisVoteThreshold  : 10.0
"""

import math, csv, os, sys
from collections import deque
from pathlib import Path
from statistics import mean, variance

# ── Config ────────────────────────────────────────────────────────────────────
SAMPLING_MS          = 40
SAMPLES_PER_SEC      = 1000 // SAMPLING_MS   # 25
G                    = 9.81

STA_WINDOW           = SAMPLES_PER_SEC        # 25
LTA_WINDOW           = SAMPLES_PER_SEC * 30   # 750
STA_LTA_THRESHOLD    = 2.5
NOISE_FLOOR          = 0.0
MIN_LTA_AVERAGE      = 0.0
LTA_MAX_VARIANCE     = 5.0

TRIGGER_WINDOW       = SAMPLES_PER_SEC * 2    # 50
MIN_TRIGGERS         = 10

FEATURE_WINDOW       = SAMPLES_PER_SEC * 4    # 100
IQR_THRESHOLD        = 0.35
ZC_THRESHOLD         = 4.0
CAV_THRESHOLD        = 0.55
KURTOSIS_THRESHOLD   = 10.0

POST_TRIGGER_SAMPLES = SAMPLES_PER_SEC        # 25

# ── STA/LTA ───────────────────────────────────────────────────────────────────
class StaLta:
    def __init__(self):
        self._sta = deque()
        self._lta = deque()
        self._sta_sum = 0.0
        self._lta_sum = 0.0
        self._lta_sq_sum = 0.0
        self._ratio = 0.0
        self._frozen = False

    def freeze(self):   self._frozen = True
    def unfreeze(self): self._frozen = False

    @property
    def ratio(self): return self._ratio

    @property
    def triggered(self): return self._ratio >= STA_LTA_THRESHOLD

    @property
    def lta_ready(self): return len(self._lta) >= LTA_WINDOW

    def add(self, x, y, z):
        mag = math.sqrt(x*x + y*y + z*z)
        net = abs(mag - G)
        if net < NOISE_FLOOR:
            net = 0.0

        # STA
        self._sta_sum += net
        self._sta.append(net)
        if len(self._sta) > STA_WINDOW:
            self._sta_sum -= self._sta.popleft()

        # LTA (only advance when not frozen)
        if not self._frozen:
            self._lta_sum += net
            self._lta_sq_sum += net * net
            self._lta.append(net)
            if len(self._lta) > LTA_WINDOW:
                old = self._lta.popleft()
                self._lta_sum -= old
                self._lta_sq_sum -= old * old

        if not self.lta_ready:
            self._ratio = 0.0
            return 0.0

        lta_mean = self._lta_sum / len(self._lta)
        if lta_mean < MIN_LTA_AVERAGE:
            self._ratio = 0.0
            return 0.0

        # LTA variance guard
        lta_var = (self._lta_sq_sum / len(self._lta)) - lta_mean * lta_mean
        if lta_var > LTA_MAX_VARIANCE:
            self._ratio = 0.0
            return 0.0

        sta_mean = self._sta_sum / len(self._sta)
        self._ratio = sta_mean / lta_mean if lta_mean > 0 else 0.0
        return self._ratio

# ── Feature extraction ────────────────────────────────────────────────────────
def percentile(sorted_data, p):
    n = len(sorted_data)
    idx = (n - 1) * p / 100.0
    lo, hi = int(idx), min(int(idx) + 1, n - 1)
    return sorted_data[lo] + (sorted_data[hi] - sorted_data[lo]) * (idx - lo)

def analyze_features(samples):
    if len(samples) < 10:
        return None
    n = len(samples)
    s = sorted(samples)
    q1 = percentile(s, 25)
    q3 = percentile(s, 75)
    iqr = q3 - q1

    # Zero-crossing rate
    mean_v = sum(samples) / n
    centered = [v - mean_v for v in samples]
    zc = sum(1 for i in range(1, n) if centered[i-1] * centered[i] < 0)
    zc_rate = zc / (n / SAMPLES_PER_SEC)

    # CAV
    dt = 1.0 / SAMPLES_PER_SEC
    cav = sum(abs(v) for v in samples) * dt

    # Peak
    peak = max(abs(v) for v in samples)

    # Kurtosis
    m = sum(samples) / n
    var = sum((v - m)**2 for v in samples) / n
    if var < 1e-10:
        kurt = 0.0
    else:
        kurt = (sum((v - m)**4 for v in samples) / n) / (var**2) - 3.0

    return dict(iqr=iqr, zc=zc_rate, cav=cav, peak=peak, kurtosis=kurt)

def is_earthquake(f):
    passed = 0
    if f['iqr'] >= IQR_THRESHOLD:   passed += 1
    if f['zc']  >= ZC_THRESHOLD:    passed += 1
    if f['cav'] >= CAV_THRESHOLD:   passed += 1
    if f['kurtosis'] < KURTOSIS_THRESHOLD: passed += 1
    return passed >= 2

def feature_pass_count(f):
    n = 0
    if f['iqr'] >= IQR_THRESHOLD:   n += 1
    if f['zc']  >= ZC_THRESHOLD:    n += 1
    if f['cav'] >= CAV_THRESHOLD:   n += 1
    if f['kurtosis'] < KURTOSIS_THRESHOLD: n += 1
    return n

# ── CSV loader ────────────────────────────────────────────────────────────────
def load_csv(path):
    rows = []
    with open(path, newline='') as fh:
        for line in fh:
            t = line.strip()
            if not t or t[0].isalpha():
                continue
            parts = t.split(',')
            if len(parts) < 3:
                continue
            try:
                rows.append((float(parts[0]), float(parts[1]), float(parts[2])))
            except ValueError:
                pass
    return rows

# ── Pipeline runner ───────────────────────────────────────────────────────────
def run_pipeline(samples):
    sta_lta = StaLta()
    feat_buf = deque()
    trig_win = deque()
    trig_above = 0
    max_ratio = 0.0
    max_trig_count = 0
    gate_ever_met = False
    best_feat = None
    best_pass = -1
    collecting = False
    post_count = 0

    for i, (x, y, z) in enumerate(samples):
        mag = math.sqrt(x*x + y*y + z*z)
        net = abs(mag - G)

        ratio = sta_lta.add(x, y, z)
        if ratio > max_ratio:
            max_ratio = ratio

        feat_buf.append(net)
        if len(feat_buf) > FEATURE_WINDOW:
            feat_buf.popleft()

        above = sta_lta.triggered
        if above: trig_above += 1
        trig_win.append(above)
        if len(trig_win) > TRIGGER_WINDOW:
            if trig_win.popleft(): trig_above -= 1

        if len(trig_win) < TRIGGER_WINDOW:
            continue
        if trig_above > max_trig_count:
            max_trig_count = trig_above

        if trig_above < MIN_TRIGGERS:
            sta_lta.unfreeze()
            collecting = False
            post_count = 0
            continue

        sta_lta.freeze()
        gate_ever_met = True

        if not collecting:
            collecting = True
            post_count = 0
        post_count += 1
        if post_count < POST_TRIGGER_SAMPLES:
            continue
        collecting = False
        post_count = 0

        feat = analyze_features(list(feat_buf))
        if feat:
            pc = feature_pass_count(feat)
            if pc > best_pass:
                best_pass = pc
                best_feat = feat
            if is_earthquake(feat):
                return dict(triggered=True, total=len(samples), max_ratio=max_ratio,
                            gate_met=True, max_trig=max_trig_count,
                            trig_idx=i, ratio=ratio, feat=feat, best_feat=best_feat)

    return dict(triggered=False, total=len(samples), max_ratio=max_ratio,
                gate_met=gate_ever_met, max_trig=max_trig_count,
                trig_idx=None, ratio=None, feat=None, best_feat=best_feat)

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    fixture_dir = Path(__file__).parent.parent / 'test' / 'fixtures' / 'earthquake'
    if not fixture_dir.exists():
        print(f'No fixture dir: {fixture_dir}')
        sys.exit(1)

    files = sorted(fixture_dir.glob('*.csv'))
    if not files:
        print('No CSV files found.')
        sys.exit(1)

    results = []
    for f in files:
        samples = load_csv(f)
        r = run_pipeline(samples)
        r['name'] = f.name
        results.append(r)

    # ── Table ─────────────────────────────────────────────────────────────────
    W = [38, 6, 5, 5, 6, 6, 5, 5, 5, 5]
    def cell(s, w): return str(s)[:w].ljust(w)
    hdrs = ['File','Trig','Gate','MaxCt','Samp','Ratio','IQR','ZC','CAV','Kurt']
    print('\n' + '─'*75)
    print('  Earthquake Detection — PRODUCTION thresholds')
    print(f'  STA/LTA≥{STA_LTA_THRESHOLD}  gate {MIN_TRIGGERS}/{TRIGGER_WINDOW}  noiseFloor={NOISE_FLOOR}  minLTA={MIN_LTA_AVERAGE}')
    print(f'  IQR≥{IQR_THRESHOLD}  ZC≥{ZC_THRESHOLD}  CAV≥{CAV_THRESHOLD}  kurt<{KURTOSIS_THRESHOLD}')
    print('─'*75)
    print('| ' + ' | '.join(cell(h, W[i]) for i, h in enumerate(hdrs)) + ' |')
    print('|-' + '-|-'.join('-'*w for w in W) + '-|')

    tp = fn = 0
    for r in results:
        f = r['feat'] if r['triggered'] else r['best_feat']
        row = [
            r['name'],
            'YES' if r['triggered'] else 'NO',
            'Y' if r['gate_met'] else 'N',
            str(r['max_trig']),
            str(r['total']),
            f"{(r['ratio'] if r['triggered'] else r['max_ratio']):.2f}",
            f"{f['iqr']:.2f}"      if f else '-',
            f"{f['zc']:.2f}"       if f else '-',
            f"{f['cav']:.2f}"      if f else '-',
            f"{f['kurtosis']:.1f}" if f else '-',
        ]
        print('| ' + ' | '.join(cell(v, W[i]) for i, v in enumerate(row)) + ' |')
        if r['triggered']: tp += 1
        else:               fn += 1

    print('─'*75)
    print(f'  TP={tp}  FN={fn}  (total earthquake files: {len(results)})')
    print('─'*75 + '\n')

if __name__ == '__main__':
    main()
