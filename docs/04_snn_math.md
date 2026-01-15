# SNN Math (LIF, window decision)

## Input
6 features -> delta encoding -> 12 spike inputs (pos/neg).

## LIF update (discrete, fixed-point friendly)
Hidden:
Vh <- Vh - (Vh >> Lh) + Ih
if Vh >= Th: spike=1, Vh <- 0 else spike=0

Output:
Vo <- Vo - (Vo >> Lo) + Io
if Vo >= To: Cout++, Vo <- 0

## Window decision
Run for W timesteps (e.g., 10). Counts Cout[3] -> class=argmax.
Confidence = max(C)/sum(C) (Q0.8).
