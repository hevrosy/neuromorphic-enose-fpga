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
