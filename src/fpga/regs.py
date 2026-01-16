from __future__ import annotations

# AXI-Lite register offsets (bytes)
CONTROL        = 0x00
STATUS         = 0x04
WINDOW_LEN     = 0x08
N_IN           = 0x0C
N_HIDDEN       = 0x10
N_OUT          = 0x14
RESULT_CLASS   = 0x18
COUNT0         = 0x1C
COUNT1         = 0x20
COUNT2         = 0x24
CONF_Q15       = 0x28
LATENCY_CYCLES = 0x2C

# CONTROL bits
CTRL_START = 1 << 0
CTRL_RESET = 1 << 1
CTRL_INTEN = 1 << 2

# STATUS bits
STS_DONE = 1 << 0
STS_BUSY = 1 << 1
STS_ERR  = 1 << 2
