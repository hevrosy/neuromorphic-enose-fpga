from __future__ import annotations

from dataclasses import dataclass
from typing import Tuple

import torch
import torch.nn as nn


class SurrogateSpike(torch.autograd.Function):
    """
    Forward: hard threshold (v >= th)
    Backward: smooth surrogate gradient (sigmoid derivative)
    """
    @staticmethod
    def forward(ctx, v: torch.Tensor, th: float, beta: float):
        ctx.save_for_backward(v)
        ctx.th = th
        ctx.beta = beta
        return (v >= th).to(v.dtype)

    @staticmethod
    def backward(ctx, grad_output: torch.Tensor):
        (v,) = ctx.saved_tensors
        th = float(ctx.th)
        beta = float(ctx.beta)

        # surrogate derivative: beta * sigmoid(beta*(v-th))*(1-sigmoid(...))
        z = beta * (v - th)
        s = torch.sigmoid(z)
        grad_v = grad_output * (beta * s * (1.0 - s))
        return grad_v, None, None


def spike_fn(v: torch.Tensor, th: float, beta: float) -> torch.Tensor:
    return SurrogateSpike.apply(v, th, beta)


@dataclass(frozen=True)
class SNNConfig:
    n_in: int = 12
    n_hidden: int = 32
    n_out: int = 3
    window_len: int = 10

    leak_h_shift: int = 4
    leak_o_shift: int = 4
    th_h: float = 1.0
    th_o: float = 1.0
    beta: float = 10.0  # surrogate steepness


def shift_to_alpha(shift: int) -> float:
    # alpha = 1 - 2^-shift (fixed-point-friendly leak)
    shift = max(1, int(shift))
    return 1.0 - (1.0 / (2.0 ** shift))


class SNNLIF(nn.Module):
    def __init__(self, cfg: SNNConfig):
        super().__init__()
        self.cfg = cfg
        self.W1 = nn.Linear(cfg.n_in, cfg.n_hidden, bias=False)
        self.W2 = nn.Linear(cfg.n_hidden, cfg.n_out, bias=False)

        # leak factors
        self.alpha_h = shift_to_alpha(cfg.leak_h_shift)
        self.alpha_o = shift_to_alpha(cfg.leak_o_shift)

        # init small weights
        nn.init.normal_(self.W1.weight, mean=0.0, std=0.2)
        nn.init.normal_(self.W2.weight, mean=0.0, std=0.2)

    def forward(self, x_spk: torch.Tensor) -> torch.Tensor:
        """
        x_spk: [B, T, n_in] spikes (0/1)
        returns logits: [B, n_out] spike counts
        """
        B, T, Nin = x_spk.shape
        assert Nin == self.cfg.n_in

        # state
        vh = torch.zeros((B, self.cfg.n_hidden), device=x_spk.device, dtype=x_spk.dtype)
        vo = torch.zeros((B, self.cfg.n_out), device=x_spk.device, dtype=x_spk.dtype)

        counts = torch.zeros((B, self.cfg.n_out), device=x_spk.device, dtype=x_spk.dtype)

        for t in range(T):
            ih = self.W1(x_spk[:, t, :])

            vh = self.alpha_h * vh + ih
            sh = spike_fn(vh, self.cfg.th_h, self.cfg.beta)
            # reset
            vh = vh * (1.0 - sh)

            io = self.W2(sh)
            vo = self.alpha_o * vo + io
            so = spike_fn(vo, self.cfg.th_o, self.cfg.beta)
            vo = vo * (1.0 - so)

            counts = counts + so

        return counts
