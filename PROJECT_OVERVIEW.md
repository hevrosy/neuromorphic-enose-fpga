# PROJECT OVERVIEW  
## Neuromorphic FPGA-Based Electronic Nose

---

## 1. Research Objective

The primary objective of this doctoral research project is to design and validate a neuromorphic hardware accelerator for embedded gas classification using spiking neural networks deployed on FPGA.

The project aims to answer the following research questions:

1. Can event-driven SNN inference reduce computational complexity for slow chemical sensing signals?
2. What architectural trade-offs arise when mapping SNNs to FPGA fabric?
3. How can deterministic inference be guaranteed in embedded neuromorphic systems?
4. What fixed-point quantization limits preserve classification accuracy?

---

## 2. Scientific Motivation

Electronic nose systems suffer from:

- Slow transient sensor response
- Baseline drift
- Sensor cross-sensitivity
- Power constraints in embedded deployments

Traditional deep neural networks are often inefficient for such low-bandwidth, temporal data.

This work proposes:

- Delta-based spike encoding
- Windowed SNN inference
- Event-driven computation
- Fixed-point hardware arithmetic
- AXI contract-based hardware abstraction

---

## 3. Technical Contributions

### 3.1 Algorithmic

- Custom delta spike encoding for gas transients
- LIF-based classification network
- Surrogate gradient training
- Quantization-aware export flow

### 3.2 Hardware

- AXI-Stream spike ingestion
- AXI-Lite control interface
- Window-based processing core
- Modular RTL architecture
- Deterministic state machine control

### 3.3 Methodological

- Contract-first FPGA development
- Bit-accurate emulator
- Golden software inference comparison
- Reproducible dataset generation

---

## 4. Experimental Framework

The experimental methodology consists of:

1. Synthetic dataset generation
2. Real sensor acquisition validation
3. Offline training
4. Fixed-point export
5. Emulator validation
6. FPGA deployment
7. Accuracy and determinism verification

---

## 5. Performance Evaluation Plan

Future benchmarking will include:

- LUT / FF / BRAM / DSP utilization
- Inference latency per window
- Throughput (windows/sec)
- Power consumption (board-level)
- Accuracy comparison (float vs quantized vs FPGA)

---

## 6. Dissertation Integration

This repository supports the dissertation chapters:

- Neuromorphic principles for chemical sensing
- FPGA architecture design
- Fixed-point quantization analysis
- Hardware/software co-verification methodology
- Experimental validation and results

---

## 7. Future Research Directions

- On-chip learning mechanisms
- Multi-class adaptive classification
- Dynamic threshold tuning
- Edge AI deployment scenarios
- Neuromorphic sensor fusion

---

## 8. Target Impact

The project contributes to:

- Embedded neuromorphic systems
- Edge AI acceleration
- Low-power sensing architectures
- Hardware-aware neural network design
- Applied FPGA-based machine intelligence

---

## 9. Repository Role

This repository serves as:

- Experimental backbone of the dissertation
- Reproducible implementation reference
- Validation environment for future extensions
- Foundation for journal publication and conference papers

---

End of overview.
