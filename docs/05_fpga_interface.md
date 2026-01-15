# FPGA Interface (Draft)

## AXI-Lite registers (example)
0x00 CONTROL: bit0=start, bit1=reset, bit2=busy, bit3=done
0x04 WINDOW_LEN (W)
0x08 LEAK_SHIFTS (Lh in [7:0], Lo in [15:8])
0x0C THRESHOLDS (Th, To) (packed or separate regs)
0x10 OUT_CLASS
0x14 OUT_CONF_Q0_8
0x18 OUT_COUNTS (packed C0,C1,C2) or 3 regs

## AXI-Stream input
Events for each timestep, TLAST marks end-of-timestep.
Event word (32-bit):
[31:24] src_id (0..11)
others reserved for v1
