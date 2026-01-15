from __future__ import annotations
import numpy as np

def baseline_correction(x: np.ndarray, baseline_len: int) -> np.ndarray:
    """
    x: shape [T, F]
    baseline_len: number of initial samples for baseline mean
    """
    if x.ndim != 2:
        raise ValueError("x must be [T, F]")
    baseline_len = max(1, min(baseline_len, x.shape[0]))
    b = x[:baseline_len].mean(axis=0, keepdims=True)
    return x - b
