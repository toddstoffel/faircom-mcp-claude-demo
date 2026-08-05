#!/usr/bin/env python3
"""Factory-floor Modbus TCP telemetry simulator for demo and connector testing."""

import math
import os
import random
import threading
import time

from pymodbus.datastore import ModbusSequentialDataBlock
from pymodbus.datastore import ModbusServerContext
from pymodbus.datastore import ModbusSlaveContext
from pymodbus.server import StartTcpServer

HOST = os.getenv("MODBUS_SIM_HOST", "0.0.0.0")
PORT = int(os.getenv("MODBUS_SIM_PORT", "1502"))
UNIT_ID = int(os.getenv("MODBUS_SIM_UNIT_ID", "1"))
UPDATE_SECONDS = float(os.getenv("MODBUS_SIM_UPDATE_SECONDS", "1.0"))
ASSET_COUNT = int(os.getenv("MODBUS_SIM_ASSET_COUNT", "8"))
REGISTERS_PER_ASSET = 12
REGISTER_COUNT = int(
    os.getenv("MODBUS_SIM_REGISTER_COUNT", str(ASSET_COUNT * REGISTERS_PER_ASSET))
)
COIL_COUNT = ASSET_COUNT * 2

STATUS_STOPPED = 0
STATUS_RUNNING = 1
STATUS_WARN = 2
STATUS_ALARM = 3

ASSET_PROFILES = [
    {
        "name": "mixing_tank",
        "temp_base": 63.0,
        "temp_amp": 6.5,
        "temp_hi": 78.0,
        "vib_base": 1.4,
        "vib_amp": 0.5,
        "vib_hi": 3.0,
        "current_base": 24.0,
        "current_amp": 6.0,
        "current_hi": 38.0,
        "pressure_base": 5.2,
        "pressure_amp": 0.7,
        "pressure_lo": 3.9,
        "pressure_hi": 7.1,
        "rpm_base": 1460,
        "rpm_amp": 100,
    },
    {
        "name": "air_compressor",
        "temp_base": 71.0,
        "temp_amp": 5.0,
        "temp_hi": 86.0,
        "vib_base": 1.9,
        "vib_amp": 0.6,
        "vib_hi": 3.6,
        "current_base": 36.0,
        "current_amp": 8.0,
        "current_hi": 52.0,
        "pressure_base": 7.0,
        "pressure_amp": 0.9,
        "pressure_lo": 5.8,
        "pressure_hi": 8.9,
        "rpm_base": 1780,
        "rpm_amp": 120,
    },
    {
        "name": "conveyor_drive",
        "temp_base": 52.0,
        "temp_amp": 4.5,
        "temp_hi": 67.0,
        "vib_base": 1.1,
        "vib_amp": 0.4,
        "vib_hi": 2.5,
        "current_base": 18.0,
        "current_amp": 4.2,
        "current_hi": 28.0,
        "pressure_base": 3.2,
        "pressure_amp": 0.4,
        "pressure_lo": 2.5,
        "pressure_hi": 4.3,
        "rpm_base": 1220,
        "rpm_amp": 90,
    },
    {
        "name": "cooling_chiller",
        "temp_base": 14.0,
        "temp_amp": 2.1,
        "temp_hi": 22.0,
        "vib_base": 0.9,
        "vib_amp": 0.3,
        "vib_hi": 2.0,
        "current_base": 28.0,
        "current_amp": 5.1,
        "current_hi": 41.0,
        "pressure_base": 4.8,
        "pressure_amp": 0.8,
        "pressure_lo": 3.7,
        "pressure_hi": 6.2,
        "rpm_base": 980,
        "rpm_amp": 70,
    },
]


def clamp_u16(value: int) -> int:
    return max(0, min(65535, int(value)))


def scale(value: float, factor: int) -> int:
    return clamp_u16(round(value * factor))


def make_assets() -> list[dict]:
    assets = []
    for idx in range(ASSET_COUNT):
        profile = ASSET_PROFILES[idx % len(ASSET_PROFILES)]
        assets.append(
            {
                "asset_id": idx + 1,
                "profile": profile,
                "phase": random.uniform(0.0, math.tau),
                "state": STATUS_RUNNING,
                "fault_ticks": 0,
                "runtime_min": random.randint(60, 2000),
                "heartbeat": random.randint(0, 5000),
            }
        )
    return assets


def evaluate_alarms(asset: dict, temp_c: float, vib_mm_s: float, current_a: float, pressure_bar: float) -> int:
    profile = asset["profile"]
    bits = 0
    if temp_c > profile["temp_hi"]:
        bits |= 1 << 0
    if vib_mm_s > profile["vib_hi"]:
        bits |= 1 << 1
    if current_a > profile["current_hi"]:
        bits |= 1 << 2
    if pressure_bar < profile["pressure_lo"]:
        bits |= 1 << 3
    if pressure_bar > profile["pressure_hi"]:
        bits |= 1 << 4
    if asset["state"] == STATUS_STOPPED:
        bits |= 1 << 5
    return bits


def compute_asset_telemetry(asset: dict, update_seconds: float) -> tuple[list[int], list[int], list[int]]:
    profile = asset["profile"]
    phase = float(asset["phase"])

    if asset["fault_ticks"] > 0:
        asset["fault_ticks"] -= 1
        asset["state"] = STATUS_ALARM
    else:
        if random.random() < 0.015:
            asset["state"] = STATUS_STOPPED
        elif random.random() < 0.03:
            asset["state"] = STATUS_WARN
        else:
            asset["state"] = STATUS_RUNNING

        if asset["state"] != STATUS_STOPPED and random.random() < 0.01:
            asset["fault_ticks"] = random.randint(3, 7)
            asset["state"] = STATUS_ALARM

    state = int(asset["state"])
    load_scale = {
        STATUS_STOPPED: 0.08,
        STATUS_RUNNING: 1.0,
        STATUS_WARN: 0.85,
        STATUS_ALARM: 1.18,
    }[state]

    temp_c = profile["temp_base"] + profile["temp_amp"] * math.sin(phase) * load_scale + random.uniform(-0.6, 0.6)
    vib_mm_s = profile["vib_base"] + profile["vib_amp"] * math.sin(phase * 1.6 + 0.4) * load_scale + random.uniform(-0.1, 0.1)
    current_a = profile["current_base"] + profile["current_amp"] * math.sin(phase * 0.7 + 1.1) * load_scale + random.uniform(-0.8, 0.8)
    pressure_bar = profile["pressure_base"] + profile["pressure_amp"] * math.sin(phase * 0.9 + 2.4) * load_scale + random.uniform(-0.08, 0.08)
    rpm = profile["rpm_base"] + profile["rpm_amp"] * math.sin(phase * 1.2 + 0.2)

    if state == STATUS_STOPPED:
        rpm = max(0.0, rpm * 0.04)
        current_a = max(0.0, current_a * 0.1)
        pressure_bar = max(0.0, pressure_bar * 0.2)

    if state != STATUS_STOPPED:
        asset["runtime_min"] += update_seconds / 60.0
    asset["heartbeat"] = (int(asset["heartbeat"]) + 1) % 65535

    alarm_bits = evaluate_alarms(asset, temp_c, vib_mm_s, current_a, pressure_bar)
    if alarm_bits and state != STATUS_STOPPED:
        state = STATUS_ALARM if (alarm_bits & 0b00000111) else STATUS_WARN

    load_pct = max(0.0, min(120.0, (current_a / max(profile["current_base"], 0.1)) * 78.0))
    energy_kw = max(0.0, current_a * 0.72)
    quality_pct = max(60.0, 99.5 - (4.0 if state == STATUS_WARN else 0.0) - (10.0 if state == STATUS_ALARM else 0.0))

    registers = [
        scale(temp_c, 10),
        scale(vib_mm_s, 100),
        scale(current_a, 10),
        scale(pressure_bar, 100),
        clamp_u16(round(rpm)),
        scale(load_pct, 10),
        scale(energy_kw, 10),
        clamp_u16(state),
        clamp_u16(alarm_bits),
        scale(quality_pct, 10),
        clamp_u16(round(asset["runtime_min"])),
        clamp_u16(asset["heartbeat"]),
    ]

    # Coil map per asset: run state and alarm state.
    coils = [1 if state in (STATUS_RUNNING, STATUS_WARN, STATUS_ALARM) else 0, 1 if state == STATUS_ALARM else 0]
    # Discrete inputs mirror key operational flags.
    discrete_inputs = [coils[0], coils[1]]

    asset["phase"] = phase + 0.11 + random.uniform(-0.02, 0.02)
    return registers, coils, discrete_inputs


def build_context() -> ModbusServerContext:
    block = [0] * REGISTER_COUNT
    coil_block = [0] * COIL_COUNT
    store = ModbusSlaveContext(
        di=ModbusSequentialDataBlock(0, coil_block.copy()),
        co=ModbusSequentialDataBlock(0, coil_block.copy()),
        hr=ModbusSequentialDataBlock(0, block.copy()),
        ir=ModbusSequentialDataBlock(0, block.copy()),
    )
    return ModbusServerContext(slaves={UNIT_ID: store}, single=False)


def update_loop(context: ModbusServerContext) -> None:
    assets = make_assets()

    while True:
        values = [0] * REGISTER_COUNT
        coil_values = [0] * COIL_COUNT
        di_values = [0] * COIL_COUNT

        for idx, asset in enumerate(assets):
            registers, coils, discrete_inputs = compute_asset_telemetry(asset, UPDATE_SECONDS)
            reg_start = idx * REGISTERS_PER_ASSET
            coil_start = idx * 2

            if reg_start + REGISTERS_PER_ASSET > len(values):
                break

            values[reg_start : reg_start + REGISTERS_PER_ASSET] = registers
            if coil_start + 1 < len(coil_values):
                coil_values[coil_start : coil_start + 2] = coils
                di_values[coil_start : coil_start + 2] = discrete_inputs

        context[UNIT_ID].setValues(1, 0, coil_values)
        context[UNIT_ID].setValues(2, 0, di_values)
        context[UNIT_ID].setValues(3, 0, values)
        context[UNIT_ID].setValues(4, 0, values)
        time.sleep(UPDATE_SECONDS)


def main() -> None:
    context = build_context()

    updater = threading.Thread(target=update_loop, args=(context,), daemon=True)
    updater.start()

    print(
        f"[modbus-sim] Serving Modbus TCP on {HOST}:{PORT} "
        f"(unit={UNIT_ID}, assets={ASSET_COUNT}, registers={REGISTER_COUNT})",
        flush=True,
    )
    print(
        "[modbus-sim] Register map per asset (12 registers): "
        "temp_c_x10, vibration_mm_s_x100, current_a_x10, pressure_bar_x100, "
        "rpm, load_pct_x10, energy_kw_x10, status_code, alarm_bits, "
        "quality_pct_x10, runtime_min, heartbeat",
        flush=True,
    )
    StartTcpServer(context=context, address=(HOST, PORT))


if __name__ == "__main__":
    main()
