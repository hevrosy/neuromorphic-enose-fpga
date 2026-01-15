# Data Format

## CSV (data/raw/*.csv)
Колони:
- t_ms (unix milliseconds)
- mq135_raw, mq3_raw, mq4_raw (или *_volts ако се скалира)
- temperature_c, humidity_rh, gas_resistance_ohm
- optional: flags (purge/valid)

## JSON (data/meta/*.json)
- run_id, label, batch_id
- config snapshot (важни параметри)
- notes, chamber info, purge info
