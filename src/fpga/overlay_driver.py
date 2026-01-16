from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Tuple

import numpy as np

from src.fpga.fpga_emulator import FPGAEmulator
from src.fpga import regs


@dataclass
class InferenceResult:
    pred_class: int
    counts: np.ndarray  # [3]
    conf: float


class SNNOverlayDriver:
    """
    Driver facade.

    Today: talks to FPGAEmulator (same API we'd use for real PYNQ overlay).
    Later: replace backend with actual MMIO + DMA.
    """
    def __init__(self, exports_dir: Path, window_len: int = 10):
        self.backend = FPGAEmulator(exports_dir=exports_dir)
        self.set_window_len(window_len)
        self.reset()

    def reset(self) -> None:
        self.backend.write_reg(regs.CONTROL, regs.CTRL_RESET)

    def set_window_len(self, window_len: int) -> None:
        self.backend.write_reg(regs.WINDOW_LEN, int(window_len) & 0xFFFFFFFF)

    @staticmethod
    def spikes_to_masks(x_spk: np.ndarray) -> np.ndarray:
        """
        x_spk: [T,12] spikes (0/1)
        returns uint32 masks [T]
        """
        x_spk = np.asarray(x_spk, dtype=np.uint8)
        T, C = x_spk.shape
        assert C == 12
        masks = np.zeros((T,), dtype=np.uint32)
        for t in range(T):
            m = 0
            for i in range(C):
                if x_spk[t, i]:
                    m |= (1 << i)
            masks[t] = m
        return masks

    def infer_from_masks(self, masks: np.ndarray) -> InferenceResult:
        self.backend.stream_send_masks(masks)
        self.backend.write_reg(regs.CONTROL, regs.CTRL_START)

        st = self.backend.read_reg(regs.STATUS)
        if st & regs.STS_ERR:
            raise RuntimeError("FPGA backend reported ERR (stream length/weights missing).")

        pred = self.backend.read_reg(regs.RESULT_CLASS)
        c0 = self.backend.read_reg(regs.COUNT0)
        c1 = self.backend.read_reg(regs.COUNT1)
        c2 = self.backend.read_reg(regs.COUNT2)
        q15 = self.backend.read_reg(regs.CONF_Q15)

        conf = float(q15) / float(1 << 15)
        return InferenceResult(pred_class=int(pred), counts=np.array([c0, c1, c2], dtype=np.int32), conf=conf)

    def infer_from_spikes(self, x_spk: np.ndarray) -> InferenceResult:
        masks = self.spikes_to_masks(x_spk)
        return self.infer_from_masks(masks)
