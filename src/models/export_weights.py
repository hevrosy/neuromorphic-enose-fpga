from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, Any, Tuple

import numpy as np
import torch


def quantize_int8(w: np.ndarray) -> Tuple[np.ndarray, float]:
    """
    Symmetric int8 quantization:
      w_float ~= w_int8 * scale
    scale chosen from max abs.
    """
    w = w.astype(np.float32)
    mx = float(np.max(np.abs(w)))
    scale = mx / 127.0 if mx > 1e-12 else 1.0
    q = np.clip(np.round(w / scale), -127, 127).astype(np.int8)
    return q, float(scale)


def write_hex_bytes(path: Path, q: np.ndarray) -> None:
    """
    Write int8 matrix as one byte per line hex (two's complement).
    Useful for later BRAM init (simple format).
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    flat = q.reshape(-1)
    with path.open("w", encoding="utf-8") as f:
        for b in flat:
            f.write(f"{int(np.uint8(b)) :02X}\n")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ckpt", default="exports/snn_ckpt.pt")
    ap.add_argument("--outdir", default="exports")
    args = ap.parse_args()

    ckpt_path = Path(args.ckpt)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    ckpt = torch.load(ckpt_path, map_location="cpu", weights_only=False)
    state = ckpt["state_dict"]
    cfg = ckpt["snn_config"]
    classes = ckpt["classes"]
    features = ckpt["features"]

    # Extract weights
    W1 = state["W1.weight"].detach().cpu().numpy().T  # PyTorch Linear: [Nh, Nin] -> transpose to [Nin, Nh]
    W2 = state["W2.weight"].detach().cpu().numpy().T  # [Nh, No]

    W1q, s1 = quantize_int8(W1)
    W2q, s2 = quantize_int8(W2)

    write_hex_bytes(outdir / "weights_w1.hex", W1q)
    write_hex_bytes(outdir / "weights_w2.hex", W2q)

    params: Dict[str, Any] = {
        "snn_config": cfg,
        "classes": classes,
        "features": features,
        "quant": {
            "w1_scale": s1,
            "w2_scale": s2,
            "format": "int8",
            "note": "float ~= int8 * scale",
        },
        "shapes": {
            "W1": [int(W1q.shape[0]), int(W1q.shape[1])],
            "W2": [int(W2q.shape[0]), int(W2q.shape[1])],
        },
    }
    (outdir / "params.json").write_text(json.dumps(params, indent=2, ensure_ascii=False), encoding="utf-8")

    # Also save numpy copies for quick use
    np.save(outdir / "W1_float.npy", W1.astype(np.float32))
    np.save(outdir / "W2_float.npy", W2.astype(np.float32))
    np.save(outdir / "W1_q.npy", W1q)
    np.save(outdir / "W2_q.npy", W2q)

    print("[DONE] Exported:")
    print(" ", outdir / "weights_w1.hex")
    print(" ", outdir / "weights_w2.hex")
    print(" ", outdir / "params.json")


if __name__ == "__main__":
    main()
