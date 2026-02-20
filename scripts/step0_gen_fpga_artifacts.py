"""
Step 0.2 — Generate FPGA artifacts:
  1) .coe files for Vivado BRAM initialization (weights)
  2) Golden test vectors for RTL simulation verification

Usage (from project root):
  python scripts/step0_gen_fpga_artifacts.py --config config/enose_default.yaml

Outputs in exports/fpga/:
  w1.coe          — hidden layer weights [12][32] int8, row-major
  w2.coe          — output layer weights [32][3]  int8, row-major
  test_vectors.txt — N test cases: spike masks + expected class + counts
  fpga_params.vh   — Verilog header with all parameters
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import List

import numpy as np

sys.path.append(str(Path(__file__).resolve().parents[1]))

from src.models.snn_dataset import WindowSpikeDataset
from src.models.golden_inference import SNNParams, SNNWeights, snn_infer_events


def int8_to_twos_complement_hex(val: int) -> str:
    """Convert signed int8 to 2-digit hex (two's complement)."""
    return f"{val & 0xFF:02X}"


def write_coe(path: Path, data: np.ndarray, radix: int = 16) -> None:
    """
    Write Vivado .coe file.
    data: 1D array of int8 values (flattened row-major).
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        f.write(f"memory_initialization_radix={radix};\n")
        f.write("memory_initialization_vector=\n")
        flat = data.reshape(-1)
        for i, val in enumerate(flat):
            hex_val = int8_to_twos_complement_hex(int(val))
            sep = ";" if i == len(flat) - 1 else ","
            f.write(f"{hex_val}{sep}\n")
    print(f"  [OK] {path}  ({len(flat)} entries)")


def spikes_to_mask(x_spk_t: np.ndarray) -> int:
    """x_spk_t: [12] -> uint32 mask"""
    mask = 0
    for i in range(len(x_spk_t)):
        if x_spk_t[i] > 0.5:
            mask |= (1 << i)
    return mask


def spikes_to_event_lists(x_spk: np.ndarray) -> list:
    """x_spk: [T, 12] -> List[List[int]]"""
    T, C = x_spk.shape
    events = []
    for t in range(T):
        ev = [ch for ch in range(C) if x_spk[t, ch] > 0.5]
        events.append(ev)
    return events


def main() -> None:
    ap = argparse.ArgumentParser(description="Step 0.2 — Generate FPGA artifacts")
    ap.add_argument("--config",  default="config/enose_default.yaml")
    ap.add_argument("--exports", default="exports")
    ap.add_argument("--val",     default="data/processed/val_windows.npz")
    ap.add_argument("--n-vectors", type=int, default=20,
                    help="Number of test vectors to generate")
    args = ap.parse_args()

    exports_dir = Path(args.exports)
    fpga_dir = exports_dir / "fpga"
    fpga_dir.mkdir(parents=True, exist_ok=True)

    # ── Load quantized weights ──
    params = json.loads((exports_dir / "params.json").read_text(encoding="utf-8"))
    snn_cfg = params["snn_config"]
    s1 = float(params["quant"]["w1_scale"])
    s2 = float(params["quant"]["w2_scale"])

    W1q = np.load(exports_dir / "W1_q.npy")  # [12, 32] int8
    W2q = np.load(exports_dir / "W2_q.npy")  # [32, 3]  int8

    n_in = W1q.shape[0]
    n_hidden = W1q.shape[1]
    n_out = W2q.shape[1]
    window_len = int(snn_cfg["window_len"])
    leak_h = int(snn_cfg["leak_h_shift"])
    leak_o = int(snn_cfg["leak_o_shift"])
    th_h_float = float(snn_cfg["th_h"])
    th_o_float = float(snn_cfg["th_o"])

    # Integer thresholds (same formula as step 0.1)
    th_h_int = max(1, int(round(th_h_float / s1)))
    th_o_int = max(1, int(round(th_o_float / s2)))

    print(f"=== Step 0.2 — Generate FPGA Artifacts ===")
    print(f"  Architecture: {n_in}→{n_hidden}→{n_out}")
    print(f"  Window: {window_len}, Leak: h={leak_h} o={leak_o}")
    print(f"  Thresholds int: h={th_h_int} o={th_o_int}")
    print(f"  W1: {W1q.shape}, W2: {W2q.shape}")
    print()

    # ═══════════════════════════════════════════════
    #  1) .coe files (Vivado BRAM init)
    # ═══════════════════════════════════════════════
    print("── Generating .coe files ──")

    # W1: stored as [row=input_ch][col=neuron] = W1q[i][j]
    # BRAM address = i * N_HIDDEN + j
    # RTL reads: for neuron_n, weight = BRAM[input_ch * N_HIDDEN + neuron_n]
    write_coe(fpga_dir / "w1.coe", W1q)

    # W2: stored as [row=hidden_neuron][col=output_class] = W2q[h][o]
    # BRAM address = h * N_OUT + o
    write_coe(fpga_dir / "w2.coe", W2q)

    # Also write raw .mem files (alternative format, one hex value per line)
    # Useful for $readmemh in simulation
    def write_mem(path: Path, data: np.ndarray):
        path.parent.mkdir(parents=True, exist_ok=True)
        flat = data.reshape(-1)
        with path.open("w", encoding="utf-8") as f:
            for val in flat:
                f.write(f"{int(val) & 0xFF:02X}\n")
        print(f"  [OK] {path}  ({len(flat)} entries)")

    write_mem(fpga_dir / "w1.mem", W1q)
    write_mem(fpga_dir / "w2.mem", W2q)
    print()

    # ═══════════════════════════════════════════════
    #  2) Verilog parameters header
    # ═══════════════════════════════════════════════
    print("── Generating Verilog parameters header ──")
    vh_path = fpga_dir / "fpga_params.vh"
    with vh_path.open("w", encoding="utf-8") as f:
        f.write("// Auto-generated by step0_gen_fpga_artifacts.py\n")
        f.write("// DO NOT EDIT — regenerate from Python if params change\n\n")
        f.write(f"parameter N_IN       = {n_in};\n")
        f.write(f"parameter N_HIDDEN   = {n_hidden};\n")
        f.write(f"parameter N_OUT      = {n_out};\n")
        f.write(f"parameter WINDOW_LEN = {window_len};\n")
        f.write(f"parameter LEAK_H     = {leak_h};  // bit-shift for hidden leak\n")
        f.write(f"parameter LEAK_O     = {leak_o};  // bit-shift for output leak\n")
        f.write(f"parameter TH_H       = {th_h_int};  // hidden threshold (int)\n")
        f.write(f"parameter TH_O       = {th_o_int};  // output threshold (int)\n")
        f.write(f"\n// Weight memory sizes\n")
        f.write(f"parameter W1_DEPTH   = {n_in * n_hidden};  // {n_in} x {n_hidden}\n")
        f.write(f"parameter W2_DEPTH   = {n_hidden * n_out};  // {n_hidden} x {n_out}\n")
        f.write(f"\n// Scales (for reference only, not used in RTL)\n")
        f.write(f"// W1 scale = {s1:.8f}\n")
        f.write(f"// W2 scale = {s2:.8f}\n")
    print(f"  [OK] {vh_path}")
    print()

    # ═══════════════════════════════════════════════
    #  3) Golden test vectors
    # ═══════════════════════════════════════════════
    print("── Generating golden test vectors ──")

    ds = WindowSpikeDataset(Path(args.val), Path(args.config))
    ip = SNNParams(
        Nh=n_hidden, No=n_out,
        leak_h_shift=leak_h, leak_o_shift=leak_o,
        th_h=th_h_int, th_o=th_o_int,
        window_len=window_len,
    )
    iw = SNNWeights(W1=W1q.astype(np.int16), W2=W2q.astype(np.int16))

    n_vec = min(args.n_vectors, len(ds))

    # Pick diverse samples: try to get some from each class
    indices = list(range(n_vec))

    tv_path = fpga_dir / "test_vectors.txt"
    with tv_path.open("w", encoding="utf-8") as f:
        f.write(f"# Golden test vectors for RTL simulation\n")
        f.write(f"# Generated by step0_gen_fpga_artifacts.py\n")
        f.write(f"# Format: one test case per block\n")
        f.write(f"# WINDOW_LEN={window_len}, N_IN={n_in}\n")
        f.write(f"# TH_H={th_h_int}, TH_O={th_o_int}, LEAK_H={leak_h}, LEAK_O={leak_o}\n")
        f.write(f"#\n")
        f.write(f"# Each test case:\n")
        f.write(f"#   TEST <id> LABEL <true_label> EXPECTED_CLASS <pred> COUNTS <c0> <c1> <c2>\n")
        f.write(f"#   MASK <hex_mask>   (one per timestep, {window_len} lines)\n")
        f.write(f"#   END\n")
        f.write(f"#\n\n")

        for vec_idx, ds_idx in enumerate(indices):
            x_spk, y = ds[ds_idx]
            x_np = x_spk.numpy().astype(np.float32)
            y_int = int(y.item())

            events = spikes_to_event_lists(x_np)
            pred, _, counts = snn_infer_events(events, iw, ip)

            # Convert to masks
            masks = []
            for t in range(window_len):
                m = spikes_to_mask(x_np[t])
                masks.append(m)

            f.write(f"TEST {vec_idx} LABEL {y_int} EXPECTED_CLASS {pred} COUNTS {int(counts[0])} {int(counts[1])} {int(counts[2])}\n")
            for t, m in enumerate(masks):
                f.write(f"MASK {m:03X}\n")
            f.write(f"END\n\n")

    print(f"  [OK] {tv_path}  ({n_vec} test vectors)")
    print()

    # ═══════════════════════════════════════════════
    #  Summary
    # ═══════════════════════════════════════════════
    print(f"{'='*60}")
    print(f"  ALL FPGA ARTIFACTS GENERATED IN: {fpga_dir.resolve()}")
    print(f"{'='*60}")
    print(f"  w1.coe / w1.mem  — hidden weights ({n_in}×{n_hidden} = {n_in*n_hidden} bytes)")
    print(f"  w2.coe / w2.mem  — output weights ({n_hidden}×{n_out} = {n_hidden*n_out} bytes)")
    print(f"  fpga_params.vh   — Verilog `include for parameters")
    print(f"  test_vectors.txt — {n_vec} golden test cases for simulation")
    print()
    print(f"  Next step: Use these in Vivado for BRAM init and testbench verification.")


if __name__ == "__main__":
    main()