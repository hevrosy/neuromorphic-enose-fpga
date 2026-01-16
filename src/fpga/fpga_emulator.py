from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, List, Tuple

import numpy as np

from src.fpga import regs
from src.models.golden_inference_float import FloatSNNParams, FloatSNNWeights, infer_counts


def _mask_to_spikes(mask: int, n_in: int = 12) -> np.ndarray:
    x = np.zeros((n_in,), dtype=np.float32)
    for i in range(n_in):
        x[i] = 1.0 if (mask >> i) & 1 else 0.0
    return x


def load_weights_from_exports(exports_dir: Path) -> Tuple[np.ndarray, np.ndarray]:
    """
    Loads exported int8 weights and dequantizes to float for golden float inference.
    Requires:
      exports/params.json
      exports/W1_q.npy
      exports/W2_q.npy
    """
    params = json.loads((exports_dir / "params.json").read_text(encoding="utf-8"))
    w1_scale = float(params["quant"]["w1_scale"])
    w2_scale = float(params["quant"]["w2_scale"])

    W1q = np.load(exports_dir / "W1_q.npy")
    W2q = np.load(exports_dir / "W2_q.npy")

    W1 = W1q.astype(np.float32) * w1_scale  # [12,Nh]
    W2 = W2q.astype(np.float32) * w2_scale  # [Nh,3]
    return W1, W2


@dataclass
class EmulatorConfig:
    n_in: int = 12
    n_hidden: int = 32
    n_out: int = 3
    window_len: int = 10
    leak_h_shift: int = 4
    leak_o_shift: int = 4
    th_h: float = 1.0
    th_o: float = 1.0


class FPGAEmulator:
    """
    Emulates the AXI-Lite + AXI-Stream contract.

    - write_reg/read_reg: AXI-Lite
    - stream_send_masks: AXI-Stream words (spike masks)
    - When START is asserted, it runs golden inference and populates result regs.
    """

    def __init__(self, exports_dir: Optional[Path] = None, cfg: Optional[EmulatorConfig] = None):
        self.cfg = cfg or EmulatorConfig()
        self.exports_dir = exports_dir

        # registers (uint32)
        self._regs = {k: 0 for k in [
            regs.CONTROL, regs.STATUS, regs.WINDOW_LEN, regs.N_IN, regs.N_HIDDEN, regs.N_OUT,
            regs.RESULT_CLASS, regs.COUNT0, regs.COUNT1, regs.COUNT2, regs.CONF_Q15, regs.LATENCY_CYCLES
        ]}

        self._regs[regs.WINDOW_LEN] = int(self.cfg.window_len)
        self._regs[regs.N_IN] = int(self.cfg.n_in)
        self._regs[regs.N_HIDDEN] = int(self.cfg.n_hidden)
        self._regs[regs.N_OUT] = int(self.cfg.n_out)

        self._stream_buf: List[int] = []

        # weights
        self.W1 = None
        self.W2 = None
        if exports_dir is not None:
            self.load_exports(exports_dir)

    def load_exports(self, exports_dir: Path) -> None:
        W1, W2 = load_weights_from_exports(exports_dir)
        self.W1, self.W2 = W1, W2

    def reset(self) -> None:
        self._stream_buf = []
        self._regs[regs.STATUS] = 0
        self._regs[regs.RESULT_CLASS] = 0
        self._regs[regs.COUNT0] = 0
        self._regs[regs.COUNT1] = 0
        self._regs[regs.COUNT2] = 0
        self._regs[regs.CONF_Q15] = 0
        self._regs[regs.LATENCY_CYCLES] = 0

    def write_reg(self, offset: int, value: int) -> None:
        value = int(value) & 0xFFFFFFFF

        if offset == regs.CONTROL:
            # handle reset
            if value & regs.CTRL_RESET:
                self.reset()

            # handle start
            if value & regs.CTRL_START:
                self._start_inference()

            # store control (optional)
            self._regs[offset] = value
            return

        if offset == regs.WINDOW_LEN:
            self._regs[offset] = value
            return

        # other registers: ignore writes
        self._regs[offset] = value

    def read_reg(self, offset: int) -> int:
        return int(self._regs.get(offset, 0))

    def stream_send_masks(self, masks: np.ndarray, tlast: bool = True) -> None:
        """
        masks: array of uint32 spike masks, one per timestep
        """
        masks = np.asarray(masks, dtype=np.uint32)
        for m in masks:
            self._stream_buf.append(int(m))

        # protocol: we don't strictly require tlast flag here; START will check length
        # In real AXI-Stream, TLAST marks frame end.

    def _start_inference(self) -> None:
        # Check weights
        if self.W1 is None or self.W2 is None:
            self._regs[regs.STATUS] = regs.STS_ERR
            return

        Texp = int(self._regs[regs.WINDOW_LEN])
        if len(self._stream_buf) < Texp:
            self._regs[regs.STATUS] = regs.STS_ERR
            return

        # Take exactly one frame
        frame = self._stream_buf[:Texp]
        self._stream_buf = self._stream_buf[Texp:]

        self._regs[regs.STATUS] = regs.STS_BUSY

        # Convert to spikes [T, 12]
        x = np.stack([_mask_to_spikes(m, n_in=self.cfg.n_in) for m in frame], axis=0)  # [T,12]

        p = FloatSNNParams(
            n_in=self.cfg.n_in,
            n_hidden=self.cfg.n_hidden,
            n_out=self.cfg.n_out,
            window_len=Texp,
            leak_h_shift=self.cfg.leak_h_shift,
            leak_o_shift=self.cfg.leak_o_shift,
            th_h=float(self.cfg.th_h),
            th_o=float(self.cfg.th_o),
        )
        w = FloatSNNWeights(W1=self.W1.astype(np.float32), W2=self.W2.astype(np.float32))

        pred, conf, counts = infer_counts(x, w, p)

        self._regs[regs.RESULT_CLASS] = int(pred)
        self._regs[regs.COUNT0] = int(counts[0])
        self._regs[regs.COUNT1] = int(counts[1])
        self._regs[regs.COUNT2] = int(counts[2])

        # confidence Q1.15
        q15 = int(np.clip(int(round(conf * (1 << 15))), 0, (1 << 15) - 1))
        self._regs[regs.CONF_Q15] = q15

        # fake latency cycles (rough)
        self._regs[regs.LATENCY_CYCLES] = int(Texp * (self.cfg.n_hidden + self.cfg.n_out))

        self._regs[regs.STATUS] = regs.STS_DONE
