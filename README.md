# Neuromorphic e-nose on FPGA (PYNQ-Z2)

Цел: реализация на енергийно-ефективен невроморфен (SNN) inference ускорител върху FPGA (PL) за e-nose (MQ + BME688),
с пълен възпроизводим pipeline: събиране на данни → preprocess → spike encoding → SNN training (PC) → export → FPGA inference.

## Hardware
- PYNQ-Z2 (Zynq-7020)
- MQ-135, MQ-3, MQ-4 (аналогови изходи към XADC входове A0..A2)
- BME688 (I2C) – температура/влажност + gas resistance
- Камера: 0.5–1L, вентилатор 5V за хомогенизация

## Software
- Vivado (по-късно за FPGA частта)
- Python (PYNQ PS) за DAQ/контрол/логване
- Python (PC) за обучение на SNN и export на weights

## Repo структура (важното)
- docs/ : протоколи, формат на данни, математика на SNN, FPGA интерфейси
- src/collect/ : DAQ (XADC + BME688) и логване
- src/preprocess/ : baseline/normalize/windowing
- src/encoding/ : delta encoder (pos/neg spikes)
- src/models/ : golden reference inference (CPU) + export

## Quickstart (DAQ skeleton)
1) Настрой config/enose_default.yaml
2) На PYNQ:
   python -m src.collect.collect_enose --config config/enose_default.yaml --label Fresh --batch B01

Данните се записват в data/raw/*.csv и data/meta/*.json

## Научна рамка
- Dataset протокол: docs/02_dataset_protocol.md
- Data format: docs/03_data_format.md
- SNN модел: docs/04_snn_math.md
- Експерименти: docs/06_experiments.md


## What we have so far (milestones)

### ✅ Commit 3 — Offline dataset pipeline (no hardware required)
- Synthetic e-nose runs generator (CSV + JSON metadata)
- Preprocess + windowing builder → `train_windows.npz`, `val_windows.npz`
- Quick plotting/preview helper

### ✅ Commit 4 — SNN training + export + roundtrip verification
- SNN model (LIF) trained with PyTorch + surrogate gradients
- Delta encoder (positive/negative spikes) → 12 spike channels
- Golden inference implementation
- Roundtrip check: **Torch forward = Golden math** (agree ~ 1.0)
- Int8 weight export (files ready for BRAM init / RTL)

### ✅ Commit 4.1 — Quality checks
- Spike density profiling (spikes/timestep, spikes/channel)
- Quant roundtrip check (float vs int8-dequant inference agreement)

### ✅ Commit 5 — FPGA interface contract + emulator + driver facade
- Documented AXI-Lite register map + AXI-Stream spike format
- Python FPGA emulator implementing the same contract
- Driver facade that later can be swapped to real PYNQ overlay (MMIO + DMA)

---

## Quickstart (Windows 11, offline)

### 1) Create and activate venv
```
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
If you train, install training deps (PyTorch):
python -m pip install -r requirements_train.txt
2) Generate synthetic raw/meta runs
python scripts\generate_synthetic_runs.py --config config\enose_default.yaml --runs-per-class 6 --batches 3 --seed 1234
3) Build processed dataset (preprocess + windowing)
python scripts\build_dataset.py --config config\enose_default.yaml --val-batch B03 --window-len 10 --stride 1 --out data\processed
Optional preview:
python scripts\preview_processed.py
Train SNN (offline)
4) Train (Torch)
python -m src.models.snn_train --config config\enose_default.yaml --epochs 20 --batch 256 --lr 0.001 --nh 32 --wlen 10 --thh 1.0 --tho 1.0 --leakh 4 --leako 4 --beta 10.0 --device cpu --out exports\snn_ckpt.pt
5) Roundtrip check (Torch vs Golden float)
python -m scripts.roundtrip_check --config config\enose_default.yaml --ckpt exports\snn_ckpt.pt --val data\processed\val_windows.npz --n 512
6) Export weights (int8)
python -m src.models.export_weights --ckpt exports\snn_ckpt.pt --outdir exports
7) Spike profiling + Quant check
python -m scripts.spike_profile --config config\enose_default.yaml --data data\processed\val_windows.npz --max 5000
python -m scripts.quant_roundtrip_check --config config\enose_default.yaml --ckpt exports\snn_ckpt.pt --val data\processed\val_windows.npz --outdir exports --n 1024
FPGA emulator (contract-first verification)
The emulator consumes the same spike-stream contract planned for hardware:
AXI-Stream input: 32-bit spike mask word per timestep (12 LSBs used)
AXI-Lite control/status/result registers
Run evaluation through the emulator (uses exported int8 weights dequantized to float for golden inference):
python -m scripts.emulator_eval --config config\enose_default.yaml --val data\processed\val_windows.npz --exports exports --n 2000 --window-len 10
Note on confidence: confidence is currently computed from output spike counts. If all output counts are zero in a window, confidence becomes 0. This metric will be refined later for hardware (e.g., membrane-based confidence).

Repository structure :

neuromorphic-enose-fpga/
  README.md
  LICENSE
  .gitignore
  requirements.txt
  requirements_train.txt

  config/
    enose_default.yaml         # acquisition + preprocess + encoding thresholds + labels

  docs/
    00_overview.md
    01_literature_protocol.md
    02_dataset_protocol.md
    03_data_format.md
    04_snn_math.md
    05_fpga_interface.md       # AXI-Lite + AXI-Stream contract (registers + stream word format)
    06_experiments.md

  data/
    raw/        # CSV logs (ignored by git; keep .keep)
    meta/       # JSON metadata (ignored by git; keep .keep)
    processed/  # npz windows + scaler + summary (ignored by git; keep .keep)

  notebooks/
    01_collect_preview.ipynb
    02_preprocess.ipynb
    03_train_snn.ipynb
    04_export_weights.ipynb
    05_fpga_inference_eval.ipynb

  scripts/
    __init__.py
    generate_synthetic_runs.py # produces raw CSV + meta JSON (synthetic)
    build_dataset.py           # preprocess + windowing -> processed npz
    preview_processed.py       # quick plot of sample windows
    roundtrip_check.py         # Torch vs Golden float agreement check
    spike_profile.py           # spike density per timestep/channel
    quant_roundtrip_check.py   # float vs int8-dequant inference agreement
    emulator_eval.py           # evaluate through FPGAEmulator contract

  src/
    __init__.py

    collect/
      __init__.py
      collect_enose.py         # future: real acquisition on PYNQ (XADC/BME)
      sensors_xadc.py          # future: XADC access
      sensor_bme688.py         # future: BME680/688 access

    preprocess/
      __init__.py
      baseline.py              # baseline correction
      normalize.py             # fit/apply scaler (train-only fit)
      windowing.py             # make windows (N,W,F) + labels

    encoding/
      __init__.py
      delta_encoder.py         # delta pos/neg spikes (12 channels from 6 features)

    models/
      __init__.py
      snn_torch.py             # SNN (LIF) + surrogate spike function (Torch)
      snn_dataset.py           # loads windows + encodes to spikes
      snn_train.py             # training loop + checkpoint
      golden_inference_float.py# golden reference inference (float)
      export_weights.py        # int8 quant + hex/params export

    fpga/
      __init__.py
      regs.py                  # AXI-Lite offsets + bit definitions
      fpga_emulator.py         # contract emulator (AXI-Lite + stream -> golden inference)
      overlay_driver.py        # driver facade (emulator today, real overlay later)