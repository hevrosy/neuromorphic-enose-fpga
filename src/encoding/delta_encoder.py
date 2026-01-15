from __future__ import annotations
from dataclasses import dataclass
from typing import Dict, List, Tuple
import numpy as np

@dataclass(frozen=True)
class DeltaEncoderConfig:
    thresholds: np.ndarray  # [F], after normalization
    feature_names: Tuple[str, ...]  # length F

def encode_pos_neg(x: np.ndarray, cfg: DeltaEncoderConfig) -> List[List[int]]:
    """
    x: [T, F] normalized
    Output: events_per_timestep: List[ List[src_id] ]
      src_id in 0..(2F-1)
      0..F-1   -> positive spikes
      F..2F-1  -> negative spikes
    Delta coding: compares against internal accumulator per feature.
    """
    if x.ndim != 2:
        raise ValueError("x must be [T, F]")
    T, F = x.shape
    if cfg.thresholds.shape[0] != F:
        raise ValueError("threshold size mismatch")

    acc = x[0].copy()
    events: List[List[int]] = []

    for t in range(T):
        ev_t: List[int] = []
        for k in range(F):
            d = x[t, k] - acc[k]
            thr = cfg.thresholds[k]
            if d >= thr:
                ev_t.append(k)       # pos
                acc[k] += thr
            elif d <= -thr:
                ev_t.append(F + k)   # neg
                acc[k] -= thr
        events.append(ev_t)
    return events
