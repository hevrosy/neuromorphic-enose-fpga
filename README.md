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
