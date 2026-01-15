from __future__ import annotations

import argparse
import csv
import json
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple

import yaml

from .sensors_xadc import XADCChannel, read_xadc_channels
from .sensor_bme688 import BME688Config, read_bme688


@dataclass
class RunInfo:
    run_id: str
    label: str
    batch_id: str
    start_unix_ms: int
    config: Dict[str, Any]


def _unix_ms() -> int:
    return int(time.time() * 1000)


def _ensure_dir(p: Path) -> None:
    p.mkdir(parents=True, exist_ok=True)


def _make_run_id(label: str, batch_id: str) -> str:
    ts = time.strftime("%Y%m%d_%H%M%S")
    return f"{ts}_{batch_id}_{label}"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True, help="Path to YAML config")
    ap.add_argument("--label", required=True, help="Fresh|Warning|Spoiled")
    ap.add_argument("--batch", required=True, help="Batch id e.g. B01")
    ap.add_argument("--notes", default="", help="Optional notes for meta JSON")
    args = ap.parse_args()

    cfg_path = Path(args.config)
    cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8"))

    raw_dir = Path(cfg["paths"]["raw_dir"])
    meta_dir = Path(cfg["paths"]["meta_dir"])
    _ensure_dir(raw_dir)
    _ensure_dir(meta_dir)

    acq = cfg["acquisition"]
    rate_hz = float(acq["sample_rate_hz"])
    period_s = 1.0 / rate_hz
    duration_sec = int(acq["duration_sec"])
    warmup_sec = int(acq.get("warmup_sec", 0))

    label = args.label
    batch_id = args.batch
    run_id = _make_run_id(label, batch_id)

    run_info = RunInfo(
        run_id=run_id,
        label=label,
        batch_id=batch_id,
        start_unix_ms=_unix_ms(),
        config=cfg,
    )

    # Setup channels
    xadc_cfg = cfg.get("xadc", {})
    xadc_enable = bool(xadc_cfg.get("enable", True))
    extra_scale = xadc_cfg.get("extra_scale", None)

    xadc_channels: Tuple[XADCChannel, ...] = tuple(
        XADCChannel(name=c["name"], iio_channel_index=int(c["iio_channel_index"]))
        for c in xadc_cfg.get("channels", [])
    )

    bme_cfg = cfg.get("bme688", {})
    bme_enable = bool(bme_cfg.get("enable", True))
    bme = BME688Config(
        i2c_bus=int(bme_cfg.get("i2c_bus", 1)),
        i2c_addr=int(bme_cfg.get("i2c_addr", 0x76)),
    )

    # Output files
    csv_path = raw_dir / f"{run_id}.csv"
    meta_path = meta_dir / f"{run_id}.json"

    # Define CSV header
    header = ["t_ms"]
    if xadc_enable:
        header += [f"{ch.name}" for ch in xadc_channels]
    if bme_enable:
        header += ["temperature_c", "humidity_rh", "gas_resistance_ohm"]

    print(f"[INFO] run_id={run_id}")
    print(f"[INFO] writing: {csv_path}")
    print(f"[INFO] writing: {meta_path}")
    print(f"[INFO] sample_rate={rate_hz} Hz, duration={duration_sec}s, warmup_discard={warmup_sec}s")

    # Write meta
    meta = {
        "run_id": run_info.run_id,
        "label": run_info.label,
        "batch_id": run_info.batch_id,
        "start_unix_ms": run_info.start_unix_ms,
        "notes": args.notes,
        "config_path": str(cfg_path),
        "config": cfg,
    }
    meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")

    # Acquisition loop
    t0 = time.time()
    n_samples = int(duration_sec * rate_hz)
    warmup_samples = int(warmup_sec * rate_hz)

    with csv_path.open("w", newline="", encoding="utf-8") as f:
        wr = csv.DictWriter(f, fieldnames=header)
        wr.writeheader()

        for n in range(n_samples):
            loop_start = time.time()
            t_ms = _unix_ms()

            row: Dict[str, Any] = {"t_ms": t_ms}

            if xadc_enable:
                xvals = read_xadc_channels(xadc_channels, extra_scale=extra_scale)
                row.update(xvals)

            if bme_enable:
                bvals = read_bme688(bme)
                row.update(bvals)

            if n >= warmup_samples:
                wr.writerow(row)

            # timing control
            elapsed = time.time() - loop_start
            sleep_s = period_s - elapsed
            if sleep_s > 0:
                time.sleep(sleep_s)

            if (n + 1) % max(int(rate_hz), 1) == 0:
                sec = int((time.time() - t0))
                print(f"[INFO] t={sec}s / {duration_sec}s")

    print("[DONE] acquisition finished")


if __name__ == "__main__":
    main()
