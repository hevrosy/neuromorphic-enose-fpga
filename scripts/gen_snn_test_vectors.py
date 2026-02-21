#!/usr/bin/env python3
"""
gen_snn_test_vectors.py — Generate golden test vectors for SNN RTL verification.

Uses FIXED-POINT (int32) arithmetic that is BIT-EXACT with the Verilog RTL:
  - Weights: int8 (from exported .hex)
  - Membrane: int16 (signed)
  - Leak: v_new = v - (v >>> leak_shift)   [arithmetic right shift]
  - Accumulate: v_new = v_leaked + weighted_input
  - Threshold: int16 (e.g. 64)
  - Fire: hard reset (v = 0)

Output: .mem files for Verilog $readmemh, plus human-readable .txt

Usage (on your PC where exports/ exists):
  python gen_snn_test_vectors.py --w1 exports/W1_q.npy --w2 exports/W2_q.npy \
      --params exports/params.json --out fpga/sim/vectors
"""
from __future__ import annotations
import argparse
import json
import numpy as np
from pathlib import Path
from dataclasses import dataclass
from typing import List, Tuple


@dataclass
class IntSNNParams:
    n_in: int = 12
    n_hidden: int = 32
    n_out: int = 3
    window_len: int = 10
    leak_h_shift: int = 4
    leak_o_shift: int = 4
    th_h: int = 64       # int16 threshold for hidden
    th_o: int = 64       # int16 threshold for output


def asr16(v: np.int16, shift: int) -> np.int16:
    """Arithmetic right shift for int16, matching Verilog >>> on signed."""
    v32 = np.int32(v)
    if v32 >= 0:
        return np.int16(v32 >> shift)
    else:
        # Python >> on negative ints is already arithmetic, but let's be explicit
        return np.int16(v32 >> shift)


def snn_infer_int(
    spike_masks: List[int],
    W1: np.ndarray,       # [12, Nh] int8
    W2: np.ndarray,       # [Nh, 3]  int8
    p: IntSNNParams,
    trace: bool = False
) -> Tuple[int, np.ndarray, dict]:
    """
    Bit-exact int16 SNN inference matching RTL behavior.

    Returns: (predicted_class, output_counts[3], trace_dict)
    """
    Nh, No = p.n_hidden, p.n_out
    T = min(len(spike_masks), p.window_len)

    # State: int16 membrane potentials
    Vh = np.zeros(Nh, dtype=np.int16)
    Vo = np.zeros(No, dtype=np.int16)
    Cout = np.zeros(No, dtype=np.int32)

    trace_data = {
        'timesteps': [],
        'spike_masks': [],
        'Vh_before': [],
        'Vh_after': [],
        'hidden_spikes': [],
        'Vo_before': [],
        'Vo_after': [],
        'output_spikes': [],
    }

    for t in range(T):
        mask = spike_masks[t] & 0xFFF  # 12-bit

        # --- Hidden layer ---
        # 1. Compute weighted input for each hidden neuron
        Ih = np.zeros(Nh, dtype=np.int16)
        for ch in range(p.n_in):
            if (mask >> ch) & 1:
                # Add weight column: W1[ch, :] are int8
                for n in range(Nh):
                    Ih[n] = np.int16(np.int32(Ih[n]) + np.int32(W1[ch, n]))

        # 2. Leak: v_leaked = v - (v >>> shift)
        Vh_leaked = np.zeros(Nh, dtype=np.int16)
        for n in range(Nh):
            leak_val = asr16(Vh[n], p.leak_h_shift)
            Vh_leaked[n] = np.int16(np.int32(Vh[n]) - np.int32(leak_val))

        # 3. Accumulate: v_new = v_leaked + Ih
        Vh_new = np.zeros(Nh, dtype=np.int16)
        for n in range(Nh):
            Vh_new[n] = np.int16(np.int32(Vh_leaked[n]) + np.int32(Ih[n]))

        if trace:
            trace_data['Vh_before'].append(Vh.copy())

        # 4. Fire + Reset
        h_spikes = np.zeros(Nh, dtype=np.uint8)
        for n in range(Nh):
            if Vh_new[n] >= p.th_h:
                h_spikes[n] = 1
                Vh[n] = np.int16(0)
            else:
                Vh[n] = Vh_new[n]

        if trace:
            trace_data['timesteps'].append(t)
            trace_data['spike_masks'].append(mask)
            trace_data['Vh_after'].append(Vh.copy())
            trace_data['hidden_spikes'].append(h_spikes.copy())

        # --- Output layer ---
        # 1. Weighted input from hidden spikes
        Io = np.zeros(No, dtype=np.int16)
        for hn in range(Nh):
            if h_spikes[hn]:
                for on in range(No):
                    Io[on] = np.int16(np.int32(Io[on]) + np.int32(W2[hn, on]))

        # 2. Leak
        Vo_leaked = np.zeros(No, dtype=np.int16)
        for on in range(No):
            leak_val = asr16(Vo[on], p.leak_o_shift)
            Vo_leaked[on] = np.int16(np.int32(Vo[on]) - np.int32(leak_val))

        # 3. Accumulate
        Vo_new = np.zeros(No, dtype=np.int16)
        for on in range(No):
            Vo_new[on] = np.int16(np.int32(Vo_leaked[on]) + np.int32(Io[on]))

        if trace:
            trace_data['Vo_before'].append(Vo.copy())

        # 4. Fire + Reset
        o_spikes = np.zeros(No, dtype=np.uint8)
        for on in range(No):
            if Vo_new[on] >= p.th_o:
                o_spikes[on] = 1
                Cout[on] += 1
                Vo[on] = np.int16(0)
            else:
                Vo[on] = Vo_new[on]

        if trace:
            trace_data['Vo_after'].append(Vo.copy())
            trace_data['output_spikes'].append(o_spikes.copy())

    cls = int(np.argmax(Cout))
    return cls, Cout, trace_data


def write_weight_mem(path: Path, W: np.ndarray, label: str):
    """Write weight matrix as .mem file for Verilog $readmemh.
    Format: one int8 (as 2-hex-digit two's complement) per line.
    Layout: row-major — W[row][col] flattened.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    flat = W.astype(np.int8).reshape(-1)
    with open(path, 'w') as f:
        f.write(f"// {label}: shape={list(W.shape)}, row-major, int8 two's complement\n")
        for i, b in enumerate(flat):
            f.write(f"{int(np.uint8(b)):02X}\n")
    print(f"  wrote {path} ({len(flat)} bytes)")


def write_spike_mem(path: Path, masks: List[int], label: str):
    """Write spike masks as .mem file — one 32-bit hex word per line."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w') as f:
        f.write(f"// {label}: {len(masks)} words (32-bit spike masks)\n")
        for m in masks:
            f.write(f"{m:08X}\n")
    print(f"  wrote {path} ({len(masks)} words)")


def write_expected_mem(path: Path, cls: int, counts: np.ndarray, label: str):
    """Write expected results as .mem file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w') as f:
        f.write(f"// {label}\n")
        f.write(f"// predicted_class={cls} counts=[{counts[0]},{counts[1]},{counts[2]}]\n")
        f.write(f"{cls:08X}\n")
        for c in counts:
            f.write(f"{int(c):08X}\n")
    print(f"  wrote {path}")


def generate_test_cases(W1, W2, p):
    """Generate diverse test cases for RTL verification."""
    tests = []

    # Test 0: All zeros — no spikes at all
    masks_0 = [0x000] * p.window_len
    tests.append(("tc0_zeros", masks_0))

    # Test 1: All ones — all 12 channels active every timestep
    masks_1 = [0xFFF] * p.window_len
    tests.append(("tc1_allones", masks_1))

    # Test 2: Single channel (ch0) every timestep
    masks_2 = [0x001] * p.window_len
    tests.append(("tc2_ch0_only", masks_2))

    # Test 3: Alternating pattern — odd channels then even channels
    masks_3 = []
    for t in range(p.window_len):
        if t % 2 == 0:
            masks_3.append(0x555)  # channels 0,2,4,6,8,10
        else:
            masks_3.append(0xAAA)  # channels 1,3,5,7,9,11
    tests.append(("tc3_alternating", masks_3))

    # Test 4: Ramp — increasing number of active channels
    masks_4 = []
    for t in range(p.window_len):
        n_ch = min(t + 1, 12)
        m = (1 << n_ch) - 1
        masks_4.append(m)
    tests.append(("tc4_ramp", masks_4))

    # Test 5: Single spike at t=0, then silence
    masks_5 = [0xFFF] + [0x000] * (p.window_len - 1)
    tests.append(("tc5_burst_then_silence", masks_5))

    # Test 6: Random pattern (fixed seed for reproducibility)
    rng = np.random.RandomState(42)
    masks_6 = [int(rng.randint(0, 0x1000)) for _ in range(p.window_len)]
    tests.append(("tc6_random_seed42", masks_6))

    # Test 7: Another random pattern
    rng7 = np.random.RandomState(123)
    masks_7 = [int(rng7.randint(0, 0x1000)) for _ in range(p.window_len)]
    tests.append(("tc7_random_seed123", masks_7))

    return tests


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--w1", default="exports/W1_q.npy", help="int8 weight matrix [12,Nh]")
    ap.add_argument("--w2", default="exports/W2_q.npy", help="int8 weight matrix [Nh,3]")
    ap.add_argument("--params", default="exports/params.json")
    ap.add_argument("--out", default="fpga/sim/vectors", help="output directory")
    ap.add_argument("--th-h", type=int, default=64, help="hidden threshold (int16)")
    ap.add_argument("--th-o", type=int, default=64, help="output threshold (int16)")
    ap.add_argument("--leak-h", type=int, default=4, help="hidden leak shift")
    ap.add_argument("--leak-o", type=int, default=4, help="output leak shift")
    ap.add_argument("--window-len", type=int, default=10)
    args = ap.parse_args()

    outdir = Path(args.out)
    outdir.mkdir(parents=True, exist_ok=True)

    # Load weights
    W1 = np.load(args.w1).astype(np.int8)  # [12, Nh]
    W2 = np.load(args.w2).astype(np.int8)  # [Nh, 3]
    print(f"W1 shape: {W1.shape}, W2 shape: {W2.shape}")
    print(f"W1 range: [{W1.min()}, {W1.max()}]")
    print(f"W2 range: [{W2.min()}, {W2.max()}]")

    p = IntSNNParams(
        n_in=12, n_hidden=W1.shape[1], n_out=W2.shape[1],
        window_len=args.window_len,
        leak_h_shift=args.leak_h, leak_o_shift=args.leak_o,
        th_h=args.th_h, th_o=args.th_o,
    )

    # Write weight .mem files for RTL
    print("\n=== Weight files ===")
    write_weight_mem(outdir / "w1.mem", W1, f"W1[{p.n_in},{p.n_hidden}]")
    write_weight_mem(outdir / "w2.mem", W2, f"W2[{p.n_hidden},{p.n_out}]")

    # Write params file for RTL
    params_rtl = {
        'n_in': p.n_in, 'n_hidden': p.n_hidden, 'n_out': p.n_out,
        'window_len': p.window_len,
        'leak_h_shift': p.leak_h_shift, 'leak_o_shift': p.leak_o_shift,
        'th_h': p.th_h, 'th_o': p.th_o,
    }
    (outdir / "params_rtl.json").write_text(json.dumps(params_rtl, indent=2))

    # Generate and run test cases
    tests = generate_test_cases(W1, W2, p)

    print(f"\n=== Running {len(tests)} test cases ===")
    summary = []

    for name, masks in tests:
        cls, counts, trace = snn_infer_int(masks, W1, W2, p, trace=True)
        print(f"\n  {name}: class={cls}, counts=[{counts[0]},{counts[1]},{counts[2]}]")

        tc_dir = outdir / name
        write_spike_mem(tc_dir / "spikes.mem", masks, name)
        write_expected_mem(tc_dir / "expected.mem", cls, counts, name)

        # Write detailed trace for debug
        with open(tc_dir / "trace.txt", 'w') as f:
            f.write(f"Test case: {name}\n")
            f.write(f"Params: th_h={p.th_h} th_o={p.th_o} leak_h={p.leak_h_shift} leak_o={p.leak_o_shift}\n")
            f.write(f"Result: class={cls} counts=[{counts[0]},{counts[1]},{counts[2]}]\n\n")

            for t in range(len(trace['timesteps'])):
                f.write(f"--- t={t} mask=0x{trace['spike_masks'][t]:03X} ---\n")
                h_spk = trace['hidden_spikes'][t]
                h_spk_bits = 0
                for i in range(len(h_spk)):
                    if h_spk[i]:
                        h_spk_bits |= (1 << i)
                f.write(f"  hidden_spikes = 0x{h_spk_bits:08X} (popcount={int(h_spk.sum())})\n")
                o_spk = trace['output_spikes'][t]
                f.write(f"  output_spikes = [{o_spk[0]},{o_spk[1]},{o_spk[2]}]\n")
                f.write(f"  Vh_after[0:4] = {trace['Vh_after'][t][:4]}\n")
                f.write(f"  Vo_after = {trace['Vo_after'][t]}\n")

        summary.append({
            'name': name,
            'class': cls,
            'counts': counts.tolist(),
            'masks': masks,
        })

    # Write combined test vector file for Verilog $readmemh
    # Format: all test spikes concatenated, with test boundaries marked
    all_spikes_path = outdir / "all_spikes.mem"
    with open(all_spikes_path, 'w') as f:
        f.write(f"// {len(tests)} test cases x {p.window_len} words each\n")
        for i, (name, masks) in enumerate(tests):
            f.write(f"// TC{i}: {name}\n")
            for m in masks:
                f.write(f"{m:08X}\n")
    print(f"\n  wrote {all_spikes_path}")

    # Write expected results for all tests
    all_expected_path = outdir / "all_expected.mem"
    with open(all_expected_path, 'w') as f:
        f.write(f"// {len(tests)} test cases: class, count0, count1, count2\n")
        for s in summary:
            f.write(f"// {s['name']}\n")
            f.write(f"{s['class']:08X}\n")
            for c in s['counts']:
                f.write(f"{c:08X}\n")
    print(f"  wrote {all_expected_path}")

    # Summary
    print(f"\n{'='*60}")
    print(f"SUMMARY: {len(tests)} test cases generated in {outdir}/")
    print(f"{'='*60}")
    for s in summary:
        print(f"  {s['name']:30s} → class={s['class']} counts={s['counts']}")
    print(f"\nWeights: {outdir}/w1.mem, {outdir}/w2.mem")
    print(f"All spikes: {outdir}/all_spikes.mem")
    print(f"All expected: {outdir}/all_expected.mem")
    print(f"\nUse these to verify RTL with: $readmemh(\"w1.mem\", weight_bram_h);")


if __name__ == "__main__":
    main()
