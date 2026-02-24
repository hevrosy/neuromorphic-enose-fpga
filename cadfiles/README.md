# Advanced E-Nose Fluidic Chamber (v1.0.0)

A 100% support-free, 3D-printable fluidic chamber designed specifically for Electronic Nose (E-Nose) applications and Volatile Organic Compound (VOC) analysis. 

This project solves the most common issues found in DIY and academic electronic noses: poor gas mixing, lack of airtightness, aerodynamic stalling, and direct cold drafts disrupting the heated MQ-series gas sensors. By utilizing an aerospace-inspired "Closed-Loop Vortex System" and a 3D-printed dual-gasket sealing mechanism, this chamber ensures highly repeatable and stable sensor readings.



---

## 1. The Concept & Scientific Justification

Traditional E-Nose chambers often suffer from the "Closed Bottle Syndrome" (Aerodynamic Stall). If a fan simply blows air into a sealed box, the pressure equalizes instantly, the fan stalls, and airflow stops. If the chamber is open to the room, the VOC sample is diluted, rendering the sensors "blind."

### The Closed-Loop Vortex System
To solve this, this chamber isolates the internal mixing airflow from the external sample-gathering airflow:
1. The Cyclonic Plenum: The aerodynamic lid houses four tangential ducts. The 60mm fan forces air through these ducts, creating a high-speed peripheral cyclone inside the 1.2L chamber. 
2. The Honeycomb Diffuser: Before hitting the sensors, the turbulent cyclone passes through a 20mm hexagonal grid, straightening the flow into a uniform, laminar breeze over the sensor array.
3. The Return Vents: Four 8mm return vents draw the mixed air from the bottom of the chamber back into the fan dome, creating an endless, powerful mixing loop without losing hermeticity.

Because the internal loop is perfectly balanced, we can introduce a micro-flow of external VOC samples using simple pressure differentials.

---

## 2. Flow Rate & Fluid Dynamics Calculations

The system is connected to an external sample jar via PTFE tubing (2mm internal diameter). The fan creates a slight vacuum in the top dome and a slight positive pressure in the main chamber, acting as a gentle, passive pump.

Using the Hagen-Poiseuille equation for laminar flow in a pipe, we can calculate the exact sampling rate:

Q = (ΔP * π * r^4) / (8 * μ * L)

Where:
* ΔP ≈ 30 Pa (Average maximum static pressure of a standard 60mm axial fan)
* r = 0.001 m (Radius of the 2mm ID PTFE tubing)
* μ ≈ 1.81 x 10^-5 Pa*s (Dynamic viscosity of air)
* L ≈ 0.5 m (Total length of the sample loop tubing)

Q = (30 * 3.14159 * 0.001^4) / (8 * 1.81 x 10^-5 * 0.5)
Q ≈ 1.3 x 10^-6 m^3/s

Converted to standard flow rate:
Q ≈ 78 mL/min



Why is ~80 mL/min optimal?
MQ-series gas sensors rely on an internal micro-heater maintaining a steady temperature of ~300°C. If the airflow is too high (e.g., direct fan blast), the heater cools down, and the baseline readings drift wildly. A micro-flow of 80 mL/min acts as a gentle, continuous "inhalation" of the sample, matching the strict standards of commercial gas chromatography equipment.

---

## 3. Component Overview

All components are fully parametric and designed for FDM printing with zero support structures.

1. flow_chamber.stl - The main 1.2L body with M3 heat-set standoffs, 2x PC4-M6 ports, and a wire-potting cup.
2. sensor_plate.stl - A universal breadboard platform (7mm grid) for mounting MQ, BME688, or custom PCBs.
3. diffuser_insert.stl - A 20mm drop-in honeycomb flow straightener with integrated pillars.
4. lid_pro.stl - The main aerodynamic lid housing the tangential ducts, return vents, and gasket grooves.
5. fan_dome_ultimate.stl - The top shell that covers the fan, houses the sample inlet port, and completes the airflow loop.
6. tpu_gaskets.stl - Two custom gaskets (151mm and 94mm) that guarantee a 100% hermetic seal.

---

## 4. Bill of Materials (BOM)

| Category | Item | Quantity | Notes |
| :--- | :--- | :--- | :--- |
| Filament | PETG / ABS / ASA | ~300g | Rigid parts (resists high sensor temps). |
| Filament | TPU (Flexible) | ~10g | Critical for the airtight custom gaskets. |
| Hardware | M3 Heat-Set Inserts | 12 pcs | OD ~4.2mm, L ~5.5mm. |
| Hardware | M3x30mm Bolts | 4 pcs | Secures the internal diffuser stack. |
| Hardware | M3x14mm Bolts | 8 pcs | Secures the main lid to the base. |
| Hardware | M4x35mm Bolts + Nuts | 4 pcs | Secures the fan and upper dome. |
| Pneumatics | PC4-M6 Fittings | 3-4 pcs | Standard 3D printer Bowden fittings. |
| Pneumatics | PTFE Tubing | 1-2 meters | 4mm OD / 2mm ID. |
| Electronics| 60x60mm Axial Fan | 1 pc | 10mm to 20mm thickness. |
| Sealing | Silicone Sealant | 1 tube | Used for potting the sensor wires. |

---

## 5. Crucial Print Settings (TPU Gaskets)

To ensure the printed TPU gaskets do not leak air through micro-gaps, adjust your slicer settings as follows:
* Flow/Extrusion Multiplier: 106% - 108% (Over-extrusion seals the layers).
* Wall Loops/Perimeters: 5 or 6 (The gasket must be 100% solid walls).
* Top/Bottom Pattern: Concentric (Crucial! Do not use zig-zag/lines).
* Print Speed: 20 mm/s.

---

## 6. Assembly Instructions

1. Heat-Set Inserts: Melt the 12 M3 inserts into the base (8 on the top flange, 4 on the internal bottom standoffs).
2. Sensors & Wiring: Mount your sensors to the sensor_plate. Route the wire loom through the square cutout, out the wall hole, and into the external potting cup. 
3. Internal Stack: Place the sensor_plate on the bottom standoffs. Place the diffuser_insert on top (legs pointing down). Secure both to the base using the four M3x30mm bolts.
4. Wire Potting: Fill the external wire cup entirely with silicone sealant. Ensure it penetrates between the wires. Let it cure fully to create a hermetic seal.
5. Gaskets: Insert the large TPU gasket into the bottom of lid_pro. Insert the smaller TPU gasket into the top groove of the lid.
6. Seal the Base: Bolt lid_pro to the base using eight M3x14mm bolts. Tighten in a cross-pattern to compress the gasket.
7. Fan & Dome: Drop the 60mm fan into the lid recess (exhaust sticker pointing DOWN). Route the fan wire out the side hole of fan_dome_ultimate. Bolt the dome over the fan using four M4x35mm bolts. Seal the tiny wire hole with a dab of silicone.
8. Pneumatics: Tap the PC4-M6 fittings into the base and the top of the dome. Connect your sample jar.

> Important Operation Note: Brand new MQ-series sensors require a continuous 48-hour burn-in period (powered at 5V in clean air) to stabilize their internal SnO2 heating elements before gathering baseline data.