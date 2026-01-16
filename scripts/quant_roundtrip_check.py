from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch

from src.models.snn_dataset import WindowSpikeDataset
from src.models.snn_torch import SNNConfig, SNNLIF
from src.models.golden_inference_float import FloatSNNParams, FloatSNNWeights, infer_counts


def load_quant_exports(outdir: Path):
    params = json.loads((outdir / "params.json").read_text(encoding="utf-8"))
    w1_scale = float(params["quant"]["w1_scale"])
    w2_scale = float(params["quant"]["w2_scale"])
    W1q = np.load(outdir / "W1_q.npy")
    W2q = np.load(outdir / "W2_q.npy")
    # Dequant to float for golden float inference
    W1 = W1q.astype(np.float32) * w1_scale
    W2 = W2q.astype(np.float32) * w2_scale
    return W1, W2


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True, help="config/enose_default.yaml")
    ap.add_argument("--ckpt", default="exports/snn_ckpt.pt")
    ap.add_argument("--val", default="data/processed/val_windows.npz")
    ap.add_argument("--outdir", default="exports")
    ap.add_argument("--n", type=int, default=512)
    args = ap.parse_args()

    ds = WindowSpikeDataset(Path(args.val), Path(args.config))
    ckpt = torch.load(Path(args.ckpt), map_location="cpu", weights_only=False)
    cfg_dict = ckpt["snn_config"]
    state = ckpt["state_dict"]

    cfg = SNNConfig(**cfg_dict)
    model = SNNLIF(cfg)
    model.load_state_dict(state)
    model.eval()

    # Float weights from torch
    W1_float = state["W1.weight"].detach().cpu().numpy().T.astype(np.float32)  # [12,Nh]
    W2_float = state["W2.weight"].detach().cpu().numpy().T.astype(np.float32)  # [Nh,3]

    # Quant exports (int8 -> dequant float)
    W1_qdq, W2_qdq = load_quant_exports(Path(args.outdir))

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

    n = min(args.n, len(ds))
    agree_float = 0
    agree_quant = 0
    drop = 0

    for i in range(n):
        x_spk, y = ds[i]
        x_np = x_spk.numpy().astype(np.float32)
        y_int = int(y.item())

        # Torch pred
        with torch.no_grad():
            logits = model(x_spk.unsqueeze(0))
            pred_t = int(torch.argmax(logits, dim=1).item())

        # Golden float pred (from torch float weights)
        pred_gf, _, _ = infer_counts(x_np, FloatSNNWeights(W1=W1_float, W2=W2_float), p)

        # Golden quant pred (from exported int8 weights dequant)
        pred_gq, _, _ = infer_counts(x_np, FloatSNNWeights(W1=W1_qdq, W2=W2_qdq), p)

        agree_float += int(pred_t == pred_gf)
        agree_quant += int(pred_t == pred_gq)
        drop += int(pred_gf != pred_gq)  # quant changes decision relative to float golden

    print(f"[QUANT ROUNDTRIP] N={n}")
    print(f"  agree(torch vs golden-float) = {agree_float / n:.3f}")
    print(f"  agree(torch vs golden-quant) = {agree_quant / n:.3f}")
    print(f"  decision_change(float->quant)= {drop / n:.3f}")
    print("If golden-quant agree is high (e.g. >0.95), int8 export is safe for FPGA.")


if __name__ == "__main__":
    main()
