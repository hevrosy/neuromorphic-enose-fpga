# Overview

Проектът реализира e-nose система (MQ + BME688) и невроморфно SNN inference ядро върху FPGA (PYNQ-Z2).

Основни блокове:
1) Data acquisition (XADC + I2C) + логване
2) Preprocess (baseline, normalize) + spike encoding (pos/neg)
3) SNN training (PC) + export на тегла/параметри
4) FPGA inference ядро (PL) + PS контрол (AXI)

Ключови метрики:
- Accuracy/F1 за 3 класа Fresh/Warning/Spoiled
- Latency (end-to-end)
- Resource usage (LUT/FF/BRAM/DSP)
- (по възможност) Power / energy-per-inference
