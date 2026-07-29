# FairCom MCP Demo for Claude Desktop

This repository is a lightweight sales and technical demo for showing FairCom MCP running against FairCom Edge with realistic data and a fast startup flow.

It is designed for two outcomes:
- Product story: show business value quickly through natural-language data exploration.
- Hands-on usage: give reps and engineers a repeatable, one-command setup with clear next steps.

## Product Description

FairCom MCP Demo helps teams prove that FairCom Edge data can be explored from Claude Desktop using MCP tools, without custom app code.

What this demo highlights:
- Fast local startup and teardown
- Realistic seeded data for meaningful questions
- MCP tool-based workflows for discovery and query
- A practical comparison path versus other MCP servers

Business value for demos:
- Short time-to-first-answer
- Easy setup for non-expert users
- Repeatable flow that can be run live with customers

## What Is Included

- Docker Compose runtime for FairCom Edge and FairCom MCP
- Seed automation for demo tables and realistic record volumes
- Claude Desktop config examples for MCP and auto-approve preferences
- Comparison templates in the comparison folder

## Prerequisites

- Docker Desktop (or Docker Engine + Compose)
- Claude Desktop
- curl
- Bash (macOS/Linux) or Git Bash/WSL2 on Windows

## Quick Start

1. Start services and seed data.

```bash
# macOS/Linux
./demo.sh

# Windows (Git Bash or WSL2)
bash ./demo.sh
```

2. Configure Claude Desktop using one of the example files in the examples folder:
   - examples/claude_desktop_config.sample.json
   - examples/claude_desktop_auto_approve.sample.json
   - examples/claude_desktop_full.sample.json

   Windows users should copy the relevant example into their Claude config location at %APPDATA%\Claude\claude_desktop_config.json (or the equivalent AppData\Roaming\Claude path) and update any placeholder values before launching Claude Desktop.

3. Fully quit and reopen Claude Desktop.

4. Try prompts such as:
- List available tables in this FairCom demo environment.
- Show columns for demo_sensor_readings.
- Count rows in demo_sensor_readings.
- Show top 10 alert readings ordered by temperature.

## Usage Instructions

### Demo Script Commands

```bash
# macOS/Linux
./demo.sh
./demo.sh --setup
./demo.sh --seed
./demo.sh --stop
./demo.sh --status

# Windows (Git Bash or WSL2)
bash ./demo.sh
bash ./demo.sh --setup
bash ./demo.sh --seed
bash ./demo.sh --stop
bash ./demo.sh --status
```

### Seeded Tables

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
- ASSETS_COUNT (default: 120)
- RECORD_COUNT (default: 6000)
- WORK_ORDERS_COUNT (default: 1800)
- MAINT_EVENTS_COUNT (default: 2400)

## Claude Desktop Configuration

On macOS, Claude Desktop config files are under:

```text
/Users/<your-user>/Library/Application Support/Claude/
```

On Windows, the config directory is typically:

```text
%APPDATA%\Claude\
```

Or in a common user profile location:

```text
C:\Users\<your-user>\AppData\Roaming\Claude\
```

Primary file:

```text
claude_desktop_config.json
```

### Configuration Examples in This Repo

Use these files as the starting point for your Claude Desktop config:

- examples/claude_desktop_config.sample.json
  - Required MCP server configuration only.
  - Best for a minimal setup.

- examples/claude_desktop_auto_approve.sample.json
  - Optional preferences block for permission-bypass and model fallback mappings.
  - Includes multiple account UUID placeholders because some environments can use more than one account or org identifier.

- examples/claude_desktop_full.sample.json
  - Single-file combined example: MCP server + optional preferences.
  - Best for Windows users who want one ready-to-merge configuration file.

Windows note: copy the chosen example into the Claude config file at %APPDATA%\Claude\claude_desktop_config.json and replace any placeholder values before restarting Claude Desktop.

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

- demo.sh: Setup and seed automation
- docker-compose.yml: FairCom Edge and FairCom MCP services
- examples/claude_desktop_config.sample.json: MCP server config sample
- examples/claude_desktop_auto_approve.sample.json: Optional preference mappings
- examples/claude_desktop_full.sample.json: Combined sample
- comparison/checklist.md: Comparison checklist
- comparison/results-template.md: Comparison output template

## Architecture Constraint

- Keep demo flows protocol-first and single-table at the API boundary.
- For multi-table stories, compose results in the local application layer.

## References

- FairCom MCP upstream README: https://github.com/toddstoffel/faircom-mcp/blob/main/README.md
- FairCom JSON Action REST API: https://documentation.faircom.com/en_US/json-action-rest-api
