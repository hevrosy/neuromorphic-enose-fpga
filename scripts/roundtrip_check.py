from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import torch

from src.models.snn_dataset import WindowSpikeDataset
from src.models.snn_torch import SNNConfig, SNNLIF
from src.models.golden_inference_float import FloatSNNParams, FloatSNNWeights, infer_counts


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True, help="config/enose_default.yaml")
    ap.add_argument("--ckpt", default="exports/snn_ckpt.pt")
    ap.add_argument("--val", default="data/processed/val_windows.npz")
    ap.add_argument("--n", type=int, default=256, help="how many samples to test")
    args = ap.parse_args()

    ds = WindowSpikeDataset(Path(args.val), Path(args.config))
    ckpt = torch.load(Path(args.ckpt), map_location="cpu", weights_only=False)
    cfg_dict = ckpt["snn_config"]
    state = ckpt["state_dict"]

    cfg = SNNConfig(**cfg_dict)
    model = SNNLIF(cfg)
    model.load_state_dict(state)
    model.eval()

    # Extract float weights in [Nin,Nh] and [Nh,No]
    W1 = state["W1.weight"].detach().cpu().numpy().T.astype(np.float32)
    W2 = state["W2.weight"].detach().cpu().numpy().T.astype(np.float32)

    p = FloatSNNParams(
        n_in=cfg.n_in,
        n_hidden=cfg.n_hidden,
        n_out=cfg.n_out,
        window_len=cfg.window_len,
        leak_h_shift=cfg.leak_h_shift,
        leak_o_shift=cfg.leak_o_shift,
        th_h=float(cfg.th_h),
        th_o=float(cfg.th_o),
    )
    w = FloatSNNWeights(W1=W1, W2=W2)

    # Test subset
    n = min(args.n, len(ds))
    torch_correct = 0
    golden_correct = 0
    agree = 0

    for i in range(n):
        x_spk, y = ds[i]
        x_np = x_spk.numpy().astype(np.float32)  # [T,12]
        y_int = int(y.item())

        # Torch
        with torch.no_grad():
            logits = model(x_spk.unsqueeze(0))  # [1,3]
            pred_t = int(torch.argmax(logits, dim=1).item())

        # Golden float
        pred_g, conf_g, counts_g = infer_counts(x_np, w, p)

        torch_correct += int(pred_t == y_int)
        golden_correct += int(pred_g == y_int)
        agree += int(pred_t == pred_g)

    print(f"[ROUNDTRIP] N={n}")
    print(f"  torch_acc  = {torch_correct / n:.3f}")
    print(f"  golden_acc = {golden_correct / n:.3f}")
    print(f"  agree      = {agree / n:.3f}")
    print("If agree is ~1.0, the golden math matches the Torch forward (no quant yet).")


if __name__ == "__main__":
    main()
