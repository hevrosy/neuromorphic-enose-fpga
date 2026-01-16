from __future__ import annotations

from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

def main():
    p = Path("data/processed/train_windows.npz")
    d = np.load(p, allow_pickle=True)
    X = d["X"]  # [N, W, F]
    y = d["y"]
    features = list(d["features"])
    classes = list(d["classes"])

    print("X:", X.shape, "y:", y.shape)
    # Plot first window of each class (if exists)
    for cls_i, cls_name in enumerate(classes):
        idxs = np.where(y == cls_i)[0]
        if len(idxs) == 0:
            continue
        w = X[idxs[0]]  # [W, F]
        plt.figure()
        plt.title(f"First window for class {cls_name}")
        for f_i, fname in enumerate(features):
            plt.plot(w[:, f_i], label=fname)
        plt.legend()
        plt.show()

if __name__ == "__main__":
    main()
