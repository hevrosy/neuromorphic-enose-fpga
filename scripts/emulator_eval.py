from __future__ import annotations

import argparse
from pathlib import Path
import numpy as np

from src.models.snn_dataset import WindowSpikeDataset
from src.fpga.overlay_driver import SNNOverlayDriver


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True, help="config/enose_default.yaml")
    ap.add_argument("--val", default="data/processed/val_windows.npz")
    ap.add_argument("--exports", default="exports", help="directory with params.json + W1_q.npy + W2_q.npy")
    ap.add_argument("--n", type=int, default=2000)
    ap.add_argument("--window-len", type=int, default=10)
    args = ap.parse_args()

    ds = WindowSpikeDataset(Path(args.val), Path(args.config))
    drv = SNNOverlayDriver(exports_dir=Path(args.exports), window_len=args.window_len)

    n = min(args.n, len(ds))
    correct = 0
    confs = []

    for i in range(n):
        x_spk, y = ds[i]           # x_spk [T,12]
        res = drv.infer_from_spikes(x_spk.numpy())
        correct += int(res.pred_class == int(y.item()))
        confs.append(res.conf)

    acc = correct / n
    print(f"[EMULATOR EVAL] N={n}")
    print(f"  acc = {acc:.3f}")
    print(f"  conf(mean)={float(np.mean(confs)):.3f} conf(median)={float(np.median(confs)):.3f}")


if __name__ == "__main__":
    main()
