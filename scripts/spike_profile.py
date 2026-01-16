from __future__ import annotations

import argparse
from pathlib import Path
import numpy as np

from src.models.snn_dataset import WindowSpikeDataset


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True, help="config/enose_default.yaml")
    ap.add_argument("--data", default="data/processed/train_windows.npz", help="train_windows.npz or val_windows.npz")
    ap.add_argument("--max", type=int, default=5000, help="max windows to analyze")
    args = ap.parse_args()

    ds = WindowSpikeDataset(Path(args.data), Path(args.config))

    n = min(args.max, len(ds))
    T = int(ds[0][0].shape[0])     # window length
    C = int(ds[0][0].shape[1])     # channels (12)
    total_spikes = 0.0
    per_ch = np.zeros((C,), dtype=np.int64)

    for i in range(n):
        x_spk, _y = ds[i]               # x_spk: [T, 12]
        x = x_spk.numpy()
        per_ch += x.sum(axis=0).astype(np.int64)
        total_spikes += float(x.sum())

    # spikes per timestep across all windows
    spikes_per_timestep = total_spikes / (n * T)
    spikes_per_window = total_spikes / n

    # If sampling rate is 1Hz and window_len=10 => "per second" ~= per timestep
    print(f"[SPIKE PROFILE] windows={n}, T={T}, channels={C}")
    print(f"  spikes/window avg   = {spikes_per_window:.3f}")
    print(f"  spikes/timestep avg = {spikes_per_timestep:.3f}  (≈ spikes/sec if 1Hz)")

    print("  spikes per channel (total over analyzed windows):")
    for ch in range(C):
        print(f"    ch{ch:02d}: {int(per_ch[ch])}")

    # Simple guidance (heuristic)
    # Typical healthy ranges for learning: ~0.2..3 spikes/timestep depending on thresholds/model
    if spikes_per_timestep < 0.05:
        print("\n[HINT] Spikes are VERY sparse. Consider lowering encoder thresholds (e.g., x0.5).")
    elif spikes_per_timestep > 6.0:
        print("\n[HINT] Spikes are VERY dense/noisy. Consider raising thresholds (e.g., x1.5..2).")
    else:
        print("\n[OK] Spike density looks reasonable for training/inference.")


if __name__ == "__main__":
    main()
