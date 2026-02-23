👃 Advanced E-Nose Fluidic Chamber (Support-Free FDM)
A professional-grade, 3D-printable fluidic chamber designed specifically for Electronic Nose (E-Nose) applications and VOC (Volatile Organic Compound) analysis.

This design solves the most common issues found in DIY electronic noses: poor gas mixing, lack of airtightness, and direct cold drafts disrupting the heated MQ-series gas sensors. By utilizing aerospace-inspired aerodynamics and a 3D-printed dual-gasket sealing system, this chamber ensures highly repeatable and stable sensor readings.

✨ Key Features
Tangential Vortex Plenum: The lid features built-in aerodynamic ducts that convert downward fan airflow into a tangential cyclone. This ensures perfect gas mixing in the 1.2L chamber.

Flush Honeycomb Diffuser: A 20mm drop-in hexagonal grid straightens the turbulent vortex into a uniform, laminar "breeze" right above the sensor array.

Universal Sensor Breadboard: The mounting plate features a 7mm grid of M3 clearance holes, allowing you to freely position various sensor breakouts (MQ series, BME688, Waveshare, SparkFun) without modifying the 3D model.

Dual TPU Gasket System: Utilizes custom 3D-printed TPU gaskets to seal both the main lid and the fan dome, guaranteeing a 100% airtight environment.

Wire Potting Gland: A dedicated external cup allows sensor wires to exit the chamber. Filling this cup with silicone creates an absolute hermetic seal around the wiring loom.

Zero-Support Printing: All components, including the complex aerodynamic ducts and overhangs, are optimized to be printed flat on the build plate with absolutely NO support structures required.

📦 Bill of Materials (BOM)
1. 3D Printed Parts
We highly recommend printing the rigid parts in PETG or ABS/ASA for temperature and chemical resistance. The gaskets MUST be printed in TPU.

flow_chamber.stl (Base)

sensor_plate.stl (Sensor mounting platform)

diffuser_insert.stl (Honeycomb grid with integrated legs)

lid_pro.stl (Aerodynamic main lid)

fan_dome_v2.stl (Recirculation cover)

tpu_gaskets.stl (Main and dome seals)

2. Fasteners & Hardware
12x M3 Heat-set inserts (OD ~4.2mm, L ~5.5mm)

8x M3x14mm bolts (For the main lid)

4x M3x30mm bolts (For the internal Diffuser + Sensor Plate stack)

4x M4x35mm bolts and nuts (Or M3x35mm with washers, for the fan and dome)

Assorted short M3 bolts & nuts (For mounting the sensors to the plate)

3. Pneumatics & Sealing
4x PC4-M6 Pneumatic fittings (Standard 3D printer Bowden fittings)

1-2m PTFE Tubing (4mm OD / 2mm ID)

1x Tube of clear sanitary silicone or neutral-cure silicone sealant

1x Glass jar (300-500ml) with a metal screw-on lid (for sample gathering)

4. Electronics
1x 60x60mm Axial Fan (10mm to 20mm thickness). Ensure the voltage matches your power supply (5V, 12V, or 24V).

Assorted Gas sensors (MQ-2, MQ-3, MQ-135, BME688, etc.)

Dupont jumper wires or soldered ribbon cables

🖨️ Crucial Print Settings (For TPU Gaskets)
To ensure the printed TPU gaskets are 100% airtight, you must adjust your slicer settings:

Speed: Print incredibly slow (Outer wall: 20mm/s, Inner: 30mm/s).

Flow / Extrusion Multiplier: Set to 106% - 108% (Over-extrusion seals micro-gaps).

Wall Loops / Perimeters: Set to 5 or 6 (The gasket should be 100% walls, no infill).

Top/Bottom Pattern: Set to CONCENTRIC (Do not use lines/zigzag, as air will escape through the toolpath lines).

Z-Seam: Set to Random.

🛠️ Assembly Instructions
Step 1: Heat-Set Inserts
Using a soldering iron set to ~220°C, gently press the 12 M3 heat-set inserts into the base: 8 into the top flange and 4 into the internal bottom standoffs.

Step 2: Pneumatic Ports
Screw two PC4-M6 fittings into the designated holes on the left wall of the flow_chamber. The threads will self-tap into the plastic.

Step 3: Sensor Array & Wiring
Arrange and bolt your sensors onto the sensor_plate.

Connect all necessary wiring.

Route the wire loom through the rectangular cutout on the plate, out through the 12x8mm hole in the chamber wall, and into the external potting cup.

Step 4: Internal Stack Assembly
Place the sensor_plate onto the 4 bottom standoffs.

Turn the diffuser_insert upside down so the 4 solid legs point downwards and the honeycomb grid faces up.

Drop the 4x M3x30mm bolts through the diffuser, through the sensor plate, and tighten them into the bottom inserts. This secures the core assembly.

Step 5: Wire Potting (Hermetic Seal)
Pull any slack out of the wires. Fill the external potting cup completely with silicone sealant, ensuring it penetrates between the individual wires. Allow it to cure fully according to the manufacturer's instructions.

Step 6: Gasket Installation
Place the large TPU gasket into the bottom groove of the lid_pro. Place the smaller TPU gasket into the top groove around the fan recess.

Step 7: Sealing the Chamber
Place the lid_pro onto the base and tighten the 8x M3x14mm bolts in a cross-pattern. The TPU gasket will compress from 3.2mm to 2.4mm, providing an absolute seal.

Step 8: Fan & Recirculation Dome
Place the 60mm fan into the lid recess. Important: The fan's exhaust side (usually the side with the sticker and struts) must face DOWN into the chamber.

Route the fan cable out through the small 5mm hole in the fan_dome_v2.

Place the dome over the fan, resting it on the top TPU gasket.

Secure everything using the 4x M4x35mm bolts.

Add a dab of silicone to the 5mm fan cable hole to seal it.

Step 9: Sample Jar Loop
Drill two holes in the metal lid of your glass sample jar and install the remaining two PC4-M6 fittings.

Connect the TOP port of the E-Nose chamber to one jar port using PTFE tubing (this pushes air into the jar).

Connect the BOTTOM port of the E-Nose chamber to the other jar port (this vacuums VOCs back to the sensors).

⚠️ Important Operation Note: Sensor Burn-in
If you are using brand-new MQ-series gas sensors (which rely on a heated SnO2 layer), you MUST perform a hardware burn-in. Power the sensors with 5V and leave them running continuously for a minimum of 48 hours in a clean-air environment before taking any baseline readings. Failing to do so will result in massive baseline drifting and inaccurate data.

Happy sniffing!