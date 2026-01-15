from __future__ import annotations
import numpy as np
from typing import Tuple

def make_windows(x: np.ndarray, y: int, window_len: int, stride: int) -> Tuple[np.ndarray, np.ndarray]:
    """
    x: [T, F]
    y: label int
    returns:
      Xw: [Nw, window_len, F]
      Yw: [Nw]
    """
    if x.ndim != 2:
        raise ValueError("x must be [T, F]")
    T, F = x.shape
    windows = []
    labels = []
    for start in range(0, T - window_len + 1, stride):
        windows.append(x[start:start + window_len])
        labels.append(y)
    if not windows:
        return np.zeros((0, window_len, F), dtype=x.dtype), np.zeros((0,), dtype=np.int64)
    return np.stack(windows, axis=0), np.array(labels, dtype=np.int64)
