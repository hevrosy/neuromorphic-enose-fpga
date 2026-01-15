from pathlib import Path

def find_iio_device():
    base = Path("/sys/bus/iio/devices")
    if not base.exists():
        return None
    for dev in sorted(base.glob("iio:device*")):
        if (dev / "in_voltage0_raw").exists():
            return dev
    return None

def main():
    print("=== PYNQ Self-Test ===")

    # IIO/XADC
    dev = find_iio_device()
    if dev is None:
        print("[XADC] NOT FOUND: /sys/bus/iio/devices/iio:device* with in_voltage0_raw")
    else:
        print(f"[XADC] OK: {dev}")
        raws = sorted(dev.glob("in_voltage*_raw"))
        print(f"[XADC] raw channels found: {len(raws)}")
        # Try read first few
        for p in raws[:4]:
            try:
                v = int(p.read_text().strip())
                print(f"  {p.name} = {v}")
            except Exception as e:
                print(f"  {p.name} read failed: {e}")

    # BME688 lib probe (doesn't fail build; just informs)
    try:
        import bme680  # noqa
        print("[BME] bme680 library: FOUND")
    except Exception as e:
        print(f"[BME] bme680 library: NOT FOUND ({e})")

    try:
        import adafruit_bme680  # noqa
        print("[BME] adafruit-circuitpython-bme680: FOUND")
    except Exception as e:
        print(f"[BME] adafruit-circuitpython-bme680: NOT FOUND ({e})")

    print("=== Done ===")

if __name__ == "__main__":
    main()
