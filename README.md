# Edge AI Electronic Nose (E-Nose) for Food Quality Assessment
**Heterogeneous HW/SW Co-Design on Zynq-7000 SoC using Spiking Neural Networks (SNN)**

[![Platform](https://img.shields.io/badge/Platform-Xilinx%20Zynq--7000-blue.svg)]()
[![Language](https://img.shields.io/badge/Language-Python%20%7C%20Verilog-green.svg)]()
[![AI](https://img.shields.io/badge/AI-Spiking%20Neural%20Network-red.svg)]()
[![Status](https://img.shields.io/badge/Status-Stable%20(v5.6)-brightgreen.svg)]()

## Абстракт (Abstract)
Този проект представя разработката на автономна, био-вдъхновена система за изкуствено обоняние (Електронен нос), предназначена за мониторинг на качеството на хранителни продукти в реално време. Системата използва хетерогенна изчислителна архитектура (HW/SW Co-Design), базирана на Xilinx Zynq-7000 SoC. За обработка на сензорните данни е реализирана 8-битова квантизирана Спайкова невронна мрежа (Spiking Neural Network - SNN) директно във FPGA матрицата, обучавана локално чрез статистическо правило на Хеб (Hebbian Learning).

## 1. Системна Архитектура (System Architecture)
Архитектурата използва парадигмата на съвместния хардуерно-софтуерен дизайн, разделяйки недетерминираните контролни процеси от масивно паралелните тензорни изчисления.

* **Processing System (PS) - ARM Cortex-A9:** Управлява операционната система (Linux/Pynq), комуникацията по I2C шината със цифровия сензор, динамичното проследяване на базовата линия, изчисляването на синаптичните тегла (Hebbian probabilities) и телеметрията (GLP Logging).
* **Programmable Logic (PL) - FPGA Fabric:** Съдържа персонализирани IP ядра (Intellectual Property Cores). Включва `enose_preproc_0` за хардуерна бинаризация на диференциалните сензорни сигнали и `enose_accel_0` за LIF (Leaky Integrate-and-Fire) невронна интеграция в реално време.
* **AXI4-Lite Interconnect:** Осъществява Memory-Mapped комуникация между PS и PL. Процесорът асинхронно записва диференциални стойности (Delta) и прагове, и извлича натрупаните спайкове (Spike Counts) от изходните регистри на хардуерния ускорител.

## 2. Сензорен Слой и Флуидика (Sensory Modality & Fluidics)
Системата извлича пространствено-времеви (spatiotemporal) химични отпечатъци чрез мултимодален сензорен масив:
1. **MQ3 (Калаен диоксид, SnO2):** Високочувствителен към алкохоли и етанол (продукти на ферментация).
2. **MQ4:** Чувствителен към метан и въглеводороди.
3. **MQ135:** Чувствителен към амоняк, сулфиди и азотни оксиди (разпад на протеини).
4. **BME688 (Bosch MEMS):** Прецизен цифров VOC (Volatile Organic Compounds) сензор, осигуряващ и термодинамична компенсация (Температура и Влажност).

**Флуидна кинетика:** Данните се събират чрез метода на газовата шапка (Headspace sampling). За избягване на хаотична дисперсия на Тейлър, системата налага строг 60-секунден софтуерен таймер за насищане на ламинарния поток преди запис на данни.

## 3. Алгоритмични решения и Компенсации (Algorithmic Solutions)
По време на разработката бяха решени няколко фундаментални проблема във физикохимията на метало-оксидните сензори:

* **Многовариантна детекция на плато (Multivariate Plateau Detection):**
Поради термичната маса на аналоговите сензори, десорбцията отнема време. Системата използва 10-секунден плъзгащ се прозорец, изисквайки едновременна стабилност и на 4-те сензора (флуктуация < 8 mV за MQ и < 4000 Ома за VOC) в продължение на 15 секунди, преди да позволи заключване на базовата линия.
* **Капанът на подмножествата (Subset/Superset Overlap Trap):**
Тъй като FPGA хардуерът реализира само положителни (ексцитаторни) синапси без латерално потискане, съществува риск от припокриване на класове (Клас 1 да е химично подмножество на Клас 2). Въведен е софтуерен *Tie-Breaker* алгоритъм, който при равен брой изходни спайкове присъжда детекцията на по-простия клас, използвайки принципа на Бръснача на Окам.
* **Десенсибилизация на синапсите (Refractory Saturation Prevention):**
За да се предотврати хардуерно препълване (Spike Saturation) на интеграторите при високи газови концентрации, мултипликаторът на синаптичните тегла (`TRAIN_MULTIPLIER`) е квантизиран до базова стойност 10x, запазвайки динамичния обхват на невронните отговори.
* **Ослепяване за климата (Environmental Blindness):**
За да се избегне научаване на артефакти (напр. промяна в температурата при отваряне на тестовата камера), алгоритъмът за обучение на Хеб софтуерно занулява синапсите за температура и влажност (индекси 8 до 11) по време на матричната генерация.

## 4. Инструкции за работа (GLP Protocol)
Проектът спазва принципите на Добрата лабораторна практика (Good Laboratory Practice - GLP).

### Стъпка 1: Подготовка на пробите
Подгответе 3 проби (напр. Свеж плод, Престоял плод, Развален плод) в изолирани стъклени съдове (vials) за поне 45 минути.

### Стъпка 2: Събиране на Dataset
Стартирайте `enose_master.py` на Pynq Linux обкръжението.
1. Проветрете камерата и стартирайте Опция `[5]` за калибрация на базата.
2. Свържете Проба 1 и изберете Опция `[2]` за запис на Клас 0.
3. Проветрете камерата `[6]`, калибрирайте отново `[5]`.
4. Повторете процеса за Клас 1 и Клас 2.

### Стъпка 3: Hebbian Learning
Изберете Опция `[3]`. Python скриптът ще извлече химичните профили и ще генерира файловете `w1.mem` (входни синапси) и `w2.mem` (изходни синапси).

### Стъпка 4: Хардуерна компилация
Изпълнете Tcl скрипта във Vivado, за да синтезирате новия bitstream (`snn_v13.bit`) с "изпечените" знания в Block RAM паметта на FPGA.

### Стъпка 5: Real-Time Inference
Изберете Опция `[4]`. Системата ще започне класификация в реално време на всеки 1000 милисекунди (20 времеви стъпки на SNN). За бърз рестарт на базовата линия без проветряване, използвайте клавиша `R`.

## 5. Телеметрия и Диагностика (Black Box Logging)
Системата е оборудвана с пълна проследимост (Traceability). Автоматично се генерират 4 диагностични файла:
* `log_01_calibration.csv`: Записва скоростта на десорбция и детекцията на плато.
* `log_02_dataset.csv`: Суровите масиви от данни с точен Timestamp.
* `log_03_training.txt`: Текстов дъмп на химичните профили и генерираните тензори.
* `log_04_inference.csv`: **Spike Decoder Лог**. Записва всяко решение на мрежата, броя на спайковете и дешифрира кои сензорни прагове са били преминати (напр. `M3_Up | VOC_Dn`).


# Neuromorphic e-Nose on FPGA  
### Dissertation Companion Repository  
**Doctoral Research Project – Neuromorphic Embedded Systems**

---

## 1. Repository Purpose

This repository accompanies a doctoral research project focused on the design, implementation, and validation of a neuromorphic spiking neural network (SNN) accelerator for gas sensing applications deployed on FPGA.

The work demonstrates a complete hardware–software co-design pipeline:

1. Multimodal gas sensing acquisition  
2. Signal preprocessing and spike encoding  
3. Offline SNN training (surrogate gradient method)  
4. Quantized weight export  
5. AXI-based FPGA inference accelerator  
6. Bit-accurate hardware/software validation  

The repository contains all components required to reproduce the experimental framework described in the dissertation.

---

## 2. Research Context

Electronic noses (e-noses) rely on sensor arrays producing slow, drifting, analog signals. Traditional neural inference is computationally expensive and power intensive for embedded environments.

This research proposes:

- Event-driven spike encoding (delta-based)
- Low-precision fixed-point SNN inference
- FPGA hardware acceleration
- Deterministic window-based classification
- Hardware/software co-verification methodology

The system targets low-power embedded classification while maintaining reproducibility and deterministic behavior.

---

## 3. System Architecture Overview

### 3.1 Hardware Platform

- **Board:** PYNQ-Z2 (Xilinx Zynq-7020)
- **PS:** ARM Cortex-A9 (Linux)
- **PL:** Custom RTL SNN accelerator
- **Interfaces:**
  - AXI-Lite (control/status)
  - AXI-Stream (spike input with TLAST)
  - XADC (analog MQ sensors)
  - I2C (BME688)

---

### 3.2 Processing Flow

```
Sensors → Preprocess → Delta Spike Encoding → AXI-Stream
                                           ↓
                                    FPGA SNN Core
                                           ↓
                                      Classification
```

The accelerator performs window-based inference using a fixed-size spike sequence terminated by TLAST.

---

## 4. Repository Structure

```
docs/          Dissertation-related technical documentation
src/           Core Python package
scripts/       CLI utilities and validation tools
fpga/          RTL sources, overlays, Vivado scripts
notebooks/     Experimental workflow notebooks
cadfiles/      Parametric sensing chamber design
config/        YAML configuration files
```

---

## 5. FPGA Implementation

### 5.1 Available Overlays

| Overlay | Purpose | Status |
|----------|---------|--------|
| Overlay0 | AXI contract validation (stub core) | Validated |
| Overlay1 | Real SNN inference accelerator | Implemented |

Pre-built bitstreams:

```
fpga/overlays/overlay0/enose_accel.bit
fpga/overlays/overlay1/snn_core.bit
```

---

### 5.2 RTL Modules

```
fpga/rtl/
├── enose_accel_stub.v
├── enose_accel.v
├── snn_core.sv
├── axi_lite_regs.sv
├── axi_stream_in.sv
├── fifo.sv
```

Design characteristics:

- Event-driven architecture
- 12-channel spike mask input
- Window-based processing
- Fixed-point arithmetic
- Deterministic latency per inference window
- Register-mapped configuration

---

## 6. Software Stack

The `src/` package provides a complete experimental pipeline:

### 6.1 Data Acquisition

```
src/collect/
```

- MQ sensor sampling (XADC)
- BME688 digital sensing
- Metadata logging

---

### 6.2 Preprocessing

```
src/preprocess/
```

- Baseline removal
- Normalization
- Window segmentation

---

### 6.3 Spike Encoding

```
src/encoding/
```

- Delta encoder
- Multi-channel spike mask generation

---

### 6.4 SNN Training

```
src/models/
```

- LIF neuron model
- Surrogate gradient training (PyTorch)
- Quantized export (int8)
- Golden reference inference

---

### 6.5 FPGA Emulation

```
src/fpga/
```

- AXI register map abstraction
- Contract-level emulator
- Overlay driver interface

---

## 7. Experimental Workflow

### 7.1 Dataset Construction

```bash
python scripts/build_dataset.py \
  --config config/enose_default.yaml \
  --window-len 10
```

### 7.2 Model Training

```bash
python -m src.models.snn_train \
  --config config/enose_default.yaml \
  --epochs 20
```

### 7.3 Quantized Export

```bash
python -m src.models.export_weights \
  --ckpt exports/snn_ckpt.pt
```

---

## 8. Hardware–Software Co-Verification

The methodology follows a contract-first approach:

1. AXI interface defined and documented
2. Software emulator implements identical register behavior
3. Quantized weights exported from trained model
4. Spike vectors verified bit-exact
5. FPGA overlay validated on hardware

See: `docs/05_fpga_interface.md`

---

## 9. Mechanical Design

A parametric sensing chamber is provided:

```
cadfiles/enose_chamber_parametric.scad
```

Design objectives:

- Controlled airflow
- Homogeneous gas distribution
- Reduced dead zones
- Separation of electronics and flow region

---

## 10. Research Contributions

This repository demonstrates:

- End-to-end neuromorphic sensing pipeline
- FPGA-based SNN accelerator design
- Deterministic embedded inference
- Reproducible quantized deployment flow
- Hardware/software co-design methodology

---

## 11. License

See `LICENSE`.

---

## 12. Academic Use

This repository accompanies a doctoral dissertation.  
If referencing this work in academic publications, please cite appropriately.

A formal citation entry will be added upon thesis submission.
