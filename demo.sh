#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

EDGE_JSON_API_URL="${EDGE_JSON_API_URL:-http://127.0.0.1:8080/api}"
EDGE_HTTP_URL="${EDGE_HTTP_URL:-http://127.0.0.1:8080/}"
MCP_BASE_URL="${MCP_BASE_URL:-http://127.0.0.1:8000}"
EDGE_USERNAME="${EDGE_USERNAME:-ADMIN}"
EDGE_PASSWORD="${EDGE_PASSWORD:-ADMIN}"
EDGE_DATABASE="${EDGE_DATABASE:-faircom}"
EDGE_OWNER="${EDGE_OWNER:-admin}"

DEMO_TABLE_ASSETS="demo_assets"
DEMO_TABLE_READINGS="demo_sensor_readings"
DEMO_TABLE_WORK_ORDERS="demo_work_orders"
DEMO_TABLE_MAINT_EVENTS="demo_maintenance_events"

ASSETS_COUNT="${ASSETS_COUNT:-120}"
RECORD_COUNT="${RECORD_COUNT:-6000}"
WORK_ORDERS_COUNT="${WORK_ORDERS_COUNT:-1800}"
MAINT_EVENTS_COUNT="${MAINT_EVENTS_COUNT:-2400}"

DEMO_ASSETS_JSON=""
DEMO_SENSOR_READINGS_JSON=""
DEMO_WORK_ORDERS_JSON=""
DEMO_MAINT_EVENTS_JSON=""

log() {
  printf '[demo] %s\n' "$*"
}

die() {
  printf '[demo] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "Missing required command: $1"
  fi
}

api_call() {
  local payload="$1"
  curl -fsS "$EDGE_JSON_API_URL" \
    -H 'Content-Type: application/json' \
    -d "$payload"
}

extract_auth_token() {
  tr -d '\n' | sed -n 's/.*"authToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

extract_error_code() {
  tr -d '\n' | grep -Eo '"errorCode"[[:space:]]*:[[:space:]]*-?[0-9]+' | head -n1 | sed -E 's/.*:[[:space:]]*//'
}

site_name_from_idx() {
  case "$1" in
    1) printf 'north-line' ;;
    2) printf 'south-line' ;;
    3) printf 'assembly' ;;
    *) printf 'packaging' ;;
  esac
}

generate_demo_datasets() {
  local i site_idx site asset_id sensor_id criticality asset_type install_year
  local status temp_whole temp_frac priority wo_status summary event_type downtime resolved

  DEMO_ASSETS_JSON='['
  for i in $(seq 1 "$ASSETS_COUNT"); do
    asset_id="demo_asset-$(printf '%02d' "$i")"
    sensor_id="demo_sensor-$(printf '%02d' "$i")"
    site_idx=$((1 + ((i - 1) % 4)))
    site="$(site_name_from_idx "$site_idx")"
    install_year=$((2012 + (i % 11)))

    case $((i % 3)) in
      0) criticality="high" ;;
      1) criticality="medium" ;;
      2) criticality="low" ;;
    esac

    case $((i % 4)) in
      0) asset_type="compressor" ;;
      1) asset_type="pump" ;;
      2) asset_type="motor" ;;
      3) asset_type="conveyor" ;;
    esac

    if [ "$i" -gt 1 ]; then DEMO_ASSETS_JSON+=','; fi
    DEMO_ASSETS_JSON+="{\"asset_id\":\"$asset_id\",\"sensor_id\":\"$sensor_id\",\"site\":\"$site\",\"asset_type\":\"$asset_type\",\"criticality\":\"$criticality\",\"install_year\":$install_year}"
  done
  DEMO_ASSETS_JSON+=']'

  DEMO_SENSOR_READINGS_JSON='['
  for i in $(seq 1 "$RECORD_COUNT"); do
    local asset_idx
    asset_idx=$((1 + ((i - 1) % ASSETS_COUNT)))
    asset_id="demo_asset-$(printf '%02d' "$asset_idx")"
    sensor_id="demo_sensor-$(printf '%02d' "$asset_idx")"
    site_idx=$((1 + ((asset_idx - 1) % 4)))
    site="$(site_name_from_idx "$site_idx")"

    case $((i % 10)) in
      0|1|2|3|4|5) status="ok" ;;
      6|7) status="warn" ;;
      8|9) status="alert" ;;
    esac

    temp_whole=$((42 + (RANDOM % 45)))
    temp_frac=$((RANDOM % 100))

    if [ "$i" -gt 1 ]; then DEMO_SENSOR_READINGS_JSON+=','; fi
    DEMO_SENSOR_READINGS_JSON+="{\"reading_id\":$i,\"asset_id\":\"$asset_id\",\"sensor_id\":\"$sensor_id\",\"site\":\"$site\",\"temperature_c\":$temp_whole.$(printf '%02d' "$temp_frac"),\"status\":\"$status\"}"
  done
  DEMO_SENSOR_READINGS_JSON+=']'

  DEMO_WORK_ORDERS_JSON='['
  for i in $(seq 1 "$WORK_ORDERS_COUNT"); do
    local asset_idx
    asset_idx=$((1 + ((i - 1) % ASSETS_COUNT)))
    asset_id="demo_asset-$(printf '%02d' "$asset_idx")"

    case $((i % 3)) in
      0) priority="P1" ;;
      1) priority="P2" ;;
      2) priority="P3" ;;
    esac

    case $((i % 4)) in
      0) wo_status="open" ;;
      1) wo_status="in_progress" ;;
      2|3) wo_status="closed" ;;
    esac

    summary="Inspection batch $((1 + (i % 9)))"

    if [ "$i" -gt 1 ]; then DEMO_WORK_ORDERS_JSON+=','; fi
    DEMO_WORK_ORDERS_JSON+="{\"work_order_id\":$i,\"asset_id\":\"$asset_id\",\"priority\":\"$priority\",\"status\":\"$wo_status\",\"summary\":\"$summary\"}"
  done
  DEMO_WORK_ORDERS_JSON+=']'

  DEMO_MAINT_EVENTS_JSON='['
  for i in $(seq 1 "$MAINT_EVENTS_COUNT"); do
    local asset_idx
    asset_idx=$((1 + ((i - 1) % ASSETS_COUNT)))
    asset_id="demo_asset-$(printf '%02d' "$asset_idx")"

    case $((i % 4)) in
      0) event_type="inspection" ;;
      1) event_type="failure" ;;
      2) event_type="repair" ;;
      3) event_type="calibration" ;;
    esac

    downtime=$((8 + (RANDOM % 95)))
    case $((i % 5)) in
      0|1|2) resolved=1 ;;
      3|4) resolved=0 ;;
    esac

    if [ "$i" -gt 1 ]; then DEMO_MAINT_EVENTS_JSON+=','; fi
    DEMO_MAINT_EVENTS_JSON+="{\"event_id\":$i,\"asset_id\":\"$asset_id\",\"event_type\":\"$event_type\",\"downtime_min\":$downtime,\"resolved\":$resolved}"
  done
  DEMO_MAINT_EVENTS_JSON+=']'
}

wait_for_http() {
  local name="$1"
  local url="$2"
  local max_attempts="$3"
  local attempt=1

  while [ "$attempt" -le "$max_attempts" ]; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      log "$name is ready"
      return 0
    fi
    sleep 2
    attempt=$((attempt + 1))
  done

  die "$name did not become ready in time: $url"
}

seed_data() {
  local session_response auth_token list_tables_response create_table_response delete_table_response
  local create_table_code delete_table_code
  local insert_response verify_response verify_cursor_id

  recreate_table() {
    local t_name="$1"
    local t_fields="$2"
    local t_primary_keys="$3"

    if printf '%s' "$list_tables_response" | grep -Eq '"tableName"[[:space:]]*:[[:space:]]*"'"$t_name"'"'; then
      log "Dropping existing table $t_name"
      delete_table_response="$(api_call "{\"api\":\"db\",\"action\":\"deleteTables\",\"authToken\":\"$auth_token\",\"params\":{\"databaseName\":\"$EDGE_DATABASE\",\"ownerName\":\"$EDGE_OWNER\",\"tableNames\":[\"$t_name\"]}}")"
      delete_table_code="$(printf '%s' "$delete_table_response" | extract_error_code)"
      if [ "${delete_table_code:-1}" != "0" ]; then
        printf '%s\n' "$delete_table_response" >&2
        die "deleteTables returned an error for table $t_name"
      fi
    fi

    log "Creating table $t_name"
    create_table_response="$(api_call "{\"api\":\"db\",\"action\":\"createTable\",\"authToken\":\"$auth_token\",\"params\":{\"databaseName\":\"$EDGE_DATABASE\",\"ownerName\":\"$EDGE_OWNER\",\"tableName\":\"$t_name\",\"fields\":$t_fields,\"primaryKeyFields\":$t_primary_keys}}")"
    create_table_code="$(printf '%s' "$create_table_response" | extract_error_code)"
    if [ "${create_table_code:-1}" != "0" ]; then
      printf '%s\n' "$create_table_response" >&2
      die "createTable returned an error for table $t_name"
    fi
  }

  insert_table_data() {
    local t_name="$1"
    local t_data="$2"
    insert_response="$(api_call "{\"api\":\"db\",\"action\":\"insertRecords\",\"authToken\":\"$auth_token\",\"params\":{\"databaseName\":\"$EDGE_DATABASE\",\"ownerName\":\"$EDGE_OWNER\",\"tableName\":\"$t_name\",\"dataFormat\":\"objects\",\"sourceData\":$t_data}}")"
    if printf '%s' "$insert_response" | grep -Eq '"errorCode"[[:space:]]*:[[:space:]]*[1-9]'; then
      printf '%s\n' "$insert_response" >&2
      die "insertRecords returned an error for table $t_name"
    fi
  }

  verify_table_readable() {
    local t_name="$1"
    local attempt

    for attempt in 1 2 3; do
      verify_response="$(api_call "{\"api\":\"db\",\"action\":\"getRecordsByTable\",\"authToken\":\"$auth_token\",\"params\":{\"databaseName\":\"$EDGE_DATABASE\",\"ownerName\":\"$EDGE_OWNER\",\"tableName\":\"$t_name\",\"returnCursor\":true}}")"
      if printf '%s' "$verify_response" | grep -Eq '"errorCode"[[:space:]]*:[[:space:]]*[1-9]'; then
        printf '%s\n' "$verify_response" >&2
        die "Verification request returned an error for table $t_name"
      fi

      verify_cursor_id="$(printf '%s' "$verify_response" | tr -d '\n' | sed -n 's/.*"cursorId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
      if [ -z "$verify_cursor_id" ]; then
        printf '%s\n' "$verify_response" >&2
        die "Verification request did not return cursorId for table $t_name"
      fi

      verify_response="$(api_call "{\"api\":\"db\",\"action\":\"getRecordsFromCursor\",\"authToken\":\"$auth_token\",\"params\":{\"cursorId\":\"$verify_cursor_id\",\"startFrom\":\"beforeFirstRecord\",\"fetchRecords\":1}}")"
      if printf '%s' "$verify_response" | grep -Eq '"errorCode"[[:space:]]*:[[:space:]]*[1-9]'; then
        printf '%s\n' "$verify_response" >&2
        die "Verification cursor fetch returned an error for table $t_name"
      fi

      return 0
    done

    printf '%s\n' "$verify_response" >&2
    die "Unable to verify readable cursor response for table $t_name"
  }

  log "Creating FairCom session against $EDGE_JSON_API_URL"
  session_response="$(api_call "{\"api\":\"admin\",\"action\":\"createSession\",\"params\":{\"username\":\"$EDGE_USERNAME\",\"password\":\"$EDGE_PASSWORD\"}}")"
  auth_token="$(printf '%s' "$session_response" | extract_auth_token)"
  if [ -z "$auth_token" ]; then
    printf '%s\n' "$session_response" >&2
    die "Failed to create session"
  fi

  generate_demo_datasets

  list_tables_response="$(api_call "{\"api\":\"db\",\"action\":\"listTables\",\"authToken\":\"$auth_token\",\"params\":{\"databaseName\":\"$EDGE_DATABASE\",\"ownerName\":\"$EDGE_OWNER\"}}")"

  recreate_table "$DEMO_TABLE_ASSETS" '[{"name":"asset_id","type":"varchar","length":32},{"name":"sensor_id","type":"varchar","length":32},{"name":"site","type":"varchar","length":32},{"name":"asset_type","type":"varchar","length":24},{"name":"criticality","type":"varchar","length":16},{"name":"install_year","type":"integer"}]' '["asset_id"]'
  recreate_table "$DEMO_TABLE_READINGS" '[{"name":"reading_id","type":"bigint"},{"name":"asset_id","type":"varchar","length":32},{"name":"sensor_id","type":"varchar","length":32},{"name":"site","type":"varchar","length":32},{"name":"temperature_c","type":"float"},{"name":"status","type":"varchar","length":16}]' '["reading_id"]'
  recreate_table "$DEMO_TABLE_WORK_ORDERS" '[{"name":"work_order_id","type":"bigint"},{"name":"asset_id","type":"varchar","length":32},{"name":"priority","type":"varchar","length":8},{"name":"status","type":"varchar","length":24},{"name":"summary","type":"varchar","length":80}]' '["work_order_id"]'
  recreate_table "$DEMO_TABLE_MAINT_EVENTS" '[{"name":"event_id","type":"bigint"},{"name":"asset_id","type":"varchar","length":32},{"name":"event_type","type":"varchar","length":24},{"name":"downtime_min","type":"integer"},{"name":"resolved","type":"bit"}]' '["event_id"]'

  log "Loading generated demo records"
  insert_table_data "$DEMO_TABLE_ASSETS" "$DEMO_ASSETS_JSON"
  insert_table_data "$DEMO_TABLE_READINGS" "$DEMO_SENSOR_READINGS_JSON"
  insert_table_data "$DEMO_TABLE_WORK_ORDERS" "$DEMO_WORK_ORDERS_JSON"
  insert_table_data "$DEMO_TABLE_MAINT_EVENTS" "$DEMO_MAINT_EVENTS_JSON"

  verify_table_readable "$DEMO_TABLE_ASSETS"
  verify_table_readable "$DEMO_TABLE_READINGS"
  verify_table_readable "$DEMO_TABLE_WORK_ORDERS"
  verify_table_readable "$DEMO_TABLE_MAINT_EVENTS"

  log "Seed complete"
  log "  assets: $ASSETS_COUNT"
  log "  sensor readings: $RECORD_COUNT"
  log "  work orders: $WORK_ORDERS_COUNT"
  log "  maintenance events: $MAINT_EVENTS_COUNT"
}

cmd_setup() {
  require_cmd docker
  require_cmd curl

  log "Starting FairCom Edge and FairCom MCP containers"
  docker compose up -d

  wait_for_http "FairCom Edge" "$EDGE_HTTP_URL" 90
  wait_for_http "FairCom MCP" "$MCP_BASE_URL/health" 90
}

cmd_seed() {
  require_cmd curl
  require_cmd sed
  require_cmd grep
  require_cmd tr
  require_cmd seq

  wait_for_http "FairCom Edge" "$EDGE_HTTP_URL" 45
  seed_data
}

cmd_start() {
  cmd_setup
  cmd_seed
  log "Environment is ready for Claude Desktop"
}

cmd_stop() {
  require_cmd docker
  log "Stopping containers"
  docker compose down --remove-orphans
}

cmd_status() {
  require_cmd docker
  docker compose ps
}

usage() {
  cat <<EOF
Usage: ./demo.sh [--setup|--seed|--stop|--status|--help]

Default:
  --setup + --seed

Options:
  --setup   Start Docker services and wait for readiness
  --seed    Create and seed demo tables only
  --stop    Stop Docker services
  --status  Show Docker service status
  --help    Show this help

Environment overrides:
  EDGE_JSON_API_URL=http://127.0.0.1:8080/api
  EDGE_HTTP_URL=http://127.0.0.1:8080/
  MCP_BASE_URL=http://127.0.0.1:8000
  EDGE_USERNAME=ADMIN
  EDGE_PASSWORD=ADMIN
  EDGE_DATABASE=faircom
  EDGE_OWNER=admin
  ASSETS_COUNT=120
  RECORD_COUNT=6000
  WORK_ORDERS_COUNT=1800
  MAINT_EVENTS_COUNT=2400
EOF
}

main() {
  local opt="${1:-}"
  case "$opt" in
    "" ) cmd_start ;;
    --setup ) cmd_setup ;;
    --seed ) cmd_seed ;;
    --stop ) cmd_stop ;;
    --status ) cmd_status ;;
    --help|-h ) usage ;;
    * ) usage; exit 1 ;;
  esac
}

main "$@"
