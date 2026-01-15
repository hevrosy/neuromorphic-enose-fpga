from __future__ import annotations
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Optional, Tuple
import re

@dataclass(frozen=True)
class XADCChannel:
    name: str
    iio_channel_index: int

def _find_iio_device() -> Optional[Path]:
    base = Path("/sys/bus/iio/devices")
    if not base.exists():
        return None
    # Try common patterns: iio:device0 ... containing XADC channels
    for dev in sorted(base.glob("iio:device*")):
        # Heuristic: look for in_voltage0_raw
        if (dev / "in_voltage0_raw").exists():
            return dev
    return None

def _read_int(p: Path) -> int:
    return int(p.read_text().strip())

def _read_float(p: Path) -> float:
    return float(p.read_text().strip())

def read_xadc_channels(channels: Tuple[XADCChannel, ...], extra_scale: Optional[float] = None) -> Dict[str, float]:
    """
    Reads XADC channels via Linux IIO sysfs.
    Returns values in "raw units" or scaled volts if scale is available.
    extra_scale (optional) multiplies the final value.
    """
    dev = _find_iio_device()
    if dev is None:
        raise RuntimeError("XADC IIO device not found under /sys/bus/iio/devices. Are you running on PYNQ/Linux?")

    out: Dict[str, float] = {}
    # Common: in_voltage{idx}_raw and in_voltage{idx}_scale
    for ch in channels:
        raw_path = dev / f"in_voltage{ch.iio_channel_index}_raw"
        if not raw_path.exists():
            raise RuntimeError(f"Missing {raw_path}. Available: {list(dev.glob('in_voltage*_raw'))}")

        raw = _read_int(raw_path)

        scale_path = dev / f"in_voltage{ch.iio_channel_index}_scale"
        if scale_path.exists():
            scale = _read_float(scale_path)
            val = raw * scale
        else:
            # Fallback: global in_voltage_scale (rare)
            global_scale = dev / "in_voltage_scale"
            if global_scale.exists():
                scale = _read_float(global_scale)
                val = raw * scale
            else:
                val = float(raw)

        if extra_scale is not None:
            val *= float(extra_scale)

        out[ch.name] = val

    return out
