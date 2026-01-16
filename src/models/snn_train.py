from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

import torch
from torch.utils.data import DataLoader

from .snn_dataset import WindowSpikeDataset
from .snn_torch import SNNConfig, SNNLIF


def evaluate(model: torch.nn.Module, loader: DataLoader, device: torch.device) -> float:
    model.eval()
    correct = 0
    total = 0
    with torch.no_grad():
        for x, y in loader:
            x = x.to(device)
            y = y.to(device)
            logits = model(x)  # [B,3] counts
            pred = torch.argmax(logits, dim=1)
            correct += int((pred == y).sum().item())
            total += int(y.numel())
    return correct / max(total, 1)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True, help="config/enose_default.yaml")
    ap.add_argument("--train", default="data/processed/train_windows.npz")
    ap.add_argument("--val", default="data/processed/val_windows.npz")
    ap.add_argument("--epochs", type=int, default=20)
    ap.add_argument("--batch", type=int, default=256)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--nh", type=int, default=32)
    ap.add_argument("--wlen", type=int, default=10)
    ap.add_argument("--thh", type=float, default=1.0)
    ap.add_argument("--tho", type=float, default=1.0)
    ap.add_argument("--leakh", type=int, default=4)
    ap.add_argument("--leako", type=int, default=4)
    ap.add_argument("--beta", type=float, default=10.0)
    ap.add_argument("--device", default="cpu", choices=["cpu", "cuda"])
    ap.add_argument("--out", default="exports/snn_ckpt.pt")
    args = ap.parse_args()

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    device = torch.device(args.device if (args.device == "cuda" and torch.cuda.is_available()) else "cpu")

    train_ds = WindowSpikeDataset(Path(args.train), Path(args.config))
    val_ds = WindowSpikeDataset(Path(args.val), Path(args.config))

    train_loader = DataLoader(train_ds, batch_size=args.batch, shuffle=True, drop_last=False)
    val_loader = DataLoader(val_ds, batch_size=args.batch, shuffle=False, drop_last=False)

    cfg = SNNConfig(
        n_in=12,
        n_hidden=args.nh,
        n_out=3,
        window_len=args.wlen,
        leak_h_shift=args.leakh,
        leak_o_shift=args.leako,
        th_h=args.thh,
        th_o=args.tho,
        beta=args.beta,
    )
    model = SNNLIF(cfg).to(device)

    opt = torch.optim.Adam(model.parameters(), lr=args.lr)
    loss_fn = torch.nn.CrossEntropyLoss()

    best_val = 0.0
    history = []

    for epoch in range(1, args.epochs + 1):
        model.train()
        running = 0.0
        n_batches = 0

        for x, y in train_loader:
            x = x.to(device)
            y = y.to(device)

            opt.zero_grad()
            logits = model(x)          # counts as logits
            loss = loss_fn(logits, y)
            loss.backward()
            opt.step()

            running += float(loss.item())
            n_batches += 1

        train_acc = evaluate(model, train_loader, device)
        val_acc = evaluate(model, val_loader, device)

        row = {
            "epoch": epoch,
            "loss": running / max(n_batches, 1),
            "train_acc": train_acc,
            "val_acc": val_acc,
        }
        history.append(row)
        print(f"[E{epoch:03d}] loss={row['loss']:.4f} train_acc={train_acc:.3f} val_acc={val_acc:.3f}")

        if val_acc >= best_val:
            best_val = val_acc
            ckpt = {
                "snn_config": asdict(cfg),
                "state_dict": model.state_dict(),
                "classes": train_ds.classes,
                "features": train_ds.features,
                "history": history,
            }
            torch.save(ckpt, out_path)

    print(f"[DONE] best_val={best_val:.3f} checkpoint saved to {out_path}")


if __name__ == "__main__":
    main()
