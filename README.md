# Neuromorphic e-Nose on FPGA

## FPGA-Based Spiking Neural Network Architecture for Electronic-Nose Sensor Data Processing

---

## 1. Overview

This repository presents a neuromorphic electronic-nose system implemented on FPGA for the acquisition, preprocessing, encoding, and classification-oriented processing of gas-sensor data. The project combines a custom measurement chamber, a gas-sensor acquisition pipeline, baseline correction, delta-based spike encoding, offline spiking neural network training, weight quantization, and FPGA-based low-latency inference.

The system is designed for research in food-quality assessment, volatile organic compound sensing, neuromorphic engineering, FPGA acceleration, and edge artificial intelligence. The main hardware platform is the **PYNQ-Z2 development board**, based on the **Xilinx Zynq-7020 SoC**.

The current implementation includes a routed FPGA overlay containing a hardware preprocessing block and a fixed-point spiking neural network accelerator with a **12–32–3 topology**. The design was synthesized and implemented in **Vivado 2025.2** for the `xc7z020clg400-1` device.

At the current stage, the project demonstrates the hardware feasibility of a low-resource FPGA-based spiking inference engine for electronic-nose data. Full experimental classification metrics on real food samples, such as accuracy, macro-F1 score, and confusion matrix, are planned as the next validation stage.

---

## 2. Motivation

Food-quality assessment is an important task in food safety, storage monitoring, logistics, smart packaging, and embedded sensing systems. Classical laboratory methods are often accurate, but they require specialized equipment, trained personnel, consumables, and time-consuming procedures.

Electronic-nose systems offer an alternative approach by using an array of partially selective gas sensors to detect patterns in volatile organic compounds emitted by samples. Instead of identifying a single chemical compound, an electronic nose analyzes the global response pattern of several sensors.

In the context of food-quality monitoring, volatile compounds may change due to:

* fermentation;
* oxidation;
* microbial activity;
* protein degradation;
* changes in pH;
* aging or spoilage;
* environmental temperature and humidity variation.

Low-cost metal-oxide gas sensors are attractive for embedded electronic-nose systems, but they also introduce several challenges:

* slow response and recovery time;
* sensor drift;
* sensitivity to temperature and humidity;
* cross-sensitivity to multiple gases;
* nonlinear response;
* baseline instability;
* memory effects between measurements.

This project addresses these challenges by combining controlled headspace measurement, baseline correction, event-based spike encoding, and FPGA-based spiking neural network inference.

---

## 3. Main Concept

The system follows the complete processing path from the physical sample to hardware inference:

```text
Food sample
    ↓
Volatile organic compounds in the measurement chamber
    ↓
Gas and environmental sensor response
    ↓
Time-series data acquisition
    ↓
Baseline correction and preprocessing
    ↓
Delta-based spike encoding
    ↓
Software SNN training
    ↓
Weight quantization
    ↓
FPGA deployment
    ↓
Hardware spiking inference
    ↓
Output spike counts and predicted class
```

The architecture consists of three main layers:

1. **Measurement Layer**
   A custom chamber, food sample, gas sensors, environmental sensors, airflow control, and experimental protocol.

2. **Software Layer**
   Data acquisition, preprocessing, spike encoding, dataset generation, SNN training, validation, quantization, and evaluation.

3. **FPGA Layer**
   Hardware preprocessing, fixed-point SNN inference, AXI-based control, output counters, class decision logic, and latency measurement.

---

## 4. Measurement Chamber

A key part of the project is the custom measurement chamber used for collecting gas-sensor data from food samples. The chamber is designed to provide a repeatable headspace environment in which volatile compounds emitted by a sample can accumulate and be measured by the sensor array.

### 4.1 Purpose of the Chamber

The measurement chamber is used to:

* isolate the food sample from uncontrolled external airflow;
* allow volatile compounds to accumulate above the sample;
* keep a fixed geometry between the sample and the sensors;
* improve repeatability between measurement runs;
* reduce random environmental disturbances;
* support controlled purge cycles between experiments;
* enable airflow homogenization using a small fan.

In gas-sensor experiments, the physical measurement geometry is critical. The chamber volume, sensor placement, sample position, airflow, and purge time directly affect the shape of the sensor response.

### 4.2 Headspace Measurement Principle

The project uses a headspace-inspired measurement approach. The food sample is placed in a closed or semi-controlled chamber, and the sensors measure the gas phase above the sample rather than contacting the sample directly.

This approach has several advantages:

* the measurement is non-destructive;
* the sensors are not directly contaminated by the sample;
* volatile compounds can accumulate in a controlled volume;
* the temporal dynamics of gas emission can be observed;
* the same method can be applied to different sample types.

### 4.3 Chamber Components

A typical chamber setup includes:

| Component                            | Function                                                |
| ------------------------------------ | ------------------------------------------------------- |
| Measurement chamber                  | Provides a controlled volume for the sample and sensors |
| Sample holder                        | Keeps the sample in a repeatable position               |
| Gas sensor array                     | Measures the response to volatile compounds             |
| Temperature and humidity sensor      | Tracks environmental conditions                         |
| Small fan                            | Helps homogenize the gas mixture                        |
| Ventilation opening or removable lid | Enables purge between runs                              |
| Data acquisition unit                | Reads raw sensor values                                 |
| FPGA / PYNQ-Z2 platform              | Performs hardware inference                             |

### 4.4 Recommended Measurement Cycle

A reproducible experiment should follow a fixed measurement protocol:

```text
1. Purge the chamber
2. Record baseline without the active sample response
3. Insert or expose the sample
4. Wait for short stabilization
5. Record sensor time-series data
6. Remove the sample
7. Purge the chamber before the next run
```

Example timing:

| Stage                  | Example Duration |
| ---------------------- | ---------------: |
| Pre-measurement purge  |            180 s |
| Baseline measurement   |             30 s |
| Sample stabilization   |             60 s |
| Active recording       |        120–300 s |
| Sampling rate          |             1 Hz |
| Post-measurement purge |            180 s |

### 4.5 Baseline Importance

Metal-oxide gas sensors may drift over time and may not start from the same value in every experiment. For this reason, a baseline is recorded for each measurement run.

Instead of using only raw sensor values, the system can use baseline-corrected values:

```text
corrected_value = current_sensor_value - baseline_sensor_value
```

This reduces the influence of slow drift and helps make measurements more comparable across different runs.

---

## 5. Sensor Layer

The system is designed around six input channels. A typical configuration includes MQ-series metal-oxide gas sensors and an environmental gas sensor.

Example input channels:

| Channel              | Meaning                                          |
| -------------------- | ------------------------------------------------ |
| MQ135                | Broad-spectrum gas response                      |
| MQ3                  | Response to alcohol vapors and related compounds |
| MQ4                  | Response to methane and related gases            |
| VOC / gas resistance | Volatile organic compound indicator              |
| Temperature          | Ambient temperature                              |
| Humidity             | Relative humidity                                |

Temperature and humidity are not necessarily direct spoilage markers, but they are important because they influence metal-oxide sensor behavior. Therefore, they can be used as contextual or compensation features.

---

## 6. Data Acquisition

The acquisition layer records time-series data from all sensor channels. Each measurement run should include metadata that allows the dataset to be used correctly for training and evaluation.

### 6.1 Recommended Dataset Format

A recommended CSV structure is:

```text
Run_ID,Batch_ID,Product,True_Class,Timestamp,
MQ135,MQ3,MQ4,VOC,TEMP,HUM,
Base_MQ135,Base_MQ3,Base_MQ4,Base_VOC,Base_TEMP,Base_HUM
```

Example:

```text
R001,B01,banana,0,2026-07-08 12:00:01,512,430,391,10234,25.1,48.2,500,421,386,10012,24.9,48.0
R001,B01,banana,0,2026-07-08 12:00:02,516,434,393,10301,25.1,48.3,500,421,386,10012,24.9,48.0
```

### 6.2 Importance of `Run_ID`

`Run_ID` is essential for scientific evaluation. A run is one independent measurement sequence with its own sample placement, baseline, and measurement cycle.

The dataset must not be split randomly row by row, because adjacent time samples from the same run are highly correlated. A row-wise split would cause temporal leakage and produce overly optimistic classification metrics.

Incorrect approach:

```text
Randomly shuffle all rows → train/test split
```

Correct approach:

```text
Whole runs → training set
Whole runs → validation set
Whole runs → test set
```

This ensures that the final test set contains independent measurement runs that were not seen during training.

---

## 7. Target Classification Task

The FPGA accelerator is designed for a three-class output task. The planned experimental classification labels are:

| Class ID | Class Name | Meaning                            |
| -------: | ---------- | ---------------------------------- |
|        0 | Fresh      | Fresh sample                       |
|        1 | Warning    | Intermediate or early-change state |
|        2 | Spoiled    | Spoiled or strongly changed sample |

The current FPGA design supports three output neurons. Final classification metrics on real samples are planned for the next project stage.

---

## 8. Preprocessing Pipeline

After acquisition, the raw sensor values are processed before being used for training or inference.

The preprocessing pipeline includes:

1. invalid value filtering;
2. baseline correction;
3. optional normalization or scaling;
4. temporal difference computation;
5. spike encoding;
6. time-window generation.

### 8.1 Baseline Correction

For each sensor channel:

```text
d_MQ135 = MQ135 - Base_MQ135
d_MQ3   = MQ3   - Base_MQ3
d_MQ4   = MQ4   - Base_MQ4
d_VOC   = VOC   - Base_VOC
d_TEMP  = TEMP  - Base_TEMP
d_HUM   = HUM   - Base_HUM
```

This allows the model to focus on the sensor response relative to its initial state rather than on absolute values that may vary due to drift or environmental conditions.

### 8.2 Windowing

The SNN does not classify a single sensor row. It processes a temporal window.

For example, with a window length of 10 time steps:

```text
t0 → 12-bit spike mask
t1 → 12-bit spike mask
t2 → 12-bit spike mask
...
t9 → 12-bit spike mask
```

The full sequence is passed to the SNN accelerator. The network accumulates output spikes over the window and then produces a class decision.

---

## 9. Delta-Based Spike Encoding

Delta-based spike encoding converts continuous sensor signals into discrete events. Instead of passing dense numerical values directly to the model, the encoder detects whether the signal has changed significantly.

For each input channel (x_i[t]), two spike channels are generated:

* a positive spike channel;
* a negative spike channel.

A positive spike is generated when the signal increases above a threshold:

[
s_i^+[t] =
\begin{cases}
1, & x_i[t] - x_i[t-1] \geq \theta_i^+ \
0, & \text{otherwise}
\end{cases}
]

A negative spike is generated when the signal decreases above a threshold:

[
s_i^-[t] =
\begin{cases}
1, & x_i[t-1] - x_i[t] \geq \theta_i^- \
0, & \text{otherwise}
\end{cases}
]

For six input features, the encoder produces twelve spike channels:

| Original Channel | Positive Spike | Negative Spike |
| ---------------- | -------------- | -------------- |
| MQ135            | MQ135_UP       | MQ135_DOWN     |
| MQ3              | MQ3_UP         | MQ3_DOWN       |
| MQ4              | MQ4_UP         | MQ4_DOWN       |
| VOC              | VOC_UP         | VOC_DOWN       |
| TEMP             | TEMP_UP        | TEMP_DOWN      |
| HUM              | HUM_UP         | HUM_DOWN       |

At each time step, these binary values are packed into a 12-bit spike mask:

```text
bit[0]  = MQ135_UP
bit[1]  = MQ135_DOWN
bit[2]  = MQ3_UP
bit[3]  = MQ3_DOWN
bit[4]  = MQ4_UP
bit[5]  = MQ4_DOWN
bit[6]  = VOC_UP
bit[7]  = VOC_DOWN
bit[8]  = TEMP_UP
bit[9]  = TEMP_DOWN
bit[10] = HUM_UP
bit[11] = HUM_DOWN
```

This representation is hardware-friendly because it uses binary events, integer weights, counters, comparators, and fixed-point arithmetic.

---

## 10. Spiking Neural Network Training

The training stage is performed offline in software before deployment to FPGA. The FPGA accelerator is used for inference with pre-trained and quantized weights; it does not currently perform on-chip learning.

The training workflow is:

```text
Raw dataset
    ↓
Baseline correction
    ↓
Spike encoding
    ↓
Window generation
    ↓
Run-level train / validation / test split
    ↓
Software SNN training
    ↓
Validation and parameter selection
    ↓
Weight quantization
    ↓
Export to FPGA-compatible memory format
    ↓
Hardware inference
```

### 10.1 Training Input

The model input is not a raw analog sensor vector. It is a sequence of 12-channel spike masks.

For one sample:

```text
Input shape = [TIME_STEPS, 12]
```

Example for a 10-step window:

```text
[
  0b000000000001,
  0b000000000101,
  0b000000100000,
  ...
  0b100000000000
]
```

Each window has one target label:

```text
0 = Fresh
1 = Warning
2 = Spoiled
```

### 10.2 Software SNN Architecture

The software model follows the same logical topology as the FPGA implementation:

```text
12 input spike channels
        ↓
32 hidden LIF neurons
        ↓
3 output LIF neurons
        ↓
Output spike counts
        ↓
Argmax class decision
```

The hidden layer contains 32 leaky integrate-and-fire neurons. The output layer contains three neurons, one for each class.

### 10.3 LIF Neuron Model

A leaky integrate-and-fire neuron integrates incoming spikes over time. Its membrane potential increases due to synaptic input and decreases due to leakage.

A simplified update rule is:

[
V[t+1] = V[t] - leak(V[t]) + I[t]
]

where:

* (V[t]) is the membrane potential;
* (leak(V[t])) is the leakage term;
* (I[t]) is the synaptic input current.

A spike is generated when the membrane potential reaches a threshold:

[
z[t] =
\begin{cases}
1, & V[t] \geq T \
0, & V[t] < T
\end{cases}
]

where (T) is the neuron threshold.

### 10.4 Surrogate Gradient Training

The spike generation function is not differentiable because it is a threshold operation. This makes direct gradient-based learning difficult. For this reason, the software training stage can use surrogate gradient learning.

The idea is:

* during the forward pass, the model uses a real binary spike function;
* during the backward pass, the non-differentiable spike function is replaced by a smooth surrogate derivative;
* the weights can then be optimized using gradient-based methods.

This allows the SNN to be trained in a framework such as PyTorch and then exported to FPGA.

### 10.5 Output Decision and Loss

During training and inference, the output neurons accumulate spikes over the temporal window.

For three output classes:

```text
C0 = number of output spikes for class 0
C1 = number of output spikes for class 1
C2 = number of output spikes for class 2
```

The predicted class is:

[
\hat{y} = \arg\max_c C_c
]

During training, the output spike counts can be interpreted as class logits or decision scores and optimized using a classification loss such as cross-entropy.

### 10.6 Dataset Split

The dataset must be split at run level:

```text
Training set   → 70% of runs
Validation set → 15% of runs
Test set       → 15% of runs
```

The final test set should not be used for threshold selection, model tuning, quantization tuning, or architecture changes.

Correct sequence:

```text
1. Collect dataset
2. Split by Run_ID
3. Train on training set
4. Tune on validation set
5. Lock the model
6. Evaluate once on the test set
```

---

## 11. Weight Quantization

After training, the floating-point weights are converted into a low-precision integer representation suitable for FPGA deployment.

Conceptual quantization flow:

```text
Floating-point weights
    ↓
Scaling
    ↓
Clipping
    ↓
Signed 8-bit integer weights
    ↓
Export to FPGA memory initialization format
```

The two main weight matrices are:

```text
W1: 12 × 32
W2: 32 × 3
```

where:

* `W1` connects the 12 input spike channels to the 32 hidden neurons;
* `W2` connects the 32 hidden neurons to the 3 output neurons.

Using signed 8-bit weights reduces FPGA resource usage and avoids floating-point arithmetic.

---

## 12. FPGA SNN Accelerator

The FPGA accelerator implements the spiking neural network inference engine in programmable logic.

### 12.1 Topology

The implemented network topology is:

```text
12 input spike channels
        ↓
32 hidden LIF neurons
        ↓
3 output LIF neurons
```

### 12.2 Main Hardware Components

The accelerator includes:

* input spike-window buffer;
* first-layer weight memory;
* second-layer weight memory;
* hidden membrane-potential registers;
* output membrane-potential registers;
* leakage logic;
* threshold comparators;
* spike generation logic;
* output spike counters;
* class decision logic;
* confidence estimation;
* latency counter;
* AXI-Lite register interface.

### 12.3 Inference Flow

The hardware inference process is:

#### Step 1: Load Input Spike Window

The software sends a sequence of 12-bit spike masks to the accelerator.

Example:

```text
t0: 000000000001
t1: 000000000101
t2: 000000001000
...
t9: 100000000000
```

#### Step 2: Process Input Layer

For each time step, active input spikes select and accumulate the corresponding weights into the hidden neurons.

Conceptually:

```text
if input_spike[i] == 1:
    hidden_current[k] += W1[i][k]
```

Because the input is binary, the accelerator does not need general-purpose multiplication for each input event.

#### Step 3: Update Hidden LIF Neurons

Each hidden neuron updates its membrane potential:

```text
V_hidden = V_hidden - leak + input_current
```

If the membrane potential crosses the threshold:

```text
hidden_spike = 1
V_hidden = reset_value
```

#### Step 4: Process Output Layer

Hidden spikes activate the second weight matrix:

```text
if hidden_spike[k] == 1:
    output_current[c] += W2[k][c]
```

The output LIF neurons update their internal states and may generate output spikes.

#### Step 5: Count Output Spikes

The accelerator maintains one spike counter per output class:

```text
count0 → class 0
count1 → class 1
count2 → class 2
```

#### Step 6: Select Predicted Class

After the complete temporal window has been processed:

```text
predicted_class = argmax(count0, count1, count2)
```

#### Step 7: Read Back Results

The processor reads:

* predicted class;
* count0;
* count1;
* count2;
* confidence;
* latency in clock cycles;
* accelerator status.

---

## 13. Hardware–Software Interface

The system uses an AXI-based interface between the Zynq processing system and the programmable logic.

### 13.1 AXI-Lite Register Map

Example register map:

| Offset | Register     | Description                       |
| -----: | ------------ | --------------------------------- |
|   0x00 | CONTROL      | Start, reset, enable              |
|   0x04 | STATUS       | Idle, busy, done, error           |
|   0x08 | WINDOW_LEN   | Input window length               |
|   0x0C | INPUT_MASK   | Input spike mask                  |
|   0x10 | DIM_IN       | Number of input channels          |
|   0x14 | DIM_HIDDEN   | Number of hidden neurons          |
|   0x18 | RESULT_CLASS | Predicted class                   |
|   0x1C | COUNT0       | Spike count for class 0           |
|   0x20 | COUNT1       | Spike count for class 1           |
|   0x24 | COUNT2       | Spike count for class 2           |
|   0x28 | CONFIDENCE   | Confidence estimate               |
|   0x2C | LATENCY      | Inference latency in clock cycles |

### 13.2 Software Control Flow

The software-side execution flow is:

```text
1. Load the FPGA bitstream
2. Initialize the overlay
3. Prepare a spike window
4. Write input spike masks
5. Start the accelerator
6. Poll the done/status bit
7. Read output registers
8. Store results in an evaluation CSV file
```

---

## 14. FPGA Implementation

The current FPGA design targets:

| Parameter         | Value                                               |
| ----------------- | --------------------------------------------------- |
| Development board | PYNQ-Z2                                             |
| SoC               | Xilinx Zynq-7020                                    |
| FPGA device       | xc7z020clg400-1                                     |
| Toolchain         | Vivado 2025.2                                       |
| Nominal clock     | 100 MHz                                             |
| Main blocks       | `enose_preproc`, `enose_accel`, `xadc_wiz`, Zynq PS |

### 14.1 Main FPGA Blocks

#### `enose_preproc`

Hardware preprocessing block for sensor-channel preparation and spike-compatible data processing.

#### `enose_accel`

Main spiking neural network accelerator. It implements the fixed 12–32–3 topology, integer weights, LIF state registers, output counters, class decision logic, and latency counter.

#### `xadc_wiz`

XADC interface block for analog acquisition support.

#### Zynq Processing System

Used for control, communication, overlay management, software interaction, and experimental workflow coordination.

---

## 15. FPGA Implementation Results

The design was synthesized, implemented, and routed in Vivado 2025.2.

### 15.1 Overall Resource Utilization

| Resource        | Used | Available | Utilization |
| --------------- | ---: | --------: | ----------: |
| Slice LUTs      | 2633 |     53200 |       4.95% |
| LUT as Logic    | 2555 |     53200 |       4.80% |
| Slice Registers | 2563 |    106400 |       2.41% |
| Block RAM Tile  |    1 |       140 |       0.71% |
| RAMB18          |    2 |       280 |       0.71% |
| DSP Blocks      |    0 |       220 |       0.00% |
| BUFG            |    1 |        32 |       3.13% |
| XADC            |    1 |         1 |        100% |

The most important result is that the design uses **0 DSP blocks**. This indicates that the inference engine is implemented using low-precision integer logic rather than multiplier-heavy arithmetic.

### 15.2 Hierarchical Resource Utilization

| Module           |  LUT |   FF |       BRAM | DSP |
| ---------------- | ---: | ---: | ---------: | --: |
| Full design      | 2633 | 2563 | 2 × RAMB18 |   0 |
| `enose_accel`    | 1337 | 1056 | 2 × RAMB18 |   0 |
| `enose_preproc`  |  595 |  579 |          0 |   0 |
| AXI interconnect |  527 |  658 |          0 |   0 |
| XADC block       |  159 |  237 |          0 |   0 |

The SNN accelerator itself uses 1337 LUTs, 1056 flip-flops, and two RAMB18 blocks. This represents only a small fraction of the available Zynq-7020 resources.

---

## 16. Behavioral Simulation

The accelerator was verified using behavioral simulation.

| Test   | Input Pattern     | Output Class | Output Counts |     Latency | Status |
| ------ | ----------------- | -----------: | ------------- | ----------: | ------ |
| Test 1 | All zeros         |            0 | `[0, 0, 0]`   | 5172 cycles | Passed |
| Test 2 | All ones `0xFFF`  |            2 | `[0, 0, 10]`  | 5172 cycles | Passed |
| Test 3 | Ramp pattern      |            2 | `[0, 0, 10]`  | 5172 cycles | Passed |
| Test 4 | Register readback |      12–32–3 | —             |           — | Passed |

For a 10-step input window, the reported simulation latency is:

[
t = \frac{5172}{100 \times 10^6} = 51.72 \mu s
]

This inference time is significantly shorter than the typical response time of metal-oxide gas sensors, which is usually on the order of seconds.

---

## 17. Timing Analysis

Post-route timing analysis was performed at a 100 MHz clock constraint.

| Metric                  |     Value |
| ----------------------- | --------: |
| WNS                     | -0.044 ns |
| TNS                     | -0.083 ns |
| Setup failing endpoints |         3 |
| WHS                     |  0.041 ns |
| Hold failing endpoints  |         0 |
| Pulse-width slack       |  3.750 ns |

The design is very close to timing closure at 100 MHz, but it is not formally timing-clean because of a small setup violation.

The estimated maximum frequency is approximately:

[
f_{max} \approx \frac{1}{10.044 ns} \approx 99.56 MHz
]

This can likely be improved by adding pipeline registers in the critical path of the hidden-layer update logic.

---

## 18. Power Estimation

Vivado power analysis reports:

| Component            |   Value |
| -------------------- | ------: |
| Total on-chip power  | 1.413 W |
| Dynamic power        | 1.275 W |
| Static power         | 0.138 W |
| Junction temperature | 41.3 °C |
| Confidence level     |     Low |

The power estimate is preliminary because it was generated without post-implementation switching activity or board-level measurements. Future work should include activity-based power estimation and direct board-level power measurement.

---

## 19. Experimental Classification on Real Dataset

The current FPGA implementation demonstrates hardware feasibility. The next stage is full experimental validation on real food-sample data.

Planned metrics include:

* accuracy;
* precision;
* recall;
* macro-F1 score;
* weighted-F1 score;
* confusion matrix;
* software SNN vs FPGA SNN agreement;
* latency per inference;
* energy per inference.

### 19.1 Evaluation Workflow

```text
Test dataset
    ↓
Spike-window generation
    ↓
FPGA inference
    ↓
Read predicted class and output counts
    ↓
Save evaluation CSV
    ↓
Compute accuracy, F1-score, and confusion matrix
```

Example evaluation CSV format:

```text
Run_ID,Window_ID,True_Class,Pred_Class,Count0,Count1,Count2,Latency_Cycles
R001,0,0,0,10,0,0,5172
R001,1,0,0,9,1,0,5172
R021,0,1,1,0,8,2,5172
R041,0,2,2,0,1,9,5172
```

### 19.2 Methodological Note

The final test set must not be used for model tuning, spike-threshold selection, quantization adjustment, or architecture changes. It should be used only once for final evaluation.

---

## 20. Current Project Status

```text
Measurement chamber: developed as part of the system
Sensor data acquisition: in development
Preprocessing pipeline: defined
Spike encoding: defined and FPGA-compatible
Software SNN training: part of the workflow
Weight quantization: part of the deployment flow
FPGA SNN accelerator: implemented
Hardware preprocessing: implemented
Vivado synthesis: completed
Vivado implementation: completed
Behavioral simulation: completed
Timing closure: near 100 MHz, minor WNS violation
Real dataset classification metrics: in progress
```

---

## 21. What This Project Currently Demonstrates

The current project demonstrates:

* a complete hardware concept for a neuromorphic electronic-nose system;
* a measurement chamber concept for repeatable headspace data acquisition;
* a sensor-to-spike processing pipeline;
* an FPGA-compatible SNN architecture;
* a low-resource 12–32–3 SNN accelerator;
* synthesis and implementation on Zynq-7020;
* deterministic simulated inference latency;
* near-100 MHz timing behavior;
* low FPGA resource utilization;
* DSP-free inference architecture.

---

## 22. What This Project Does Not Yet Claim

For scientific correctness, the current version does not yet claim:

* final classification accuracy on real food samples;
* macro-F1 score on an independent test set;
* confusion matrix from real sample measurements;
* comparison against software baselines on a complete dataset;
* board-measured power consumption;
* fully closed timing at exactly 100 MHz.

These results are planned for the next experimental stage.

---

## 23. Future Work

Planned next steps include:

* collecting a real dataset with independent measurement runs;
* experimental Fresh / Warning / Spoiled classification;
* computing accuracy, precision, recall, macro-F1, and confusion matrix;
* comparing software SNN and FPGA SNN outputs;
* comparing against baseline models such as SVM, Random Forest, and MLP;
* improving timing closure at 100 MHz;
* measuring board-level power consumption;
* adding sensor drift compensation;
* adding temperature and humidity compensation;
* implementing adaptive spike thresholds;
* increasing the number of sensor channels;
* evaluating larger SNN topologies;
* investigating semi-online or on-chip learning.

---

## 24. Scientific Relevance

This project demonstrates a practical approach for combining electronic-nose sensing, event-based encoding, and FPGA-based neuromorphic inference. The central idea is that gas-sensor time-series data can be represented as event streams rather than dense numerical vectors.

This enables the use of spiking neural networks, which are naturally suited for temporal event processing. The FPGA implementation shows that such a model can be mapped to a low-cost embedded platform with low resource usage and no DSP utilization.

The project is relevant to:

* intelligent sensing systems;
* edge AI;
* embedded classification;
* neuromorphic engineering;
* FPGA accelerators;
* electronic noses;
* food-quality monitoring;
* low-latency sensor processing.

---

## 25. Conclusion

This repository presents an integrated approach to building a neuromorphic electronic-nose system on FPGA. The system includes a measurement chamber, sensor acquisition pipeline, spike encoding, software SNN training workflow, weight quantization, and FPGA-based spiking inference.

The current results demonstrate the hardware feasibility of the approach through synthesis, implementation, behavioral simulation, timing analysis, power estimation, and FPGA resource analysis. The architecture uses a small fraction of the Zynq-7020 resources and does not require DSP blocks, making it suitable for embedded edge-AI applications.

The next key milestone is real-sample experimental classification, which will provide full evaluation of the practical effectiveness of the system.

# Neuromorphic e-Nose on FPGA

## Невроморфна електронна обонятелна система върху FPGA за анализ на сензорни данни и оценка на качеството на хранителни продукти

---

## 1. Общо описание

Този проект представя невроморфна електронна обонятелна система, реализирана върху FPGA, предназначена за обработка и анализ на данни от газови сензори при оценка на състоянието на хранителни продукти. Системата комбинира специализирана измервателна камера, масив от газови и околни сензори, софтуерен pipeline за събиране и подготовка на данни, спайково кодиране на сензорните сигнали, обучение на спайкова невронна мрежа и FPGA-базирана хардуерна инференция.

Основната идея на проекта е динамичният отговор на газовите сензори към летливите органични съединения, отделяни от хранителни проби, да бъде преобразуван в събитийно представяне, подходящо за обработка от спайкова невронна мрежа. Вместо да се използва класически софтуерен класификатор, инференцията се реализира като хардуерен ускорител в програмируемата логика на Xilinx Zynq-7020 SoC.

Проектът е разработен като изследователска платформа за:

* електронни обонятелни системи;
* FPGA-базирана обработка на сензорни данни;
* невроморфно инженерство;
* спайкови невронни мрежи;
* embedded AI;
* edge inference;
* хардуерно-софтуерно съвместно проектиране.

---

## 2. Мотивация

Оценката на качеството на хранителни продукти е важна задача в областта на безопасността на храните, логистиката, съхранението и интелигентното пакетиране. Традиционните лабораторни методи често изискват специализирано оборудване, консумативи, обучен персонал и значително време за анализ. Поради това съществува интерес към компактни, недеструктивни и нискобюджетни системи, които могат да извършват предварителна оценка на състоянието на продукта в реално време или близо до реално време.

Електронният нос използва масив от частично селективни газови сензори. Всеки сензор реагира на определен клас химични съединения, но обикновено не е напълно селективен. Вместо да се идентифицира едно конкретно вещество, системата анализира цялостния сензорен отпечатък, формиран от реакциите на различните сензори.

При хранителни продукти летливите органични съединения могат да се изменят в резултат на:

* ферментация;
* микробиологична активност;
* окисление;
* разграждане на белтъчини;
* промяна в pH;
* стареене или разваляне;
* промяна в температурата и влажността на средата.

Метал-оксидните газови сензори са подходящи за нискобюджетни експериментални системи, но имат редица предизвикателства:

* бавна реакция и възстановяване;
* дрейф във времето;
* зависимост от температура и влажност;
* крос-чувствителност към различни газове;
* нелинейни характеристики;
* необходимост от стабилен baseline;
* значителни преходни процеси след поставяне на пробата.

Поради тези особености настоящият проект използва не само абсолютните стойности на сензорите, а и динамиката на тяхната промяна. Това мотивира използването на delta-базирано спайково кодиране и спайкова невронна мрежа.

---

## 3. Основна концепция

Системата работи по следния общ принцип:

```text
Хранителна проба
      ↓
Отделяне на летливи органични съединения в измервателната камера
      ↓
Реакция на газовите и околните сензори
      ↓
Събиране на времеви сензорни редове
      ↓
Baseline correction и нормализация
      ↓
Delta-базирано spike encoding
      ↓
Обучение на software SNN модел
      ↓
Quantization на теглата
      ↓
Експорт към FPGA
      ↓
Хардуерна SNN инференция
      ↓
Изходен клас и spike-count резултати
```

Този подход разделя системата на три основни слоя:

1. **Физически измервателен слой**
   Камера, проба, газови сензори, околни сензори, въздушен поток и протокол за измерване.

2. **Софтуерен слой за данни и обучение**
   Събиране на измервания, preprocessing, spike encoding, създаване на dataset, обучение на SNN и export на тегла.

3. **FPGA слой за хардуерна инференция**
   Хардуерен preprocessor, SNN accelerator, AXI интерфейс, регистри, output counters и latency measurement.

---

## 4. Измервателна камера за събиране на данни

Важна част от проекта е специализираната измервателна камера, предназначена за контролирано събиране на газови проби от хранителни продукти. Камерата служи за формиране на сравнително стабилна headspace среда около пробата, така че сензорите да могат да регистрират характерния газов профил.

### 4.1 Роля на камерата

Камерата изпълнява няколко функции:

* изолира пробата от външната среда;
* позволява натрупване на летливи съединения над пробата;
* намалява влиянието на външни въздушни потоци;
* осигурява повторяемост между измерванията;
* позволява контролирано проветряване между експериментите;
* поддържа постоянна геометрия между пробата и сензорите;
* позволява използване на вентилатор за хомогенизиране на газовата смес.

При газови сензори геометрията на измервателната постановка е критична. Разстоянието между пробата и сензорите, обемът на камерата, скоростта на въздушния поток и времето за стабилизиране влияят директно върху формата на сензорния отговор.

### 4.2 Принцип на headspace измерване

Проектът използва принцип, близък до headspace анализ. Хранителната проба се поставя в затворен обем, където летливите органични съединения се натрупват в газовата фаза над пробата. Сензорите не влизат в директен контакт с продукта, а измерват газовата среда около него.

Това има няколко предимства:

* измерването е недеструктивно;
* сензорите не се замърсяват директно от пробата;
* може да се анализира времевата динамика на отделяне на летливи съединения;
* подходът е приложим към различни типове продукти.

### 4.3 Основни компоненти на камерата

Типичната постановка включва:

| Компонент                          | Роля                                                |
| ---------------------------------- | --------------------------------------------------- |
| Затворен обем / камера             | Изолира пробата и сензорите от външната среда       |
| Държач за проба                    | Осигурява повторяема позиция на хранителния продукт |
| Газови сензори                     | Измерват реакцията към летливи съединения           |
| Температурен и влажностен сензор   | Регистрира околните условия                         |
| Малък вентилатор                   | Хомогенизира газовата смес в камерата               |
| Вентилационен отвор / капак        | Позволява purge между експериментите                |
| Микроконтролер / acquisition модул | Събира суровите сензорни данни                      |
| FPGA/PYNQ-Z2 платформа             | Изпълнява хардуерната инференция                    |

### 4.4 Препоръчителен протокол за измерване

За да бъдат данните научно използваеми, всяко измерване трябва да следва еднакъв протокол.

Примерен експериментален цикъл:

```text
1. Проветряване на камерата
2. Измерване на baseline без проба
3. Поставяне на пробата
4. Кратко време за стабилизиране
5. Запис на сензорните данни
6. Премахване на пробата
7. Purge / проветряване преди следващия run
```

Примерни времена:

| Етап                  | Примерна продължителност |
| --------------------- | -----------------------: |
| Purge преди измерване |                    180 s |
| Baseline measurement  |                     30 s |
| Sample stabilization  |                     60 s |
| Active recording      |                120–300 s |
| Sampling rate         |                     1 Hz |
| Purge след измерване  |                    180 s |

### 4.5 Значение на baseline

Преди всяко измерване се записва baseline. Това е началното състояние на сензорите преди поставяне на пробата или преди активния измервателен прозорец. Baseline стойностите са важни, защото газовите сензори често имат дрейф и различно начално състояние при различни експерименти.

Вместо да се използват директно суровите стойности, системата може да използва отклонението от baseline:

```text
corrected_value = current_sensor_value - baseline_sensor_value
```

Това намалява влиянието на бавния дрейф и позволява по-сравними измервания между различни runs.

---

## 5. Сензорен слой

Системата е проектирана за работа с шест основни входни величини. Типичната конфигурация включва метал-оксидни газови сензори и сензор за температура, влажност и газово съпротивление.

Примерни входни канали:

| Канал                | Значение                                              |
| -------------------- | ----------------------------------------------------- |
| MQ135                | широкоспектърен газов отговор                         |
| MQ3                  | чувствителност към алкохолни пари и сродни съединения |
| MQ4                  | чувствителност към метан и сродни газове              |
| VOC / Gas resistance | индикатор за летливи органични съединения             |
| Temperature          | температура на средата                                |
| Humidity             | относителна влажност                                  |

Температурата и влажността не са директни маркери за разваляне, но са важни, защото влияят върху реакцията на метал-оксидните сензори. Затова те могат да се използват като компенсационни или контекстни входни признаци.

---

## 6. Събиране на данни

Софтуерният acquisition слой записва времеви редове от сензорните канали. Всеки запис трябва да бъде свързан с метаданни, за да може по-късно да се направи коректно обучение и оценка.

### 6.1 Примерна структура на dataset

Препоръчителен CSV формат:

```text
Run_ID,Batch_ID,Product,True_Class,Timestamp,
MQ135,MQ3,MQ4,VOC,TEMP,HUM,
Base_MQ135,Base_MQ3,Base_MQ4,Base_VOC,Base_TEMP,Base_HUM
```

Пример:

```text
R001,B01,banana,0,2026-07-08 12:00:01,512,430,391,10234,25.1,48.2,500,421,386,10012,24.9,48.0
R001,B01,banana,0,2026-07-08 12:00:02,516,434,393,10301,25.1,48.3,500,421,386,10012,24.9,48.0
```

### 6.2 Значение на `Run_ID`

`Run_ID` е критично поле. Един run представлява едно независимо измерване на една проба при конкретно поставяне, конкретен baseline и конкретен експериментален цикъл.

При оценка на модела dataset-ът не трябва да се разделя ред по ред, защото съседни секунди от един и същ run са силно корелирани. Правилният подход е разделяне по `Run_ID` или `Batch_ID`.

Неправилен подход:

```text
Случайно разбъркване на всички редове → train/test split
```

Правилен подход:

```text
Цели runs → train
Цели runs → validation
Цели runs → test
```

Това предотвратява temporal leakage и дава по-реалистична оценка на класификационната способност.

### 6.3 Планирани класове

За бъдещата експериментална класификация системата е проектирана за три класа:

| Class ID | Class name | Описание                            |
| -------: | ---------- | ----------------------------------- |
|        0 | Fresh      | прясна проба                        |
|        1 | Warning    | междинно състояние                  |
|        2 | Spoiled    | развалена или силно променена проба |

Текущият FPGA дизайн вече поддържа три изходни класа, но финалната класификационна оценка върху реален dataset предстои.

---

## 7. Предварителна обработка на данните

След събиране на суровите сензорни стойности се изпълнява preprocessing pipeline.

Основните стъпки са:

1. премахване на невалидни стойности;
2. baseline correction;
3. нормализация или мащабиране;
4. изчисляване на разлики във времето;
5. spike encoding;
6. разделяне на данните на времеви прозорци.

### 7.1 Baseline correction

За всеки сензорен канал се изчислява отклонение от baseline:

```text
d_MQ135 = MQ135 - Base_MQ135
d_MQ3   = MQ3   - Base_MQ3
d_MQ4   = MQ4   - Base_MQ4
d_VOC   = VOC   - Base_VOC
d_TEMP  = TEMP  - Base_TEMP
d_HUM   = HUM   - Base_HUM
```

Това позволява моделът да се фокусира върху промяната на сензора спрямо началното му състояние, а не върху абсолютна стойност, която може да зависи от дрейф, температура или конкретен ден на измерване.

### 7.2 Windowing

Спайковата невронна мрежа не обработва единичен ред от dataset-а, а времеви прозорец. Например при window length от 10 времеви стъпки входът към FPGA ускорителя представлява последователност от 10 спайкови маски.

Пример:

```text
t0  → 12-bit spike mask
t1  → 12-bit spike mask
t2  → 12-bit spike mask
...
t9  → 12-bit spike mask
```

Този прозорец се подава към SNN ускорителя, който натрупва изходни спайкове и връща предсказан клас.

---

## 8. Delta-базирано спайково кодиране

Delta spike encoding преобразува непрекъснатите сензорни сигнали в дискретни събития. Вместо всяка стойност да се подава директно към модела, се следи дали сигналът се е променил достатъчно спрямо предходната стойност или спрямо baseline.

За всеки сензорен канал (x_i[t]) се формират два спайкови канала:

* положителен спайк при значимо нарастване;
* отрицателен спайк при значимо намаляване.

Положителният спайк се дефинира като:

[
s_i^+[t] =
\begin{cases}
1, & x_i[t] - x_i[t-1] \geq \theta_i^+ \
0, & \text{otherwise}
\end{cases}
]

Отрицателният спайк се дефинира като:

[
s_i^-[t] =
\begin{cases}
1, & x_i[t-1] - x_i[t] \geq \theta_i^- \
0, & \text{otherwise}
\end{cases}
]

За шест сензорни канала се получават дванадесет спайкови канала:

| Оригинален канал | Positive spike | Negative spike |
| ---------------- | -------------- | -------------- |
| MQ135            | MQ135_UP       | MQ135_DOWN     |
| MQ3              | MQ3_UP         | MQ3_DOWN       |
| MQ4              | MQ4_UP         | MQ4_DOWN       |
| VOC              | VOC_UP         | VOC_DOWN       |
| TEMP             | TEMP_UP        | TEMP_DOWN      |
| HUM              | HUM_UP         | HUM_DOWN       |

Във всеки момент тези 12 бинарни стойности се пакетират в 12-битова маска:

```text
bit[0]  = MQ135_UP
bit[1]  = MQ135_DOWN
bit[2]  = MQ3_UP
bit[3]  = MQ3_DOWN
...
bit[10] = HUM_UP
bit[11] = HUM_DOWN
```

Това представяне е подходящо за FPGA, защото използва битови операции, броячи, сравнения и фиксирана точност.

---

## 9. Обучение на спайковата невронна мрежа

Обучението се изпълнява като софтуерен етап преди FPGA имплементацията. FPGA ускорителят не обучава модела на текущия етап; той изпълнява инференция с вече обучени и квантизирани тегла.

Общият training pipeline е:

```text
Raw dataset
      ↓
Baseline correction
      ↓
Spike encoding
      ↓
Window generation
      ↓
Train / validation / test split по Run_ID
      ↓
Software SNN training
      ↓
Validation и избор на параметри
      ↓
Quantization на теглата
      ↓
Export към FPGA memory format
      ↓
Hardware inference
```

### 9.1 Вход към обучението

Входът към SNN модела не е сурова аналогова стойност, а последователност от 12-битови спайкови маски.

За един sample:

```text
Input shape = [TIME_STEPS, 12]
```

Пример при `TIME_STEPS = 10`:

```text
[
  0b000000000001,
  0b000000000101,
  0b000000100000,
  ...
  0b100000000000
]
```

Всеки такъв прозорец има един label:

```text
0 = Fresh
1 = Warning
2 = Spoiled
```

### 9.2 Архитектура на software SNN модела

Моделът следва същата логическа структура като FPGA ускорителя:

```text
12 input spike channels
        ↓
32 hidden LIF neurons
        ↓
3 output LIF neurons
        ↓
output spike counts
        ↓
argmax decision
```

Скритият слой съдържа 32 LIF неврона. Изходният слой съдържа 3 неврона — по един за всеки клас.

### 9.3 LIF невронен модел

LIF невронът интегрира входните спайкове във времето. Мембранният потенциал се увеличава при входен ток и намалява чрез теч. При достигане на праг невронът генерира спайк.

Обобщената динамика е:

[
V[t+1] = V[t] - leak(V[t]) + I[t]
]

където:

* (V[t]) е мембранният потенциал;
* (leak(V[t])) е течът;
* (I[t]) е входният синаптичен ток.

Генерирането на спайк може да се запише като:

[
z[t] =
\begin{cases}
1, & V[t] \geq T \
0, & V[t] < T
\end{cases}
]

където (T) е прагът на неврона.

### 9.4 Проблемът с обучението на SNN

Спайковата функция е недиференцируема, защото представлява прагова функция. Това затруднява директното обучение чрез класически backpropagation. Затова при софтуерното обучение може да се използва surrogate gradient подход.

Идеята е следната:

* във forward pass се използва реална прагова spike функция;
* в backward pass недиференцируемата функция се заменя с приближена диференцируема функция;
* така теглата могат да се оптимизират чрез gradient-based метод.

Този подход позволява обучение на SNN модел в PyTorch или сходна среда, след което теглата се експортират към FPGA.

### 9.5 Loss функция и изходно решение

Изходните неврони акумулират спайкове за целия времеви прозорец. За всеки клас се получава spike count:

```text
C0 = брой изходни спайкове за клас 0
C1 = брой изходни спайкове за клас 1
C2 = брой изходни спайкове за клас 2
```

Предсказаният клас е:

[
\hat{y} = \arg\max_c C_c
]

По време на обучение spike counts могат да се използват като logits или като основа за loss функция, например cross-entropy loss спрямо истинския клас.

### 9.6 Разделяне на dataset-а

За да бъде оценката научно коректна, разделянето трябва да се извършва по `Run_ID`, а не ред по ред.

Пример:

```text
Train set      → 70% от runs
Validation set → 15% от runs
Test set       → 15% от runs
```

Това гарантира, че прозорци от един и същ експериментален run няма да попаднат едновременно в train и test.

### 9.7 Quantization

След обучението теглата се преобразуват от floating-point към нископрецизно целочислено представяне, подходящо за FPGA.

Пример:

```text
floating-point weights
      ↓
scaling
      ↓
clipping
      ↓
signed 8-bit integer weights
      ↓
export to memory initialization file
```

Квантизацията намалява използването на ресурси и позволява инференция без операции с плаваща запетая.

### 9.8 Export към FPGA

Квантизираните тегла се експортират във формат, подходящ за зареждане в блокова памет или memory initialization файлове.

Концептуално:

```text
W1: 12 × 32 тегла
W2: 32 × 3 тегла
```

Където:

* `W1` свързва входните спайкови канали със скрития слой;
* `W2` свързва скрития слой с изходните класове.

След export тези тегла се използват от FPGA SNN ускорителя.

---

## 10. FPGA SNN ускорител

FPGA ускорителят реализира инференцията на спайковата невронна мрежа в програмируемата логика на Zynq-7020.

### 10.1 Топология

Реализираната топология е:

```text
12 входни спайкови канала
        ↓
32 LIF неврона
        ↓
3 изходни LIF неврона
```

### 10.2 Основни хардуерни компоненти

SNN ускорителят включва:

* входен буфер за spike window;
* памет за теглата между входния и скрития слой;
* памет за теглата между скрития и изходния слой;
* регистри за мембранните потенциали на скрития слой;
* регистри за мембранните потенциали на изходния слой;
* прагови компаратори;
* spike generation логика;
* output spike counters;
* class decision логика;
* latency counter;
* AXI-Lite register interface.

### 10.3 Работа на ускорителя

Работата на ускорителя може да бъде описана в няколко стъпки.

#### Стъпка 1: Зареждане на входен прозорец

Софтуерът подава последователност от 12-битови spike masks към FPGA блока. Всеки spike mask представя един времеви момент от измерването.

Пример:

```text
t0: 000000000001
t1: 000000000101
t2: 000000001000
...
t9: 100000000000
```

#### Стъпка 2: Обработка на входния слой

За всеки timestep активните входни спайкове избират съответните тегла към скрития слой. Вместо да се извършват пълни умножения, при бинарен вход се акумулират само теглата на активните входни канали.

Концептуално:

```text
if input_spike[i] == 1:
    hidden_current[k] += W1[i][k]
```

Това е много подходящо за FPGA, защото входът е бинарен, а теглата са целочислени.

#### Стъпка 3: Обновяване на скритите LIF неврони

За всеки скрит неврон се обновява мембранният потенциал:

```text
V_hidden = V_hidden - leak + input_current
```

Ако потенциалът надвиши прага:

```text
hidden_spike = 1
V_hidden = reset_value
```

#### Стъпка 4: Обработка на изходния слой

Скритите спайкове активират теглата към трите изходни неврона:

```text
if hidden_spike[k] == 1:
    output_current[c] += W2[k][c]
```

След това се обновяват мембранните потенциали на изходните неврони.

#### Стъпка 5: Броене на изходните спайкове

За всеки клас се поддържа брояч:

```text
count0 → клас 0
count1 → клас 1
count2 → клас 2
```

При генериране на изходен спайк съответният брояч се увеличава.

#### Стъпка 6: Избор на клас

След обработване на целия прозорец се избира класът с най-голям spike count:

```text
predicted_class = argmax(count0, count1, count2)
```

#### Стъпка 7: Readback към софтуера

Софтуерът прочита от AXI регистрите:

* predicted class;
* count0;
* count1;
* count2;
* confidence;
* latency cycles;
* status.

---

## 11. Хардуерно-софтуерен интерфейс

Комуникацията между процесорната система и FPGA логиката се реализира чрез AXI интерфейс.

### 11.1 AXI-Lite регистри

AXI-Lite интерфейсът се използва за контрол и статус.

Примерна регистрова карта:

| Offset | Register     | Описание                    |
| -----: | ------------ | --------------------------- |
|   0x00 | CONTROL      | start, reset, enable        |
|   0x04 | STATUS       | idle, busy, done, error     |
|   0x08 | WINDOW_LEN   | дължина на входния прозорец |
|   0x0C | INPUT_MASK   | входен spike mask           |
|   0x10 | DIM_IN       | брой входни канали          |
|   0x14 | DIM_HIDDEN   | брой скрити неврони         |
|   0x18 | RESULT_CLASS | предсказан клас             |
|   0x1C | COUNT0       | spike count за клас 0       |
|   0x20 | COUNT1       | spike count за клас 1       |
|   0x24 | COUNT2       | spike count за клас 2       |
|   0x28 | CONFIDENCE   | оценка на увереността       |
|   0x2C | LATENCY      | брой тактове за инференция  |

### 11.2 Софтуерен контрол

От страна на процесорната система workflow-ът е:

```text
1. Зареждане на bitstream
2. Инициализация на overlay
3. Подготовка на spike window
4. Запис на входни masks
5. Стартиране на ускорителя
6. Polling на done bit
7. Прочитане на резултатите
8. Запис на резултата в evaluation CSV
```

---

## 12. FPGA реализация

Проектът е реализиран върху:

| Параметър         | Стойност                                            |
| ----------------- | --------------------------------------------------- |
| Development board | PYNQ-Z2                                             |
| SoC               | Xilinx Zynq-7020                                    |
| Device            | xc7z020clg400-1                                     |
| Toolchain         | Vivado 2025.2                                       |
| Clock             | 100 MHz nominal                                     |
| Основни модули    | `enose_preproc`, `enose_accel`, `xadc_wiz`, Zynq PS |

### 12.1 Основни FPGA блокове

#### `enose_preproc`

Хардуерен блок за предварителна обработка на входните сензорни канали. Той служи като междинен слой между acquisition частта и SNN ускорителя.

#### `enose_accel`

Основният SNN ускорител. Той реализира фиксирана 12–32–3 спайкова невронна мрежа с целочислени тегла, LIF състояния, output counters и class decision logic.

#### `xadc_wiz`

XADC блок за аналогово-цифрово преобразуване и връзка с аналогови сензорни канали.

#### Zynq Processing System

Използва се за софтуерен контрол, комуникация, зареждане на overlay и управление на експериментите.

---

## 13. Резултати от FPGA имплементацията

Дизайнът е синтезиран, имплементиран и рутиран във Vivado 2025.2.

### 13.1 Общо използване на ресурси

| Ресурс          | Използвани | Налични | Използване |
| --------------- | ---------: | ------: | ---------: |
| Slice LUTs      |       2633 |   53200 |      4.95% |
| LUT as Logic    |       2555 |   53200 |      4.80% |
| Slice Registers |       2563 |  106400 |      2.41% |
| Block RAM Tile  |          1 |     140 |      0.71% |
| RAMB18          |          2 |     280 |      0.71% |
| DSP Blocks      |          0 |     220 |      0.00% |
| BUFG            |          1 |      32 |      3.13% |
| XADC            |          1 |       1 |       100% |

### 13.2 Йерархично използване на ресурси

| Модул            |  LUT |   FF |       BRAM | DSP |
| ---------------- | ---: | ---: | ---------: | --: |
| Пълен дизайн     | 2633 | 2563 | 2 × RAMB18 |   0 |
| `enose_accel`    | 1337 | 1056 | 2 × RAMB18 |   0 |
| `enose_preproc`  |  595 |  579 |          0 |   0 |
| AXI interconnect |  527 |  658 |          0 |   0 |
| XADC block       |  159 |  237 |          0 |   0 |

Основният резултат е, че SNN ускорителят използва малко ресурси и не използва DSP блокове. Това показва, че архитектурата е подходяща за нискоресурсни embedded FPGA системи.

---

## 14. Поведенческа симулация

Функционалността е проверена чрез поведенческа симулация.

| Тест   | Входен шаблон          | Изходен клас | Изходни броячи | Латентност | Статус |
| ------ | ---------------------- | -----------: | -------------- | ---------: | ------ |
| Test 1 | Всички нули            |            0 | `[0, 0, 0]`    | 5172 такта | Passed |
| Test 2 | Всички единици `0xFFF` |            2 | `[0, 0, 10]`   | 5172 такта | Passed |
| Test 3 | Ramp pattern           |            2 | `[0, 0, 10]`   | 5172 такта | Passed |
| Test 4 | Register readback      |      12–32–3 | —              |          — | Passed |

При 100 MHz латентността е:

[
t = \frac{5172}{100 \times 10^6} = 51.72 \mu s
]

Това показва, че инференцията е много по-бърза от динамиката на газовите сензори.

---

## 15. Timing анализ

Post-route timing анализът показва:

| Показател               |  Стойност |
| ----------------------- | --------: |
| WNS                     | -0.044 ns |
| TNS                     | -0.083 ns |
| Setup failing endpoints |         3 |
| WHS                     |  0.041 ns |
| Hold failing endpoints  |         0 |
| Pulse-width slack       |  3.750 ns |

Дизайнът е много близо до timing closure при 100 MHz, но формално има минимално setup нарушение. Оценената максимална честота е приблизително:

[
f_{max} \approx 99.56 MHz
]

Това може да бъде подобрено чрез малка pipeline оптимизация в критичния път на SNN ускорителя.

---

## 16. Оценка на мощността

Vivado power analysis отчита:

| Компонент            | Стойност |
| -------------------- | -------: |
| Total on-chip power  |  1.413 W |
| Dynamic power        |  1.275 W |
| Static power         |  0.138 W |
| Junction temperature |  41.3 °C |
| Confidence level     |      Low |

Тези стойности са предварителни, защото са генерирани без реален switching activity файл. За финална публикационна оценка е необходимо board-level измерване или post-implementation activity-based power estimation.

---

## 17. Експериментална класификация върху реален dataset

Текущата FPGA реализация доказва хардуерната реализуемост на системата. Следващият етап е експериментална оценка върху реален dataset.

Планирани метрики:

* accuracy;
* precision;
* recall;
* macro-F1;
* weighted-F1;
* confusion matrix;
* software SNN vs FPGA SNN agreement;
* latency per inference;
* energy per inference.

### 17.1 Evaluation workflow

```text
Test dataset
      ↓
Spike window generation
      ↓
FPGA inference
      ↓
Read predicted class and output counts
      ↓
Save evaluation CSV
      ↓
Compute accuracy, F1-score and confusion matrix
```

Примерен evaluation CSV:

```text
Run_ID,Window_ID,True_Class,Pred_Class,Count0,Count1,Count2,Latency_Cycles
R001,0,0,0,10,0,0,5172
R001,1,0,0,9,1,0,5172
R021,0,1,1,0,8,2,5172
R041,0,2,2,0,1,9,5172
```

### 17.2 Важно методологично ограничение

Финалният test set не трябва да се използва за настройка на прагове, параметри, тегла или архитектура. Той трябва да се използва само веднъж за финална оценка.

Правилна последователност:

```text
1. Събиране на dataset
2. Разделяне по Run_ID
3. Обучение върху train set
4. Настройка върху validation set
5. Заключване на модела
6. Финална оценка върху test set
```

---

## 18. Какво е реализирано до момента

Към текущия етап проектът включва:

```text
Измервателна концепция и камера: разработена като част от системата
Сензорен acquisition pipeline: разработван
Baseline correction: предвидена в pipeline-а
Delta spike encoding: реализирана концептуално и съвместима с FPGA входа
Software SNN training: част от pipeline-а
Weight quantization: част от deployment workflow-а
FPGA SNN accelerator: реализиран
Hardware preprocessing block: реализиран
Vivado synthesis: завършен
Vivado implementation: завършен
Behavioral simulation: завършена
FPGA resource reports: налични
Timing report: наличен
Power estimate: наличен
Real dataset classification metrics: предстоящи
```

---

## 19. Какво проектът все още не твърди

За научна коректност текущият проект не твърди финална класификационна точност върху реален dataset.

Все още предстои:

* реална accuracy стойност;
* macro-F1 върху независим test set;
* confusion matrix;
* сравнение със software baseline;
* board-level power measurement;
* пълно timing closure при 100 MHz;
* batch-wise validation върху независими проби.

Тези резултати са планирани като следващ етап.

---

## 20. Научна значимост

Проектът демонстрира практически подход за комбиниране на електронен нос, невроморфно кодиране и FPGA-базирана инференция. Основната научна идея е, че газовите сензорни сигнали могат да бъдат представени като събитийни времеви последователности, а не само като плътни числови вектори.

Това позволява използването на спайкови невронни мрежи, които са естествено подходящи за обработка на времеви събития. FPGA реализацията показва, че подобен модел може да бъде имплементиран с ниско използване на ресурси и без DSP блокове.

Проектът е релевантен за:

* интелигентни сензорни системи;
* edge AI;
* embedded classification;
* невроморфно инженерство;
* FPGA ускорители;
* електронни носове;
* мониторинг на хранителни продукти.

## 21. Статус на проекта

```text
Measurement chamber: developed as part of the system
Sensor data acquisition: in development
Preprocessing pipeline: defined
Spike encoding: defined and FPGA-compatible
Software SNN training: part of the workflow
Weight quantization: part of the deployment flow
FPGA SNN accelerator: implemented
Hardware preprocessing: implemented
Vivado synthesis: completed
Vivado implementation: completed
Behavioral simulation: completed
Timing closure: near 100 MHz, minor WNS violation
Real dataset classification metrics: in progress
```

---

## 22. Бъдещо развитие

Планирани следващи стъпки:

* събиране на реален dataset с независими runs;
* експериментална класификация на Fresh / Warning / Spoiled проби;
* изчисляване на accuracy, precision, recall, macro-F1 и confusion matrix;
* comparison между software SNN и FPGA SNN;
* comparison със стандартни baseline модели като SVM, Random Forest и MLP;
* оптимизация на timing за пълно 100 MHz closure;
* board-level power measurement;
* drift compensation;
* температурна и влажностна компенсация;
* адаптивни spike thresholds;
* разширяване на броя сензорни канали;
* изследване на по-големи SNN архитектури;
* възможност за on-chip или semi-online learning.

---

## 23. Заключение

Този проект представя интегриран подход за изграждане на невроморфна електронна обонятелна система върху FPGA. Системата включва измервателна камера, сензорен acquisition pipeline, spike encoding, software обучение на SNN модел и хардуерна инференция чрез FPGA ускорител.

Текущите резултати доказват хардуерната реализуемост на подхода чрез синтез, имплементация, поведенческа симулация и анализ на FPGA ресурсите. Архитектурата използва малка част от ресурсите на Zynq-7020 и не използва DSP блокове, което я прави подходяща за embedded edge AI приложения.

Следващата ключова стъпка е експериментална класификация върху реални хранителни проби, която ще позволи пълна оценка на практическата ефективност на системата.

