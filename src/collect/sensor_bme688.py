from __future__ import annotations
from dataclasses import dataclass
from typing import Dict, Optional

@dataclass(frozen=True)
class BME688Config:
    i2c_bus: int = 1
    i2c_addr: int = 0x76

def read_bme688(cfg: BME688Config) -> Dict[str, float]:
    """
    Reads BME688. We try 'bme680' python lib first.
    If not installed, raise with instructions.
    """
    try:
        import bme680  # type: ignore
    except Exception as e:
        raise RuntimeError(
            "BME688 library not found. Install one of:\n"
            "  pip install bme680\n"
            "or\n"
            "  pip install adafruit-circuitpython-bme680\n"
            "Then update this module accordingly.\n"
            f"Original import error: {e}"
        )

    # bme680 supports BME680/BME688-compatible chips in practice.
    sensor = bme680.BME680(i2c_addr=cfg.i2c_addr, i2c_device=cfg.i2c_bus)

    # Basic read
    if not sensor.get_sensor_data():
        raise RuntimeError("BME688: failed to read sensor data")

    temperature_c = float(sensor.data.temperature)
    humidity_rh = float(sensor.data.humidity)

    gas_res = None
    if sensor.data.heat_stable:
        gas_res = float(sensor.data.gas_resistance)
    else:
        # still return something, but note that gas may be unstable early on
        gas_res = float(sensor.data.gas_resistance) if sensor.data.gas_resistance else float("nan")

    return {
        "temperature_c": temperature_c,
        "humidity_rh": humidity_rh,
        "gas_resistance_ohm": gas_res,
    }
