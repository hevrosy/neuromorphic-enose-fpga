# FPGA Interface (SNN Inference Core) — AXI-Lite + AXI-Stream Contract

## 1. Overview
The system uses:
- **AXI-Lite** for control/status/result registers (PS ↔ PL)
- **AXI-Stream** for input spike event stream (PS → PL via DMA)

The SNN core performs inference over a fixed-length window (T timesteps) and returns:
- predicted class (0..2)
- output spike counts for each class

Target architecture: 12 → 32 → 3 (LIF), fixed-point friendly.

---

## 2. Data format (AXI-Stream)

### 2.1 Word format (32-bit)
Each AXI-Stream word is a **spike mask** for one timestep:

- Bits [11:0] : `spike_mask[11:0]` (12 channels)
- Bits [31:12]: reserved (0)

Interpretation:
- `spike_mask[i] = 1` means spike on input channel i at current timestep.
- One AXI-Stream word corresponds to one timestep.

### 2.2 Frame boundary
- `TLAST=1` marks the last timestep of the window.
- Expected number of words per inference = `WINDOW_LEN` (default 10).

---

## 3. Control/Status registers (AXI-Lite)

### 3.1 Address map (byte offsets)
All registers are 32-bit.

| Offset | Name            | R/W | Description |
|-------:|-----------------|:---:|------------|
| 0x00   | CONTROL         | R/W | bit0 START, bit1 RESET, bit2 INT_EN |
| 0x04   | STATUS          |  R  | bit0 DONE, bit1 BUSY, bit2 ERR |
| 0x08   | WINDOW_LEN      | R/W | number of timesteps (words) per inference |
| 0x0C   | N_IN            |  R  | input channels (fixed 12) |
| 0x10   | N_HIDDEN        |  R  | hidden neurons (fixed 32) |
| 0x14   | N_OUT           |  R  | classes (fixed 3) |
| 0x18   | RESULT_CLASS    |  R  | predicted class index 0..2 |
| 0x1C   | COUNT0          |  R  | output spike count for class 0 |
| 0x20   | COUNT1          |  R  | output spike count for class 1 |
| 0x24   | COUNT2          |  R  | output spike count for class 2 |
| 0x28   | CONF_Q15        |  R  | confidence in Q1.15 (optional, may be 0) |
| 0x2C   | LATENCY_CYCLES  |  R  | cycles from START to DONE (optional) |

### 3.2 CONTROL bits
- START (bit0): writing 1 triggers inference (core expects stream input)
- RESET (bit1): synchronous reset of internal state (clears BUSY/DONE)
- INT_EN (bit2): optional interrupt enable

### 3.3 STATUS bits
- DONE (bit0): inference finished, results valid
- BUSY (bit1): core is processing
- ERR (bit2): protocol error (wrong stream length, etc.)

---

## 4. PS-side typical sequence (PYNQ)
1) Write RESET=1 then RESET=0
2) Write WINDOW_LEN
3) Stream send `WINDOW_LEN` spike masks via DMA (TLAST on last word)
4) Write START=1
5) Poll STATUS.DONE
6) Read RESULT_CLASS and COUNT0..2

---

## 5. Notes for RTL mapping
- Spike masks map naturally to input event decoding (12-bit).
- Fixed-point weights stored in BRAM (int8/int16).
- Output counts can be kept in small counters (<= WINDOW_LEN).
