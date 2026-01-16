from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, Any, List, Tuple

import numpy as np
import pandas as pd
import yaml

# Make sure imports work when running as "python scripts/build_dataset.py" from repo root
import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))

from src.preprocess.baseline import baseline_correction
from src.preprocess.normalize import fit_scaler, apply_scaler, Scaler
from src.preprocess.windowing import make_windows


FEATURE_ORDER = ["mq135", "mq3", "mq4", "temperature_c", "humidity_rh", "gas_resistance_ohm"]


def moving_average(x: np.ndarray, win: int) -> np.ndarray:
    if win <= 1:
        return x
    # simple causal moving average
    y = np.empty_like(x, dtype=np.float32)
    for f in range(x.shape[1]):
        s = 0.0
        q = []
        for i in range(x.shape[0]):
            q.append(float(x[i, f]))
            s += q[-1]
            if len(q) > win:
                s -= q.pop(0)
            y[i, f] = s / len(q)
    return y


def label_to_int(label: str, classes: List[str]) -> int:
    if label not in classes:
        raise ValueError(f"Label '{label}' not in classes={classes}")
    return classes.index(label)


def load_run(csv_path: Path, meta_path: Path, classes: List[str]) -> Tuple[np.ndarray, int, Dict[str, Any]]:
    df = pd.read_csv(csv_path)
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    label = meta["label"]
    y = label_to_int(label, classes)

    missing = [c for c in FEATURE_ORDER if c not in df.columns]
    if missing:
        raise RuntimeError(f"Missing columns {missing} in {csv_path.name}")

    x = df[FEATURE_ORDER].to_numpy(dtype=np.float32)  # [T, F]
    return x, y, meta


def split_by_batch(run_items: List[Tuple[np.ndarray, int, Dict[str, Any]]], val_batch: str = "B03"):
    train, val = [], []
    for x, y, meta in run_items:
        b = meta.get("batch_id", "")
        (val if b == val_batch else train).append((x, y, meta))
    return train, val


def concat_windows(items: List[Tuple[np.ndarray, int, Dict[str, Any]]], window_len: int, stride: int) -> Tuple[np.ndarray, np.ndarray]:
    X_all, Y_all = [], []
    for x, y, _meta in items:
        Xw, Yw = make_windows(x, y, window_len=window_len, stride=stride)
        if Xw.shape[0] > 0:
            X_all.append(Xw)
            Y_all.append(Yw)
    if not X_all:
        return np.zeros((0, window_len, len(FEATURE_ORDER)), dtype=np.float32), np.zeros((0,), dtype=np.int64)
    return np.concatenate(X_all, axis=0), np.concatenate(Y_all, axis=0)


def save_scaler(path: Path, scaler: Scaler, feature_order: List[str]) -> None:
    np.savez(path, mean=scaler.mean.astype(np.float32), std=scaler.std.astype(np.float32), features=np.array(feature_order))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True, help="config/enose_default.yaml")
    ap.add_argument("--val-batch", default="B03", help="batch id reserved for validation (default B03)")
    ap.add_argument("--window-len", type=int, default=10, help="window length in samples (e.g., 10 seconds at 1 Hz)")
    ap.add_argument("--stride", type=int, default=1, help="stride in samples")
    ap.add_argument("--out", default="data/processed", help="output directory for .npz datasets")
    args = ap.parse_args()

    cfg = yaml.safe_load(Path(args.config).read_text(encoding="utf-8"))
    raw_dir = Path(cfg["paths"]["raw_dir"])
    meta_dir = Path(cfg["paths"]["meta_dir"])
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    classes: List[str] = list(cfg["labels"]["classes"])

    # preprocess config
    baseline_sec = int(cfg["preprocess"]["baseline_sec"])
    rate_hz = float(cfg["acquisition"]["sample_rate_hz"])
    baseline_len = max(1, int(baseline_sec * rate_hz))
    smooth_win = int(cfg["preprocess"].get("smoothing_window", 1))
    do_norm = bool(cfg["preprocess"].get("normalize", True))

    # Collect runs
    csv_files = sorted(raw_dir.glob("*.csv"))
    if not csv_files:
        raise RuntimeError(f"No CSV files found in {raw_dir}. Generate synthetic runs first.")

    run_items: List[Tuple[np.ndarray, int, Dict[str, Any]]] = []
    for csv_path in csv_files:
        meta_path = meta_dir / (csv_path.stem + ".json")
        if not meta_path.exists():
            continue
        x, y, meta = load_run(csv_path, meta_path, classes)
        run_items.append((x, y, meta))

    if not run_items:
        raise RuntimeError("No matched (csv,json) run pairs found.")

    # Split by batch
    train_items, val_items = split_by_batch(run_items, val_batch=args.val_batch)
    if not train_items or not val_items:
        print("[WARN] train or val is empty. Consider generating batches B01..B03 and using --val-batch B03.")

    def preprocess_runs(items: List[Tuple[np.ndarray, int, Dict[str, Any]]]) -> List[Tuple[np.ndarray, int, Dict[str, Any]]]:
        out = []
        for x, y, meta in items:
            x1 = baseline_correction(x, baseline_len=baseline_len)
            x2 = moving_average(x1, win=smooth_win).astype(np.float32)
            out.append((x2, y, meta))
        return out

    train_items = preprocess_runs(train_items)
    val_items = preprocess_runs(val_items)

    # Fit scaler on TRAIN only
    if do_norm and train_items:
        X_train_cat = np.concatenate([x for x, _, _ in train_items], axis=0)
        scaler = fit_scaler(X_train_cat)
        train_items = [(apply_scaler(x, scaler).astype(np.float32), y, m) for x, y, m in train_items]
        val_items = [(apply_scaler(x, scaler).astype(np.float32), y, m) for x, y, m in val_items]
        save_scaler(out_dir / "scaler.npz", scaler, FEATURE_ORDER)
        print("[OK] scaler saved:", out_dir / "scaler.npz")
    else:
        print("[INFO] normalization disabled or no train data; scaler not saved.")

    # Windowing
    Xtr, Ytr = concat_windows(train_items, window_len=args.window_len, stride=args.stride)
    Xva, Yva = concat_windows(val_items, window_len=args.window_len, stride=args.stride)

    np.savez(out_dir / "train_windows.npz", X=Xtr.astype(np.float32), y=Ytr.astype(np.int64), features=np.array(FEATURE_ORDER), classes=np.array(classes))
    np.savez(out_dir / "val_windows.npz", X=Xva.astype(np.float32), y=Yva.astype(np.int64), features=np.array(FEATURE_ORDER), classes=np.array(classes))

    summary = {
        "classes": classes,
        "features": FEATURE_ORDER,
        "train_windows": int(Xtr.shape[0]),
        "val_windows": int(Xva.shape[0]),
        "window_len": int(args.window_len),
        "stride": int(args.stride),
        "baseline_len": int(baseline_len),
        "smoothing_window": int(smooth_win),
        "val_batch": args.val_batch,
    }
    (out_dir / "dataset_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    print("[DONE] Dataset built")
    print("  Train:", Xtr.shape, Ytr.shape)
    print("  Val:  ", Xva.shape, Yva.shape)
    print("  Out:  ", out_dir.resolve())


if __name__ == "__main__":
    main()
