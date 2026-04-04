param(
  [switch]$UseReload
)

$ErrorActionPreference = "Stop"

function Get-PythonCommand {
  param([string]$ProjectDir)

  $venvPython = Join-Path $ProjectDir "venv\Scripts\python.exe"
  if (Test-Path $venvPython) {
    return "& `"$venvPython`""
  }
  return "python"
}

function Start-BackendWindow {
  param(
    [string]$Name,
    [string]$ProjectDir,
    [string]$Command
  )

  $cmd = @"
Set-Location '$ProjectDir'
$Command
"@

  Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-ExecutionPolicy", "Bypass",
    "-Command", $cmd
  ) | Out-Null

  Write-Host "Started $Name"
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$chathuryaDir = Join-Path $root "Chathurya"
$dataDir = Join-Path $root "data"
$itDir = Join-Path $root "IT22573414_gallage"
$carCareDir = Join-Path $root "car_care_services"

$reloadFlag = if ($UseReload) { "--reload" } else { "" }

$chathuryaPy = Get-PythonCommand -ProjectDir $chathuryaDir
$dataPy = Get-PythonCommand -ProjectDir $dataDir
$itPy = Get-PythonCommand -ProjectDir $itDir
$carCarePy = Get-PythonCommand -ProjectDir $carCareDir

# Chathurya backend -> 8000
$chathuryaCmd = "$chathuryaPy -m uvicorn 3_app:app --host 0.0.0.0 --port 8000 $reloadFlag"

# data backend -> 8001
# Keep Firebase disabled for local testing, matching existing run_server.bat behavior.
$dataCmd = '$env:ENABLE_FIREBASE="0"; ' +
           "$dataPy -m uvicorn src.api.api_server:app --host 0.0.0.0 --port 8001 $reloadFlag"

# IT22573414_gallage backend -> 8002
$itCmd = "$itPy -m uvicorn main:app --host 0.0.0.0 --port 8002 $reloadFlag"

# car_care_services backend -> 8003
$carCareCmd = "$carCarePy -m uvicorn main:app --host 0.0.0.0 --port 8003 $reloadFlag"

Start-BackendWindow -Name "Chathurya (8000)" -ProjectDir $chathuryaDir -Command $chathuryaCmd
Start-BackendWindow -Name "data (8001)" -ProjectDir $dataDir -Command $dataCmd
Start-BackendWindow -Name "IT22573414_gallage (8002)" -ProjectDir $itDir -Command $itCmd
Start-BackendWindow -Name "car_care_services (8003)" -ProjectDir $carCareDir -Command $carCareCmd

Write-Host ""
Write-Host "All backend windows started:"
Write-Host "  Chathurya -> http://127.0.0.1:8000/docs"
Write-Host "  data -> http://127.0.0.1:8001/docs"
Write-Host "  IT22573414_gallage -> http://127.0.0.1:8002/docs"
Write-Host "  car_care_services -> http://127.0.0.1:8003/docs"
