from __future__ import annotations

from dataclasses import dataclass
from typing import Tuple
import numpy as np


@dataclass(frozen=True)
class FloatSNNParams:
    n_in: int = 12
    n_hidden: int = 32
    n_out: int = 3
    window_len: int = 10
    leak_h_shift: int = 4
    leak_o_shift: int = 4
    th_h: float = 1.0
    th_o: float = 1.0


def shift_to_alpha(shift: int) -> float:
    shift = max(1, int(shift))
    return 1.0 - (1.0 / (2.0 ** shift))


@dataclass(frozen=True)
class FloatSNNWeights:
    W1: np.ndarray  # [12, Nh] float32
    W2: np.ndarray  # [Nh, No] float32


def infer_counts(x_spk: np.ndarray, w: FloatSNNWeights, p: FloatSNNParams) -> Tuple[int, float, np.ndarray]:
    """
    x_spk: [T, 12] spikes 0/1 (float)
    returns: (cls, confidence, counts[3])
    """
    T = min(x_spk.shape[0], p.window_len)
    Nh, No = p.n_hidden, p.n_out
    alpha_h = shift_to_alpha(p.leak_h_shift)
    alpha_o = shift_to_alpha(p.leak_o_shift)

    vh = np.zeros((Nh,), dtype=np.float32)
    vo = np.zeros((No,), dtype=np.float32)
    counts = np.zeros((No,), dtype=np.float32)

    for t in range(T):
        ih = x_spk[t].astype(np.float32) @ w.W1.astype(np.float32)  # [Nh]
        vh = alpha_h * vh + ih
        sh = (vh >= p.th_h).astype(np.float32)
        vh = vh * (1.0 - sh)

        io = sh @ w.W2.astype(np.float32)  # [No]
        vo = alpha_o * vo + io
        so = (vo >= p.th_o).astype(np.float32)
        vo = vo * (1.0 - so)
        counts += so

    cls = int(np.argmax(counts))
    conf = float(counts[cls] / max(float(np.sum(counts)), 1e-6))
    return cls, conf, counts
