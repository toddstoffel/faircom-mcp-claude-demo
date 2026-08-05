# FairCom MCP Demo for Claude Desktop

This repository is a lightweight sales and technical demo for showing FairCom MCP running against FairCom Edge with realistic data and a fast startup flow.

It is designed for two outcomes:
- Product story: show business value quickly through natural-language data exploration.
- Hands-on usage: give reps and engineers a repeatable, one-command setup with clear next steps.

## Product Description

FairCom MCP Demo helps teams prove that FairCom Edge data can be explored from Claude Desktop using MCP tools, without custom app code.

What this demo highlights:
- Fast local startup and teardown
- Realistic sample ERP data for meaningful questions
- Optional Modbus TCP simulator for connector and transform experiments
- MCP tool-based workflows for discovery and query
- A practical comparison path versus other MCP servers

Business value for demos:
- Short time-to-first-answer
- Easy setup for non-expert users
- Repeatable flow that can be run live with customers

## What Is Included

- Docker Compose runtime for FairCom Edge and FairCom MCP
- Optional Docker Compose profile for a simulated Modbus TCP telemetry source
- Sample ERP dataset loader for demo tables and realistic record volumes
- Claude Desktop config examples for MCP and auto-approve preferences
- Comparison templates in the comparison folder

## Prerequisites

- Docker Desktop (or Docker Engine + Compose)
- Claude Desktop
- curl
- Bash (macOS/Linux) or PowerShell 5+/7 on Windows
- Windows users should run the demo with PowerShell via demo.cmd or demo.ps1 rather than relying on WSL or Git Bash

## Quick Start

1. Start services (no sample ERP seed by default).

```powershell
# macOS/Linux
./demo.sh

# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File .\demo.ps1
# or
./demo.cmd
```

2. Configure Claude Desktop using one of the example files in the examples folder:
  - examples/linux-mac/claude_desktop_config.json
   - examples/claude_desktop_auto_approve.json
   - examples/claude_desktop_full.json
  - examples/windows/claude_desktop_config.json

  On Windows, use Claude Desktop Settings > Developer > Edit Config to open the exact config file used by your running install, then paste your chosen example content into that file. Save it with the exact filename claude_desktop_config.json, replace placeholders, then fully quit Claude from the system tray and relaunch. The repo also includes Windows-friendly launchers in demo.cmd and demo.ps1 so the demo can be started without relying on WSL or Git Bash.

3. Fully quit and reopen Claude Desktop.

4. Try prompts such as:
- List available tables in this FairCom demo environment.
- Show columns for demo_sensor_readings.
- Count rows in demo_sensor_readings.
- Show top 10 alert readings ordered by temperature.

Optional: include `--seed` during startup if you want the sample ERP dataset tables loaded.

Default startup does not configure Modbus data ingestion into FairCom Edge. That connector setup is intentionally left to MCP-driven configuration steps.

## Usage Instructions

### Demo Script Commands

```bash
# macOS/Linux
./demo.sh
./demo.sh --setup
./demo.sh --seed          # setup + sample ERP dataset
./demo.sh --modbus --seed # setup + modbus + sample ERP dataset
./demo.sh --stop
./demo.sh --status
./demo.sh --modbus

# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File .\demo.ps1
powershell -ExecutionPolicy Bypass -File .\demo.ps1 --setup
powershell -ExecutionPolicy Bypass -File .\demo.ps1 --seed
powershell -ExecutionPolicy Bypass -File .\demo.ps1 --modbus --seed
powershell -ExecutionPolicy Bypass -File .\demo.ps1 --stop
powershell -ExecutionPolicy Bypass -File .\demo.ps1 --status
powershell -ExecutionPolicy Bypass -File .\demo.ps1 --modbus

# or use the wrapper batch file
./demo.cmd
./demo.cmd --setup
./demo.cmd --seed
./demo.cmd --modbus --seed
./demo.cmd --stop
./demo.cmd --status
./demo.cmd --modbus
```

### Sample ERP Dataset Tables

- demo_assets
- demo_sensor_readings
- demo_work_orders
- demo_maintenance_events

Default volumes:
- assets: 120
- sensor readings: 6000
- work orders: 1800
- maintenance events: 2400

Larger run example:

```bash
ASSETS_COUNT=300 RECORD_COUNT=20000 WORK_ORDERS_COUNT=5000 MAINT_EVENTS_COUNT=7000 ./demo.sh --seed
```

### Environment Overrides

- EDGE_JSON_API_URL (default: http://127.0.0.1:8080/api)
- EDGE_HTTP_URL (default: http://127.0.0.1:8080/)
- MCP_BASE_URL (default: http://127.0.0.1:8000)
- EDGE_USERNAME (default: ADMIN)
- EDGE_PASSWORD (default: ADMIN)
- EDGE_DATABASE (default: faircom)
- EDGE_OWNER (default: admin)
- ENABLE_MODBUS_SIM (default: 0)
- MODBUS_SIM_PORT (default: 1502)
- MODBUS_SIM_UNIT_ID (default: 1)
- MODBUS_SIM_ASSET_COUNT (default: 8)
- MODBUS_SIM_REGISTER_COUNT (default: MODBUS_SIM_ASSET_COUNT x 12)
- MODBUS_SIM_UPDATE_SECONDS (default: 1.0)
- ASSETS_COUNT (default: 120)
- RECORD_COUNT (default: 6000)
- WORK_ORDERS_COUNT (default: 1800)
- MAINT_EVENTS_COUNT (default: 2400)

### Optional Modbus Simulator

Use one of these commands when you want a local Modbus endpoint for FairCom Edge connector testing:

```bash
./demo.sh --modbus
# include sample ERP dataset tables
./demo.sh --modbus --seed
```

```powershell
powershell -ExecutionPolicy Bypass -File .\demo.ps1 --modbus
# include sample ERP dataset tables
powershell -ExecutionPolicy Bypass -File .\demo.ps1 --modbus --seed
```

Simple rule:
- default runs setup only
- --seed adds sample ERP dataset tables
- --modbus adds Modbus simulator
- --modbus --seed runs everything

Advanced setup-only with Modbus simulator:

```bash
ENABLE_MODBUS_SIM=1 ./demo.sh --setup
```

```powershell
$env:ENABLE_MODBUS_SIM=1; powershell -ExecutionPolicy Bypass -File .\demo.ps1 --setup
```

This starts an opt-in simulator on localhost:1502.
No Modbus connector or transform is auto-created in FairCom Edge.

Factory-floor telemetry profile (default behavior):
- 8 simulated assets by default (configurable with MODBUS_SIM_ASSET_COUNT)
- Asset classes rotate across mixing tank, air compressor, conveyor drive, and cooling chiller
- Per-asset state model: stopped, running, warning, alarm
- Per-asset alarms are encoded as bit flags (overtemp, vibration, overcurrent, low/high pressure, stopped)
- Full address map and bit decoding: [modbus-sim/modbus-sensor-map.md](modbus-sim/modbus-sensor-map.md)

Register map per asset (12 holding/input registers):
1. temperature_c x10
2. vibration_mm_s x100
3. current_a x10
4. pressure_bar x100
5. rpm
6. load_pct x10
7. energy_kw x10
8. status_code (0 stopped, 1 running, 2 warning, 3 alarm)
9. alarm_bits
10. quality_pct x10
11. runtime_min
12. heartbeat

Coils/discrete inputs per asset:
- offset +0: run state flag
- offset +1: alarm state flag

### MCP-Driven Connector and Transform Workflow

Goal: let AI use FairCom MCP to help configure FairCom Edge connectors and transforms against a known Modbus source.

1. Start with the optional simulator enabled.
2. In Claude Desktop, ask MCP to inspect current Edge configuration (connectors, pipelines, transforms).
3. Ask MCP to create or update a Modbus connector targeting host modbus-sim and port 1502.
4. Ask MCP to define a transform that maps incoming registers to a single target table/entity.
5. Validate with MCP queries by checking row growth and sampled transformed values.

Reference tutorials for connector and transform setup patterns:
- https://documentation.faircom.com/en_US/edge-tutorials/faircom-edge-tutorials

## Claude Desktop Configuration

Start with Claude Desktop Settings > Developer > Edit Config. This opens the actual config path used by the running app instance and avoids install-type path confusion.

On macOS, Claude Desktop config files are under:

```text
/Users/<your-user>/Library/Application Support/Claude/
```

On Windows, traditional installs commonly use:

```text
%APPDATA%\Claude\
```

Which usually resolves to:

```text
C:\Users\<your-user>\AppData\Roaming\Claude\
```

For MSIX/Store-style installs, Windows can virtualize this location to a package-specific path under LocalAppData\Packages, for example:

```text
C:\Users\<your-user>\AppData\Local\Packages\<package-family-name>\LocalCache\Roaming\Claude\
```

The package-family-name value varies by install channel and version. Use Settings > Developer > Edit Config to open the exact active path used by your running Claude Desktop instance.

Use Edit Config instead of guessing paths.

Primary file:

```text
claude_desktop_config.json
```

### Configuration Examples in This Repo

Use these files as starting points for your Claude Desktop config. Each file has a different purpose.

Recommended selection order:

1. Windows users: start with examples/windows/claude_desktop_config.json.
2. Linux/macOS users: start with examples/linux-mac/claude_desktop_config.json.
3. Add preferences from examples/claude_desktop_auto_approve.json only if you need account-level behavior settings.
4. Use examples/claude_desktop_full.json only as a reference for a combined structure.

#### Example File Purpose and When to Use It

- examples/linux-mac/claude_desktop_config.json
  - Contains mcpServers only.
  - Uses command: docker and expects docker to resolve from PATH.
  - Use for Linux/macOS, or any environment where docker is reliably on PATH.

- examples/claude_desktop_auto_approve.json
  - Contains preferences only.
  - Does not define mcpServers and will not start a connector by itself.
  - Use when you already have an MCP config and want optional account-based preference mappings.
  - Includes multiple account UUID placeholders because some environments can use more than one account or org identifier.

- examples/claude_desktop_full.json
  - Contains both mcpServers and preferences in one file.
  - Uses command: docker (PATH-based), so it may require edits on Windows if Claude cannot resolve docker.
  - Use as a combined reference template, especially for understanding final JSON shape.

- examples/windows/claude_desktop_config.json
  - Contains mcpServers only.
  - Uses an absolute docker.exe path for Windows.
  - Use as the default Windows connector template to avoid PATH resolution failures in Claude Desktop.

#### How to Apply These Examples Correctly

Claude Desktop reads one primary config file named claude_desktop_config.json. It does not auto-load these repo filenames directly.

Use this process:

1. Open Claude Desktop and go to Settings > Developer > Edit Config.
2. Replace or merge content from the example file into that opened config file.
3. Keep valid JSON with one top-level object. Do not paste multiple separate JSON documents.
4. If combining MCP + preferences manually, final shape should look like this:

```json
{
  "mcpServers": {
    "faircom-mcp-demo": {
      "command": "...",
      "args": ["..."]
    }
  },
  "preferences": {
    "bypassPermissionsGateByAccount": {
      "YOUR_ACCOUNT_UUID_PRIMARY": true
    },
    "coworkModelAutoFallbackByAccount": {
      "YOUR_ACCOUNT_UUID_PRIMARY": true
    }
  }
}
```

5. Save, fully quit Claude from the system tray, then relaunch.

#### Common Misconfiguration Patterns

- Using examples/claude_desktop_auto_approve.json alone and expecting connector startup.
- Keeping example filename instead of applying content to Claude's active claude_desktop_config.json.
- Using command: docker on Windows when Claude cannot resolve PATH.
- Closing Claude window without fully exiting from tray after config edits.

Windows note: ensure the file name is exactly claude_desktop_config.json. Claude does not auto-load alternate names like claude_desktop_full.json.

### Windows Connector Not Found Troubleshooting

If Claude Desktop on Windows does not show the faircom-mcp-demo connector, check these in order:

1. In Claude Desktop, open Settings > Developer > Edit Config and use that file. Do not assume %APPDATA% is the active path for MSIX installs.
2. Confirm filename is exact: claude_desktop_config.json.
3. Use examples/windows/claude_desktop_config.json first. It uses an absolute docker.exe path that avoids PATH resolution issues in some Windows installs.
4. Verify docker path exists:
  - C:\Program Files\Docker\Docker\resources\bin\docker.exe
  - If your install differs, update command to your actual docker.exe path.
5. Ensure the config is valid JSON (no comments, no trailing commas).
6. Fully quit Claude Desktop from the system tray, then relaunch.
7. If still missing, run in PowerShell and verify:
  - Test-Path "$env:APPDATA\Claude\claude_desktop_config.json"
  - Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory | Where-Object { $_.Name -match "Claude|Anthropic" }
  - Test-Path "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
8. If the connector still does not appear, inspect Claude logs next to the active config path for per-server launch logs (for example mcp-server-faircom-mcp-demo.log).

### Important Placeholders

Replace these values with your own before use:
- YOUR_ACCOUNT_UUID_PRIMARY
- YOUR_ACCOUNT_UUID_ALT_1
- YOUR_ACCOUNT_UUID_ALT_2

## Permission Prompt Troubleshooting

This section documents what was changed and what we observed while troubleshooting repeated approval prompts.

### Changes Applied

- Added preferences.bypassPermissionsGateByAccount entries for all discovered account UUIDs.
- Added preferences.coworkModelAutoFallbackByAccount entries for the same UUIDs.
- Tested dxt:allowlistEnabled org flags in Claude internal config.json during troubleshooting.
- Verified runtime settings in Claude support files and restarted Claude Desktop.

### What Logs Showed

In Claude logs, we consistently observed:
- Organization allowlist enabled: false
- Updated allowlist enabled state for org ...: false
- permission_error with message: Claude Code requires a Pro or Max subscription.

### Practical Meaning

- Local config can improve behavior but may be overridden by org/account policy.
- Claude internal allowlist flags can be reset by runtime policy checks.
- If policy forces allowlist off, manual approvals can still appear.
- This is not a FairCom MCP server failure; FairCom MCP can still initialize and execute tools successfully.

### If Prompts Still Appear

1. Confirm Claude account/org entitlement supports the required features.
2. Confirm UUID mappings are correct in your local config.
3. Fully quit and relaunch Claude Desktop.
4. Re-check Claude logs for allowlist resets after restart.

## Suggested Demo Prompt Flow

1. What tools are available from faircom-mcp-demo?
2. List tables that start with demo_.
3. Describe demo_sensor_readings and summarize key fields.
4. Find the top 5 assets by number of alert readings.
5. Count open vs closed work orders.

## Repo Contents

- demo.sh: Setup and sample ERP dataset loader for macOS/Linux
- demo.ps1: PowerShell entrypoint for Windows
- demo.cmd: Windows Command Prompt launcher for demo.ps1
- docker-compose.yml: FairCom Edge and FairCom MCP services
- modbus-sim/modbus_telemetry_simulator.py: Optional simulated Modbus TCP telemetry source
- examples/linux-mac/claude_desktop_config.json: Linux/macOS MCP server config sample
- examples/claude_desktop_auto_approve.json: Optional preference mappings
- examples/claude_desktop_full.json: Combined sample
- examples/windows/claude_desktop_config.json: Windows docker.exe-path sample
- comparison/checklist.md: Comparison checklist
- comparison/results-template.md: Comparison output template

## Architecture Constraint

- Keep demo flows protocol-first and single-table at the API boundary.
- For multi-table stories, compose results in the local application layer.

## References

- FairCom MCP upstream README: https://github.com/toddstoffel/faircom-mcp/blob/main/README.md
- FairCom JSON Action REST API: https://documentation.faircom.com/en_US/json-action-rest-api
