from __future__ import annotations
from dataclasses import dataclass
from typing import Tuple, List
import numpy as np

@dataclass(frozen=True)
class SNNParams:
    Nh: int = 32
    No: int = 3
    leak_h_shift: int = 4
    leak_o_shift: int = 4
    th_h: int = 64
    th_o: int = 64
    window_len: int = 10

@dataclass(frozen=True)
class SNNWeights:
    W1: np.ndarray  # [12, Nh] int8/int16
    W2: np.ndarray  # [Nh, No] int8/int16

def snn_infer_events(events: List[List[int]], weights: SNNWeights, p: SNNParams) -> Tuple[int, int, np.ndarray]:
    """
    events: per timestep list of src_id (0..11) for pos/neg spikes
    We treat src_id<6 as +1, src_id>=6 as -1 mapped to base feature (src_id-6).
    But since we already split pos/neg as separate channels (12 inputs),
    simplest is to use channels 0..11 with +1 spikes; weights handle sign via learned values.
    """
    Nh, No = p.Nh, p.No
    Vh = np.zeros((Nh,), dtype=np.int32)
    Vo = np.zeros((No,), dtype=np.int32)
    Cout = np.zeros((No,), dtype=np.int32)

    T = min(len(events), p.window_len)

    for t in range(T):
        # accumulate Ih from input spikes
        Ih = np.zeros((Nh,), dtype=np.int32)
        for src in events[t]:
            Ih += weights.W1[src].astype(np.int32)

        # hidden update
        Vh = Vh - (Vh >> p.leak_h_shift) + Ih
        spikeH = (Vh >= p.th_h).astype(np.int32)
        Vh = np.where(spikeH == 1, 0, Vh)

        # output accumulate
        Io = (spikeH.astype(np.int32) @ weights.W2.astype(np.int32))
        Vo = Vo - (Vo >> p.leak_o_shift) + Io
        spikeO = (Vo >= p.th_o).astype(np.int32)
        Cout += spikeO
        Vo = np.where(spikeO == 1, 0, Vo)

    cls = int(np.argmax(Cout))
    s = int(Cout.sum())
    conf_q0_8 = int((int(Cout[cls]) << 8) // max(s, 1))
    return cls, conf_q0_8, Cout
