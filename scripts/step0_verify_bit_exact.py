"""
Step 0.1 — Bit-exact verification across all three inference paths.

Compares:
  1) Torch forward  (float32, surrogate gradient at eval = hard threshold)
  2) Golden float   (float32, numpy, same math as torch)
  3) Golden int     (int32 arithmetic, bit-shift leak — matches planned FPGA RTL)

Usage (from project root):
  python scripts/step0_verify_bit_exact.py --config config/enose_default.yaml

Prerequisites:
  - Already ran generate_synthetic_runs.py
  - Already ran build_dataset.py
  - Already ran snn_train.py  (checkpoint at exports/snn_ckpt.pt)
  - Already ran export_weights.py (exports/W1_q.npy, W2_q.npy, params.json)
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Tuple

import numpy as np
import torch

# ── project imports ──
sys.path.append(str(Path(__file__).resolve().parents[1]))

from src.models.snn_dataset import WindowSpikeDataset
from src.models.snn_torch import SNNConfig, SNNLIF
from src.models.golden_inference_float import (
    FloatSNNParams, FloatSNNWeights, infer_counts as infer_float,
)
from src.models.golden_inference import (
    SNNParams, SNNWeights, snn_infer_events,
)


# ────────────────────────────────────────────────────────────
#  helpers
# ────────────────────────────────────────────────────────────

def spikes_to_event_lists(x_spk: np.ndarray) -> list:
    """
    x_spk: [T, 12]  (0/1 float or int)
    returns: List[List[int]]  event-list format for golden_inference.py
    """
    T, C = x_spk.shape
    events = []
    for t in range(T):
        ev = [ch for ch in range(C) if x_spk[t, ch] > 0.5]
        events.append(ev)
    return events


def load_int8_weights(exports_dir: Path) -> Tuple[np.ndarray, np.ndarray, float, float]:
    """Returns W1_q [12, Nh], W2_q [Nh, 3], scale1, scale2"""
    params = json.loads((exports_dir / "params.json").read_text(encoding="utf-8"))
    s1 = float(params["quant"]["w1_scale"])
    s2 = float(params["quant"]["w2_scale"])
    W1q = np.load(exports_dir / "W1_q.npy")  # [12, Nh] int8
    W2q = np.load(exports_dir / "W2_q.npy")  # [Nh, 3]  int8
    return W1q, W2q, s1, s2


# ────────────────────────────────────────────────────────────
#  main
# ────────────────────────────────────────────────────────────

def main() -> None:
    ap = argparse.ArgumentParser(description="Step 0.1 — Bit-exact verification")
    ap.add_argument("--config", default="config/enose_default.yaml")
    ap.add_argument("--ckpt",   default="exports/snn_ckpt.pt")
    ap.add_argument("--val",    default="data/processed/val_windows.npz")
    ap.add_argument("--exports", default="exports")
    ap.add_argument("--n",      type=int, default=500, help="samples to test")
    args = ap.parse_args()

    exports_dir = Path(args.exports)

    # ── 1. load dataset ──
    ds = WindowSpikeDataset(Path(args.val), Path(args.config))

    # ── 2. load torch model ──
    ckpt = torch.load(Path(args.ckpt), map_location="cpu", weights_only=False)
    cfg_dict = ckpt["snn_config"]
    state = ckpt["state_dict"]
    cfg = SNNConfig(**cfg_dict)
    model = SNNLIF(cfg)
    model.load_state_dict(state)
    model.eval()

    # ── 3. float weights (from torch, NO quantization) ──
    W1_float = state["W1.weight"].detach().cpu().numpy().T.astype(np.float32)  # [12, Nh]
    W2_float = state["W2.weight"].detach().cpu().numpy().T.astype(np.float32)  # [Nh, 3]

    fp = FloatSNNParams(
        n_in=cfg.n_in, n_hidden=cfg.n_hidden, n_out=cfg.n_out,
        window_len=cfg.window_len,
        leak_h_shift=cfg.leak_h_shift, leak_o_shift=cfg.leak_o_shift,
        th_h=float(cfg.th_h), th_o=float(cfg.th_o),
    )
    fw_orig = FloatSNNWeights(W1=W1_float, W2=W2_float)

    # ── 4. quantized weights (int8 dequant → float for golden-float path) ──
    W1q, W2q, s1, s2 = load_int8_weights(exports_dir)
    W1_qdq = W1q.astype(np.float32) * s1
    W2_qdq = W2q.astype(np.float32) * s2
    fw_quant = FloatSNNWeights(W1=W1_qdq, W2=W2_qdq)

    # ── 5. int weights for golden-int path ──
    # golden_inference.py expects W1[12, Nh] and W2[Nh, No] as int8/int16
    # and uses int32 arithmetic with thresholds in int domain.
    #
    # CRITICAL: We need to determine the correct int thresholds.
    # In float domain: th_h = 1.0, th_o = 1.0
    # In int domain:   th_h_int = th_h_float / scale_w1  (approx)
    # But actually the golden_inference.py uses raw int weights and int thresholds.
    # The relationship: float_membrane = int_membrane * w_scale (roughly)
    # So: th_int = th_float / w_scale
    #
    # However, this is not exact because spikes are binary (0/1) and:
    #   float: vh += spike @ W1_float   (units: float)
    #   int:   Vh += spike @ W1_int8    (units: int8-scale)
    #
    # The threshold must be in the same units as the accumulator.
    # Float threshold = 1.0
    # Int accumulator units = w_scale * int_value
    # So: th_int = th_float / w_scale = 1.0 / w_scale
    #
    # For the output layer similarly: th_o_int = 1.0 / w2_scale
    # But wait — output layer input is hidden spikes (binary 0/1),
    # so its accumulator is in w2_scale units → th_o_int = th_o / w2_scale

    th_h_int = max(1, int(round(float(cfg.th_h) / s1)))
    th_o_int = max(1, int(round(float(cfg.th_o) / s2)))

    ip = SNNParams(
        Nh=cfg.n_hidden, No=cfg.n_out,
        leak_h_shift=cfg.leak_h_shift, leak_o_shift=cfg.leak_o_shift,
        th_h=th_h_int, th_o=th_o_int,
        window_len=cfg.window_len,
    )
    iw = SNNWeights(W1=W1q.astype(np.int16), W2=W2q.astype(np.int16))

    print(f"=== Step 0.1 — Bit-Exact Verification ===")
    print(f"  Samples:       {min(args.n, len(ds))}")
    print(f"  SNN config:    {cfg.n_in}→{cfg.n_hidden}→{cfg.n_out}, T={cfg.window_len}")
    print(f"  Float th_h={cfg.th_h}, th_o={cfg.th_o}")
    print(f"  W1 scale={s1:.6f}, W2 scale={s2:.6f}")
    print(f"  Int   th_h={th_h_int}, th_o={th_o_int}")
    print()

    # ── 6. run comparison ──
    n = min(args.n, len(ds))

    # counters
    correct_torch = 0
    correct_gf_orig = 0
    correct_gf_quant = 0
    correct_gi = 0

    agree_torch_gf = 0       # torch vs golden-float (orig weights) — should be ~1.0
    agree_gf_orig_quant = 0   # golden-float orig vs quant — shows quantization impact
    agree_gf_quant_gi = 0     # golden-float-quant vs golden-int — shows float→int gap
    agree_torch_gi = 0        # torch vs golden-int — end-to-end gap

    # detailed mismatch tracking
    mismatches_gi = []  # indices where golden-int disagrees with golden-float-quant

    for i in range(n):
        x_spk, y = ds[i]
        x_np = x_spk.numpy().astype(np.float32)  # [T, 12]
        y_int = int(y.item())

        # Path A: Torch
        with torch.no_grad():
            logits = model(x_spk.unsqueeze(0))
            pred_torch = int(torch.argmax(logits, dim=1).item())

        # Path B: Golden float (original weights)
        pred_gf_orig, _, counts_gf_orig = infer_float(x_np, fw_orig, fp)

        # Path C: Golden float (quantized weights, dequantized)
        pred_gf_quant, _, counts_gf_quant = infer_float(x_np, fw_quant, fp)

        # Path D: Golden int (int8 weights, int32 arithmetic, int thresholds)
        events = spikes_to_event_lists(x_np)
        pred_gi, _, counts_gi = snn_infer_events(events, iw, ip)

        # Accuracy
        correct_torch    += int(pred_torch    == y_int)
        correct_gf_orig  += int(pred_gf_orig  == y_int)
        correct_gf_quant += int(pred_gf_quant == y_int)
        correct_gi       += int(pred_gi       == y_int)

        # Agreement
        agree_torch_gf       += int(pred_torch    == pred_gf_orig)
        agree_gf_orig_quant  += int(pred_gf_orig  == pred_gf_quant)
        agree_gf_quant_gi    += int(pred_gf_quant == pred_gi)
        agree_torch_gi       += int(pred_torch    == pred_gi)

        if pred_gf_quant != pred_gi and len(mismatches_gi) < 5:
            mismatches_gi.append({
                "idx": i,
                "y_true": y_int,
                "pred_gf_quant": pred_gf_quant,
                "counts_gf_quant": counts_gf_quant.tolist(),
                "pred_gi": pred_gi,
                "counts_gi": counts_gi.tolist(),
            })

    # ── 7. report ──
    print(f"{'='*60}")
    print(f"  ACCURACY (vs true label)")
    print(f"{'='*60}")
    print(f"  Torch forward:         {correct_torch/n:.4f}  ({correct_torch}/{n})")
    print(f"  Golden float (orig w): {correct_gf_orig/n:.4f}  ({correct_gf_orig}/{n})")
    print(f"  Golden float (quant w):{correct_gf_quant/n:.4f}  ({correct_gf_quant}/{n})")
    print(f"  Golden int   (int8 w): {correct_gi/n:.4f}  ({correct_gi}/{n})")
    print()

    print(f"{'='*60}")
    print(f"  AGREEMENT (pairwise)")
    print(f"{'='*60}")
    print(f"  Torch vs Golden-float-orig:  {agree_torch_gf/n:.4f}  <- should be 1.000")
    print(f"  GF-orig vs GF-quant:         {agree_gf_orig_quant/n:.4f}  <- quantization impact")
    print(f"  GF-quant vs Golden-int:      {agree_gf_quant_gi/n:.4f}  <- float→int gap (CRITICAL)")
    print(f"  Torch vs Golden-int:         {agree_torch_gi/n:.4f}  <- end-to-end gap")
    print()

    if mismatches_gi:
        print(f"{'='*60}")
        print(f"  SAMPLE MISMATCHES: Golden-float-quant vs Golden-int")
        print(f"{'='*60}")
        for m in mismatches_gi:
            print(f"  idx={m['idx']}: true={m['y_true']}, "
                  f"gf_quant={m['pred_gf_quant']} (counts={m['counts_gf_quant']}), "
                  f"gi={m['pred_gi']} (counts={m['counts_gi']})")
        print()

    # ── 8. verdict ──
    print(f"{'='*60}")
    print(f"  VERDICT")
    print(f"{'='*60}")

    ok = True
    if agree_torch_gf / n < 0.999:
        print("  [FAIL] Torch vs Golden-float disagree! Fix golden_inference_float.py")
        ok = False
    else:
        print("  [PASS] Torch ≡ Golden-float (orig weights)")

    if agree_gf_orig_quant / n < 0.95:
        print("  [WARN] Quantization changes >5% decisions. Consider retraining or wider quant.")
    else:
        print(f"  [PASS] Quantization impact acceptable ({(1-agree_gf_orig_quant/n)*100:.1f}% changed)")

    if agree_gf_quant_gi / n < 0.90:
        print("  [FAIL] Golden-float-quant vs Golden-int diverge >10%!")
        print("         This means the FPGA (int) inference will NOT match the emulator.")
        print("         Check: int thresholds, leak shift arithmetic, weight shapes.")
        ok = False
    elif agree_gf_quant_gi / n < 0.95:
        print(f"  [WARN] Golden-int diverges {(1-agree_gf_quant_gi/n)*100:.1f}% from float-quant.")
        print("         Acceptable for MVP, but investigate for thesis.")
    else:
        print(f"  [PASS] Golden-int closely matches float-quant ({(1-agree_gf_quant_gi/n)*100:.1f}% diff)")

    if ok:
        print("\n  >>> READY for RTL development. Golden-int is the reference for FPGA. <<<")
    else:
        print("\n  >>> FIX issues above before proceeding to RTL. <<<")


if __name__ == "__main__":
    main()