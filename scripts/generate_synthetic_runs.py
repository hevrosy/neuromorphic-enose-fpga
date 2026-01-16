from __future__ import annotations

import argparse
import json
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Any, List, Tuple

import numpy as np
import pandas as pd
import yaml


def _unix_ms() -> int:
    return int(time.time() * 1000)


def _ensure_dir(p: Path) -> None:
    p.mkdir(parents=True, exist_ok=True)


def _make_run_id(label: str, batch_id: str, idx: int) -> str:
    ts = time.strftime("%Y%m%d_%H%M%S")
    return f"syn_{ts}_{batch_id}_{label}_{idx:03d}"


def _smoothstep(x: np.ndarray) -> np.ndarray:
    # Smooth rise 0..1
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


@dataclass
class SynthParams:
    T: int
    sample_rate_hz: float
    rng_seed: int


def synth_run(label: str, p: SynthParams) -> pd.DataFrame:
    """
    Generates one synthetic run with columns matching our raw CSV format:
    t_ms, mq135, mq3, mq4, temperature_c, humidity_rh, gas_resistance_ohm

    The dynamics are intentionally simple but realistic enough to validate the pipeline:
    - Slow drift + noise
    - VOC "rise" signature differs by class
    - T/RH correlate mildly with some channels
    - gas_resistance tends to decrease with VOC (common behavior for MOX gas resistance)
    """
    rng = np.random.default_rng(p.rng_seed)
    T = p.T
    t = np.arange(T, dtype=np.float32)
    tn = t / max(T - 1, 1)

    # Temperature & humidity: slow variation
    temp = 24.0 + 0.6 * np.sin(2 * np.pi * tn) + 0.15 * rng.standard_normal(T)
    rh = 45.0 + 2.0 * np.cos(2 * np.pi * tn + 0.3) + 0.5 * rng.standard_normal(T)

    # VOC profile by class (0..1)
    # Fresh: near-flat
    # Warning: moderate rise
    # Spoiled: strong rise + more variability
    if label.lower() == "fresh":
        voc = 0.08 + 0.03 * np.sin(2 * np.pi * tn * 1.3) + 0.02 * rng.standard_normal(T)
    elif label.lower() == "warning":
        rise = _smoothstep((tn - 0.15) / 0.65)  # starts rising after ~15%
        voc = 0.12 + 0.35 * rise + 0.03 * rng.standard_normal(T)
    elif label.lower() == "spoiled":
        rise = _smoothstep((tn - 0.10) / 0.55)
        voc = 0.18 + 0.65 * rise + 0.06 * rng.standard_normal(T)
    else:
        raise ValueError(f"Unknown label: {label}")

    voc = np.clip(voc, 0.0, 1.2)

    # Slow drift component (sensor drift)
    drift = 0.03 * tn + 0.01 * np.sin(2 * np.pi * tn * 0.35)

    # MQ channels (treated as "voltage-like" signals in arbitrary units)
    # Build different sensitivities per channel + mild T/RH dependence
    mq135 = 1.2 + 1.8 * voc + 0.3 * drift + 0.02 * (rh - 45.0) + 0.03 * rng.standard_normal(T)
    mq3   = 0.9 + 1.1 * voc + 0.2 * drift + 0.015 * (temp - 24.0) + 0.03 * rng.standard_normal(T)
    mq4   = 1.0 + 1.4 * voc + 0.25 * drift + 0.01 * (rh - 45.0) + 0.03 * rng.standard_normal(T)

    # BME gas resistance (ohms): decreases as VOC increases (simple inverse relation)
    gas_res = 180_000.0 * (1.0 - 0.55 * np.clip(voc, 0.0, 1.0)) + 8_000.0 * rng.standard_normal(T)
    gas_res = np.clip(gas_res, 5_000.0, 300_000.0)

    # Timestamps
    t0 = _unix_ms()
    t_ms = (t0 + (t * (1000.0 / p.sample_rate_hz))).astype(np.int64)

    df = pd.DataFrame({
        "t_ms": t_ms,
        "mq135": mq135.astype(np.float32),
        "mq3": mq3.astype(np.float32),
        "mq4": mq4.astype(np.float32),
        "temperature_c": temp.astype(np.float32),
        "humidity_rh": rh.astype(np.float32),
        "gas_resistance_ohm": gas_res.astype(np.float32),
    })
    return df


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True, help="config/enose_default.yaml")
    ap.add_argument("--runs-per-class", type=int, default=6, help="how many runs for each class")
    ap.add_argument("--batches", type=int, default=3, help="number of batches (B01..)")
    ap.add_argument("--seed", type=int, default=1234, help="base random seed")
    ap.add_argument("--out-raw", default=None, help="override raw dir")
    ap.add_argument("--out-meta", default=None, help="override meta dir")
    args = ap.parse_args()

    cfg = yaml.safe_load(Path(args.config).read_text(encoding="utf-8"))
    raw_dir = Path(args.out_raw) if args.out_raw else Path(cfg["paths"]["raw_dir"])
    meta_dir = Path(args.out_meta) if args.out_meta else Path(cfg["paths"]["meta_dir"])
    _ensure_dir(raw_dir)
    _ensure_dir(meta_dir)

    rate_hz = float(cfg["acquisition"]["sample_rate_hz"])
    duration_sec = int(cfg["acquisition"]["duration_sec"])
    T = int(duration_sec * rate_hz)

    classes: List[str] = list(cfg["labels"]["classes"])

    print(f"[INFO] Generating synthetic runs into:")
    print(f"  raw:  {raw_dir}")
    print(f"  meta: {meta_dir}")
    print(f"[INFO] classes={classes}, runs_per_class={args.runs_per_class}, batches={args.batches}, T={T}, rate={rate_hz}Hz")

    idx_global = 0
    for b in range(1, args.batches + 1):
        batch_id = f"B{b:02d}"
        for label in classes:
            for r in range(args.runs_per_class):
                run_id = _make_run_id(label, batch_id, r + 1)
                seed = args.seed + idx_global * 101
                idx_global += 1

                df = synth_run(label, SynthParams(T=T, sample_rate_hz=rate_hz, rng_seed=seed))

                csv_path = raw_dir / f"{run_id}.csv"
                meta_path = meta_dir / f"{run_id}.json"

                df.to_csv(csv_path, index=False)

                meta = {
                    "run_id": run_id,
                    "label": label,
                    "batch_id": batch_id,
                    "start_unix_ms": int(df["t_ms"].iloc[0]),
                    "notes": "synthetic run (generated)",
                    "config_path": str(Path(args.config)),
                    "config": cfg,
                    "synthetic": {
                        "seed": seed,
                        "generator": "generate_synthetic_runs.py",
                    }
                }
                meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")

                print(f"[OK] {run_id}")

    print("[DONE] synthetic generation complete")


if __name__ == "__main__":
    main()
