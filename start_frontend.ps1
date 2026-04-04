$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$appDir = Join-Path $root "vehicle_app"

Set-Location $appDir

# Reverse all backend ports to USB-connected Android device (safe if repeated).
adb reverse tcp:8000 tcp:8000 | Out-Null
adb reverse tcp:8001 tcp:8001 | Out-Null
adb reverse tcp:8002 tcp:8002 | Out-Null

flutter run
