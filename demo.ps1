#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptRoot

$EdgeJsonApiUrl = if ($env:EDGE_JSON_API_URL) { $env:EDGE_JSON_API_URL } else { 'http://127.0.0.1:8080/api' }
$EdgeHttpUrl = if ($env:EDGE_HTTP_URL) { $env:EDGE_HTTP_URL } else { 'http://127.0.0.1:8080/' }
$McpBaseUrl = if ($env:MCP_BASE_URL) { $env:MCP_BASE_URL } else { 'http://127.0.0.1:8000' }
$EdgeUsername = if ($env:EDGE_USERNAME) { $env:EDGE_USERNAME } else { 'ADMIN' }
$EdgePassword = if ($env:EDGE_PASSWORD) { $env:EDGE_PASSWORD } else { 'ADMIN' }
$EdgeDatabase = if ($env:EDGE_DATABASE) { $env:EDGE_DATABASE } else { 'faircom' }
$EdgeOwner = if ($env:EDGE_OWNER) { $env:EDGE_OWNER } else { 'admin' }
$EnableModbusSim = if ($env:ENABLE_MODBUS_SIM) { [int]$env:ENABLE_MODBUS_SIM } else { 0 }

$DemoTableAssets = 'demo_assets'
$DemoTableReadings = 'demo_sensor_readings'
$DemoTableWorkOrders = 'demo_work_orders'
$DemoTableMaintEvents = 'demo_maintenance_events'

$AssetsCount = [int](($env:ASSETS_COUNT, '120' | Where-Object { $_ } | Select-Object -First 1))
$RecordCount = [int](($env:RECORD_COUNT, '6000' | Where-Object { $_ } | Select-Object -First 1))
$WorkOrdersCount = [int](($env:WORK_ORDERS_COUNT, '1800' | Where-Object { $_ } | Select-Object -First 1))
$MaintEventsCount = [int](($env:MAINT_EVENTS_COUNT, '2400' | Where-Object { $_ } | Select-Object -First 1))

$DemoAssetsJson = ''
$DemoSensorReadingsJson = ''
$DemoWorkOrdersJson = ''
$DemoMaintEventsJson = ''

function Write-Log([string]$Message) {
  Write-Host "[demo] $Message"
}

function Fail([string]$Message) {
  Write-Error "[demo] ERROR: $Message"
  exit 1
}

function Assert-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    Fail "Missing required command: $Name"
  }
}

function Invoke-ApiJson([object]$Payload) {
  $json = if ($Payload -is [string]) { $Payload } else { $Payload | ConvertTo-Json -Compress -Depth 20 }
  $response = Invoke-WebRequest -Uri $EdgeJsonApiUrl -Method Post -ContentType 'application/json' -Body $json -ErrorAction Stop
  if ($response.Content) {
    try {
      return $response.Content | ConvertFrom-Json
    } catch {
      return $response.Content
    }
  }
  return $null
}

function Invoke-ApiJsonString([string]$Json) {
  $response = Invoke-WebRequest -Uri $EdgeJsonApiUrl -Method Post -ContentType 'application/json' -Body $Json -ErrorAction Stop
  if ($response.Content) {
    try {
      return $response.Content | ConvertFrom-Json
    } catch {
      return $response.Content
    }
  }
  return $null
}

function Get-JsonValue([object]$Object, [string]$Name) {
  if ($null -eq $Object) { return $null }

  if ($Object -is [System.Collections.IDictionary]) {
    if ($Object.Contains($Name)) { return $Object[$Name] }
    if ($Object.Contains('result')) {
      return Get-JsonValue $Object['result'] $Name
    }
    return $null
  }

  $property = $Object.PSObject.Properties[$Name]
  if ($null -ne $property) { return $property.Value }

  $resultProperty = $Object.PSObject.Properties['result']
  if ($null -ne $resultProperty) {
    return Get-JsonValue $resultProperty.Value $Name
  }

  return $null
}

function Get-ErrorCode([object]$Object) {
  $raw = Get-JsonValue $Object 'errorCode'
  if ($null -eq $raw) { return $null }
  return [string]$raw
}

function Get-AuthToken([object]$Object) {
  return [string](Get-JsonValue $Object 'authToken')
}

function Site-Name-From-Index([int]$Index) {
  switch ($Index) {
    1 { return 'north-line' }
    2 { return 'south-line' }
    3 { return 'assembly' }
    default { return 'packaging' }
  }
}

function Generate-Demo-Datasets {
  $assetObjects = @()
  for ($i = 1; $i -le $AssetsCount; $i++) {
    $assetId = "demo_asset-$([string]::Format('{0:00}', $i))"
    $sensorId = "demo_sensor-$([string]::Format('{0:00}', $i))"
    $siteIndex = 1 + (($i - 1) % 4)
    $site = Site-Name-From-Index $siteIndex
    $installYear = 2012 + ($i % 11)

    $criticality = switch ($i % 3) {
      0 { 'high' }
      1 { 'medium' }
      default { 'low' }
    }

    $assetType = switch ($i % 4) {
      0 { 'compressor' }
      1 { 'pump' }
      2 { 'motor' }
      default { 'conveyor' }
    }

    $assetObjects += [PSCustomObject]@{
      asset_id = $assetId
      sensor_id = $sensorId
      site = $site
      asset_type = $assetType
      criticality = $criticality
      install_year = $installYear
    }
  }
  $script:DemoAssetsJson = ($assetObjects | ConvertTo-Json -Compress -Depth 10)

  $sensorObjects = @()
  for ($i = 1; $i -le $RecordCount; $i++) {
    $assetIndex = 1 + (($i - 1) % $AssetsCount)
    $assetId = "demo_asset-$([string]::Format('{0:00}', $assetIndex))"
    $sensorId = "demo_sensor-$([string]::Format('{0:00}', $assetIndex))"
    $siteIndex = 1 + (($assetIndex - 1) % 4)
    $site = Site-Name-From-Index $siteIndex

    $status = switch ($i % 10) {
      0 { 'ok' }
      1 { 'ok' }
      2 { 'ok' }
      3 { 'ok' }
      4 { 'ok' }
      5 { 'ok' }
      6 { 'warn' }
      7 { 'warn' }
      8 { 'alert' }
      default { 'alert' }
    }

    $tempWhole = 42 + (Get-Random -Minimum 0 -Maximum 45)
    $tempFrac = Get-Random -Minimum 0 -Maximum 99
    $tempValue = [double]::Parse("$tempWhole.$([string]::Format('{0:00}', $tempFrac))")

    $sensorObjects += [PSCustomObject]@{
      reading_id = $i
      asset_id = $assetId
      sensor_id = $sensorId
      site = $site
      temperature_c = $tempValue
      status = $status
    }
  }
  $script:DemoSensorReadingsJson = ($sensorObjects | ConvertTo-Json -Compress -Depth 10)

  $workOrderObjects = @()
  for ($i = 1; $i -le $WorkOrdersCount; $i++) {
    $assetIndex = 1 + (($i - 1) % $AssetsCount)
    $assetId = "demo_asset-$([string]::Format('{0:00}', $assetIndex))"

    $priority = switch ($i % 3) {
      0 { 'P1' }
      1 { 'P2' }
      default { 'P3' }
    }

    $woStatus = switch ($i % 4) {
      0 { 'open' }
      1 { 'in_progress' }
      default { 'closed' }
    }

    $summary = "Inspection batch $((1 + ($i % 9)))"

    $workOrderObjects += [PSCustomObject]@{
      work_order_id = $i
      asset_id = $assetId
      priority = $priority
      status = $woStatus
      summary = $summary
    }
  }
  $script:DemoWorkOrdersJson = ($workOrderObjects | ConvertTo-Json -Compress -Depth 10)

  $maintEventObjects = @()
  for ($i = 1; $i -le $MaintEventsCount; $i++) {
    $assetIndex = 1 + (($i - 1) % $AssetsCount)
    $assetId = "demo_asset-$([string]::Format('{0:00}', $assetIndex))"

    $eventType = switch ($i % 4) {
      0 { 'inspection' }
      1 { 'failure' }
      2 { 'repair' }
      default { 'calibration' }
    }

    $downtimeMin = 8 + (Get-Random -Minimum 0 -Maximum 95)
    $resolved = if (($i % 5) -in 0,1,2) { 1 } else { 0 }

    $maintEventObjects += [PSCustomObject]@{
      event_id = $i
      asset_id = $assetId
      event_type = $eventType
      downtime_min = $downtimeMin
      resolved = $resolved
    }
  }
  $script:DemoMaintEventsJson = ($maintEventObjects | ConvertTo-Json -Compress -Depth 10)
}

function Wait-For-Http([string]$Name, [string]$Url, [int]$MaxAttempts) {
  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    try {
      Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 5 | Out-Null
      Write-Log "$Name is ready"
      return
    } catch {
      Start-Sleep -Seconds 2
    }
  }

  Fail "$Name did not become ready in time: $Url"
}

function Wait-For-Tcp([string]$Name, [string]$Host, [int]$Port, [int]$MaxAttempts) {
  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    $client = $null
    try {
      $client = [System.Net.Sockets.TcpClient]::new()
      $result = $client.BeginConnect($Host, $Port, $null, $null)
      if ($result.AsyncWaitHandle.WaitOne(1000) -and $client.Connected) {
        $client.EndConnect($result)
        Write-Log "$Name is ready"
        return
      }
    } catch {
    } finally {
      if ($null -ne $client) {
        $client.Dispose()
      }
    }
    Start-Sleep -Seconds 2
  }

  Fail "$Name did not become ready in time: ${Host}:${Port}"
}

function Seed-Data {
  $sessionResponse = Invoke-ApiJson (@{
    api = 'admin'
    action = 'createSession'
    params = @{ username = $EdgeUsername; password = $EdgePassword }
  })
  $authToken = Get-AuthToken $sessionResponse
  if ([string]::IsNullOrWhiteSpace($authToken)) {
    Write-Output $sessionResponse | Out-String | Write-Error
    Fail 'Failed to create session'
  }

  Generate-Demo-Datasets

  $listTablesResponse = Invoke-ApiJson (@{
    api = 'db'
    action = 'listTables'
    authToken = $authToken
    params = @{ databaseName = $EdgeDatabase; ownerName = $EdgeOwner }
  })
  $listTablesText = ($listTablesResponse | ConvertTo-Json -Compress -Depth 20)

  function Recreate-Table([string]$TableName, [string]$Fields, [string]$PrimaryKeys) {
    $tablePattern = [Regex]::Escape("`"tableName`":`"$TableName`"")
    if ($listTablesText -match $tablePattern) {
      Write-Log "Dropping existing table $TableName"
      $deleteResponse = Invoke-ApiJson (@{
        api = 'db'
        action = 'deleteTables'
        authToken = $authToken
        params = @{ databaseName = $EdgeDatabase; ownerName = $EdgeOwner; tableNames = @($TableName) }
      })
      if ((Get-ErrorCode $deleteResponse) -ne '0') {
        Write-Output $deleteResponse | Out-String | Write-Error
        Fail "deleteTables returned an error for table $TableName"
      }
    }

    Write-Log "Creating table $TableName"
    $createPayload = '{"api":"db","action":"createTable","authToken":"' + $authToken + '","params":{"databaseName":"' + $EdgeDatabase + '","ownerName":"' + $EdgeOwner + '","tableName":"' + $TableName + '","fields":' + $Fields + ',"primaryKeyFields":' + $PrimaryKeys + '}}'
    $createResponse = Invoke-ApiJsonString $createPayload
    if ((Get-ErrorCode $createResponse) -ne '0') {
      Write-Output $createResponse | Out-String | Write-Error
      Fail "createTable returned an error for table $TableName"
    }
  }

  function Insert-Table-Data([string]$TableName, [string]$Data) {
    $insertPayload = '{"api":"db","action":"insertRecords","authToken":"' + $authToken + '","params":{"databaseName":"' + $EdgeDatabase + '","ownerName":"' + $EdgeOwner + '","tableName":"' + $TableName + '","dataFormat":"objects","sourceData":' + $Data + '}}'
    $insertResponse = Invoke-ApiJsonString $insertPayload
    if ((Get-ErrorCode $insertResponse) -and (Get-ErrorCode $insertResponse) -ne '0') {
      Write-Output $insertResponse | Out-String | Write-Error
      Fail "insertRecords returned an error for table $TableName"
    }
  }

  function Verify-Table-Readable([string]$TableName) {
    $verifyResponse = Invoke-ApiJson (@{
      api = 'db'
      action = 'getRecordsByTable'
      authToken = $authToken
      params = @{ databaseName = $EdgeDatabase; ownerName = $EdgeOwner; tableName = $TableName; returnCursor = $true }
    })
    if ((Get-ErrorCode $verifyResponse) -and (Get-ErrorCode $verifyResponse) -ne '0') {
      Write-Output $verifyResponse | Out-String | Write-Error
      Fail "Verification request returned an error for table $TableName"
    }

    $cursorId = Get-JsonValue $verifyResponse 'cursorId'
    if ([string]::IsNullOrWhiteSpace($cursorId)) {
      Write-Log "Verification response for $TableName did not include a cursorId; continuing"
      return
    }

    $cursorResponse = Invoke-ApiJson (@{
      api = 'db'
      action = 'getRecordsFromCursor'
      authToken = $authToken
      params = @{ cursorId = $cursorId; startFrom = 'beforeFirstRecord'; fetchRecords = 1 }
    })

    if ((Get-ErrorCode $cursorResponse) -and (Get-ErrorCode $cursorResponse) -ne '0') {
      Write-Output $cursorResponse | Out-String | Write-Error
      Fail "Verification cursor fetch returned an error for table $TableName"
    }
  }

  Recreate-Table $DemoTableAssets '[{"name":"asset_id","type":"varchar","length":32},{"name":"sensor_id","type":"varchar","length":32},{"name":"site","type":"varchar","length":32},{"name":"asset_type","type":"varchar","length":24},{"name":"criticality","type":"varchar","length":16},{"name":"install_year","type":"integer"}]' '["asset_id"]'
  Recreate-Table $DemoTableReadings '[{"name":"reading_id","type":"bigint"},{"name":"asset_id","type":"varchar","length":32},{"name":"sensor_id","type":"varchar","length":32},{"name":"site","type":"varchar","length":32},{"name":"temperature_c","type":"float"},{"name":"status","type":"varchar","length":16}]' '["reading_id"]'
  Recreate-Table $DemoTableWorkOrders '[{"name":"work_order_id","type":"bigint"},{"name":"asset_id","type":"varchar","length":32},{"name":"priority","type":"varchar","length":8},{"name":"status","type":"varchar","length":24},{"name":"summary","type":"varchar","length":80}]' '["work_order_id"]'
  Recreate-Table $DemoTableMaintEvents '[{"name":"event_id","type":"bigint"},{"name":"asset_id","type":"varchar","length":32},{"name":"event_type","type":"varchar","length":24},{"name":"downtime_min","type":"integer"},{"name":"resolved","type":"bit"}]' '["event_id"]'

  Write-Log 'Loading generated demo records'
  Insert-Table-Data $DemoTableAssets $DemoAssetsJson
  Insert-Table-Data $DemoTableReadings $DemoSensorReadingsJson
  Insert-Table-Data $DemoTableWorkOrders $DemoWorkOrdersJson
  Insert-Table-Data $DemoTableMaintEvents $DemoMaintEventsJson

  Verify-Table-Readable $DemoTableAssets
  Verify-Table-Readable $DemoTableReadings
  Verify-Table-Readable $DemoTableWorkOrders
  Verify-Table-Readable $DemoTableMaintEvents

  Write-Log 'Seed complete'
  Write-Log "  assets: $AssetsCount"
  Write-Log "  sensor readings: $RecordCount"
  Write-Log "  work orders: $WorkOrdersCount"
  Write-Log "  maintenance events: $MaintEventsCount"
}

function Cmd-Setup {
  Assert-Command docker

  if ($EnableModbusSim -eq 1) {
    Write-Log 'Starting FairCom Edge, FairCom MCP, and optional Modbus simulator containers'
    $env:COMPOSE_PROFILES = 'modbus-sim'
    & docker compose up -d
    Remove-Item Env:COMPOSE_PROFILES -ErrorAction SilentlyContinue
  } else {
    Write-Log 'Starting FairCom Edge and FairCom MCP containers'
    & docker compose up -d
  }

  Wait-For-Http 'FairCom Edge' "$EdgeHttpUrl" 90
  Wait-For-Http 'FairCom MCP' "$McpBaseUrl/health" 90

  if ($EnableModbusSim -eq 1) {
    Wait-For-Tcp 'Modbus simulator' '127.0.0.1' 1502 45
    Write-Log 'Modbus simulator endpoint: localhost:1502 (Docker network: modbus-sim:1502)'
  }
}

function Cmd-Seed {
  Assert-Command docker
  Wait-For-Http 'FairCom Edge' "$EdgeHttpUrl" 45
  Seed-Data
}

function Cmd-Start {
  Cmd-Setup
  Write-Log 'Environment is ready'
}

function Cmd-StartWithSeed {
  Cmd-Setup
  Cmd-Seed
  Write-Log 'Environment is ready with sample ERP dataset'
}

function Cmd-Stop {
  Assert-Command docker
  Write-Log 'Stopping containers'
  & docker compose down --remove-orphans
  $env:COMPOSE_PROFILES = 'modbus-sim'
  & docker compose down --remove-orphans | Out-Null
  Remove-Item Env:COMPOSE_PROFILES -ErrorAction SilentlyContinue
}

function Cmd-Status {
  Assert-Command docker
  $env:COMPOSE_PROFILES = 'modbus-sim'
  & docker compose ps
  Remove-Item Env:COMPOSE_PROFILES -ErrorAction SilentlyContinue
}

function Show-Usage {
  Write-Host @"
Usage: ./demo.ps1 [--modbus] [--seed] [--setup|--stop|--status|--help]

Default:
  setup only (no sample ERP seed)

Options:
  --setup   Start Docker services and wait for readiness
  --modbus  Include Modbus simulator in startup
  --seed    Load sample ERP dataset tables after setup
  --stop    Stop Docker services
  --status  Show Docker service status
  --help    Show this help

Simple rule:
  default = setup only
  --seed = setup + sample ERP dataset
  --modbus = setup + Modbus simulator
  --modbus --seed = setup + Modbus simulator + sample ERP dataset

Advanced:
  ./demo.ps1 --seed-only    # load sample ERP dataset into already-running Edge only

Environment overrides:
  EDGE_JSON_API_URL=http://127.0.0.1:8080/api
  EDGE_HTTP_URL=http://127.0.0.1:8080/
  MCP_BASE_URL=http://127.0.0.1:8000
  EDGE_USERNAME=ADMIN
  EDGE_PASSWORD=ADMIN
  EDGE_DATABASE=faircom
  EDGE_OWNER=admin
  ENABLE_MODBUS_SIM=0
  ASSETS_COUNT=120
  RECORD_COUNT=6000
  WORK_ORDERS_COUNT=1800
  MAINT_EVENTS_COUNT=2400
"@
}

$mode = 'start'
$doSeed = $false

foreach ($arg in $args) {
  switch ($arg) {
    '--setup' { }
    '--modbus' { $EnableModbusSim = 1 }
    '--seed' { $doSeed = $true }
    '--seed-only' { $mode = 'seed-only' }
    '--setup-with-modbus' { $EnableModbusSim = 1 }
    '--setup-only-with-modbus' { $EnableModbusSim = 1 }
    '--with-modbus' { $EnableModbusSim = 1; $doSeed = $true }
    '--start-with-modbus' { $EnableModbusSim = 1; $doSeed = $true }
    '--stop' { $mode = 'stop' }
    '--status' { $mode = 'status' }
    '--help' { $mode = 'help' }
    '-h' { $mode = 'help' }
    default { Show-Usage; exit 1 }
  }
}

switch ($mode) {
  'start' {
    if ($doSeed) {
      Cmd-StartWithSeed
    } else {
      Cmd-Start
    }
  }
  'seed-only' { Cmd-Seed }
  'stop' { Cmd-Stop }
  'status' { Cmd-Status }
  'help' { Show-Usage }
  default { Show-Usage; exit 1 }
}
