from __future__ import annotations
import numpy as np
from dataclasses import dataclass

@dataclass(frozen=True)
class Scaler:
    mean: np.ndarray  # [F]
    std: np.ndarray   # [F]

def fit_scaler(x: np.ndarray, eps: float = 1e-6) -> Scaler:
    if x.ndim != 2:
        raise ValueError("x must be [T, F] or [N, F]")
    mu = x.mean(axis=0)
    sd = x.std(axis=0) + eps
    return Scaler(mean=mu, std=sd)

def apply_scaler(x: np.ndarray, scaler: Scaler) -> np.ndarray:
    return (x - scaler.mean) / scaler.std
