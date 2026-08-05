# Modbus Sensor Map for Factory-Floor Simulator

This document maps the simulated Modbus telemetry exposed by [modbus_telemetry_simulator.py](modbus_telemetry_simulator.py).

## Endpoint

- Host endpoint: localhost:1502
- Docker network endpoint: modbus-sim:1502
- Unit ID: 1 (default)

## Addressing Model

- Holding Registers (FC03): telemetry values
- Input Registers (FC04): mirror of telemetry values
- Coils (FC01): run/alarm flags
- Discrete Inputs (FC02): mirror of run/alarm flags

Per-asset sizing:

- Registers per asset: 12
- Coils per asset: 2
- Discrete inputs per asset: 2
- Default asset count: 8

Offset formulas by asset number N (1-based):

- Register base offset: (N - 1) * 12
- Coil base offset: (N - 1) * 2
- Discrete input base offset: (N - 1) * 2

## Register Layout Per Asset

For each asset, offsets below are relative to that asset's register base offset.

| Relative Offset | Field | Scale | Example Decode |
|---|---|---|---|
| 0 | temperature_c | x10 | value / 10.0 |
| 1 | vibration_mm_s | x100 | value / 100.0 |
| 2 | current_a | x10 | value / 10.0 |
| 3 | pressure_bar | x100 | value / 100.0 |
| 4 | rpm | integer | value |
| 5 | load_pct | x10 | value / 10.0 |
| 6 | energy_kw | x10 | value / 10.0 |
| 7 | status_code | enum | 0 stopped, 1 running, 2 warning, 3 alarm |
| 8 | alarm_bits | bitfield | see alarm bit map |
| 9 | quality_pct | x10 | value / 10.0 |
| 10 | runtime_min | integer | value |
| 11 | heartbeat | integer | value |

## Alarm Bit Map (register +8)

| Bit | Meaning |
|---|---|
| 0 | over temperature |
| 1 | high vibration |
| 2 | over current |
| 3 | low pressure |
| 4 | high pressure |
| 5 | stopped state |

## Coil and Discrete Input Layout Per Asset

For each asset, offsets below are relative to that asset's coil/discrete-input base offset.

| Relative Offset | Field | Meaning |
|---|---|---|
| 0 | run_flag | 1 when running, warning, or alarm |
| 1 | alarm_flag | 1 when in alarm state |

## Default Asset Address Map (8 assets)

Asset profiles rotate in this sequence:

1. mixing_tank
2. air_compressor
3. conveyor_drive
4. cooling_chiller

Then repeat.

| Asset # | Profile | Register Range (FC03/FC04) | Coil Range (FC01) | Discrete Input Range (FC02) |
|---|---|---|---|---|
| 1 | mixing_tank | 0-11 | 0-1 | 0-1 |
| 2 | air_compressor | 12-23 | 2-3 | 2-3 |
| 3 | conveyor_drive | 24-35 | 4-5 | 4-5 |
| 4 | cooling_chiller | 36-47 | 6-7 | 6-7 |
| 5 | mixing_tank | 48-59 | 8-9 | 8-9 |
| 6 | air_compressor | 60-71 | 10-11 | 10-11 |
| 7 | conveyor_drive | 72-83 | 12-13 | 12-13 |
| 8 | cooling_chiller | 84-95 | 14-15 | 14-15 |

## Notes for Connector/Transform Setup

- Use FC03 or FC04 for telemetry fields; values are mirrored.
- Convert scaled fields to engineering units using the scale column above.
- Decode status_code and alarm_bits into human-friendly labels in transforms.
- If MODBUS_SIM_ASSET_COUNT changes, keep using the same formulas to compute offsets.
