from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
import yaml
import torch
from torch.utils.data import Dataset


FEATURE_ORDER = ["mq135", "mq3", "mq4", "temperature_c", "humidity_rh", "gas_resistance_ohm"]


@dataclass(frozen=True)
class EncoderSpec:
    thresholds: np.ndarray  # [F]
    feature_order: List[str]


def load_encoder_spec(config_path: Path) -> EncoderSpec:
    cfg = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    thr_map: Dict[str, float] = cfg["encoding"]["thresholds"]
    thresholds = np.array([float(thr_map[name]) for name in FEATURE_ORDER], dtype=np.float32)
    return EncoderSpec(thresholds=thresholds, feature_order=FEATURE_ORDER)


def encode_window_posneg(x_win: np.ndarray, thresholds: np.ndarray) -> np.ndarray:
    """
    x_win: [T, F] normalized features
    thresholds: [F]
    returns spikes: [T, 2F] (0/1)
    Delta encoder with accumulator per feature.
    """
    T, F = x_win.shape
    spk = np.zeros((T, 2 * F), dtype=np.float32)
    acc = x_win[0].copy()

    for t in range(T):
        for k in range(F):
            d = x_win[t, k] - acc[k]
            thr = thresholds[k]
            if d >= thr:
                spk[t, k] = 1.0
                acc[k] += thr
            elif d <= -thr:
                spk[t, F + k] = 1.0
                acc[k] -= thr

    return spk


class WindowSpikeDataset(Dataset):
    def __init__(self, npz_path: Path, config_path: Path):
        d = np.load(npz_path, allow_pickle=True)
        X = d["X"].astype(np.float32)  # [N, T, F]
        y = d["y"].astype(np.int64)

        self.classes = list(d["classes"])
        self.features = list(d["features"])

        if self.features != FEATURE_ORDER:
            raise RuntimeError(f"Feature order mismatch.\nExpected: {FEATURE_ORDER}\nFound: {self.features}")

        spec = load_encoder_spec(config_path)
        thr = spec.thresholds

        # Pre-encode to spikes for speed
        Xspk = np.zeros((X.shape[0], X.shape[1], 2 * X.shape[2]), dtype=np.float32)
        for i in range(X.shape[0]):
            Xspk[i] = encode_window_posneg(X[i], thr)

        self.Xspk = torch.from_numpy(Xspk)  # float32
        self.y = torch.from_numpy(y)

    def __len__(self) -> int:
        return int(self.y.shape[0])

    def __getitem__(self, idx: int):
        return self.Xspk[idx], self.y[idx]
