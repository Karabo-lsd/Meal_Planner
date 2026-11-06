param(
    [string]$DeviceId,
    [switch]$TunnelOnly
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

$adbCommand = Get-Command adb -ErrorAction SilentlyContinue
$adb = if ($adbCommand) { $adbCommand.Source } else { $null }

if (-not $adb) {
    $sdkRoots = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
    ) | Where-Object { $_ }

    foreach ($sdkRoot in $sdkRoots) {
        $candidate = Join-Path $sdkRoot 'platform-tools\adb.exe'
        if (Test-Path $candidate) {
            $adb = $candidate
            break
        }
    }
}

if (-not $adb) {
    throw 'Android platform-tools were not found. Install Android SDK Platform-Tools or add adb to PATH.'
}

$deviceLines = @(& $adb devices -l)
if ($LASTEXITCODE -ne 0) {
    throw 'Could not query Android devices through adb.'
}
$physicalDevices = @(
    $deviceLines |
        Where-Object {
            $_ -match '^\S+\s+device\s+' -and
            ($_ -split '\s+')[0] -notlike 'emulator-*'
        } |
        ForEach-Object { ($_ -split '\s+')[0] }
)

if ($DeviceId) {
    if ($physicalDevices -notcontains $DeviceId) {
        throw "Device '$DeviceId' is not listed as an authorized physical Android device. Check the USB cable and debugging authorization."
    }
} elseif ($physicalDevices.Count -eq 1) {
    $DeviceId = $physicalDevices[0]
} elseif ($physicalDevices.Count -gt 1) {
    throw "More than one physical Android device is connected ($($physicalDevices -join ', ')). Rerun with -DeviceId <serial>."
} else {
    throw 'No authorized physical Android device found. Connect the phone with a data-capable USB cable and enable USB debugging.'
}

try {
    $health = Invoke-RestMethod -Uri 'http://127.0.0.1:8000/health' -TimeoutSec 5
    if ($health.status -ne 'healthy') {
        throw 'Unexpected backend health response.'
    }
} catch {
    throw 'The backend is not healthy at http://127.0.0.1:8000. Start backend/docker-compose.yml first.'
}

& $adb -s $DeviceId reverse tcp:8000 tcp:8000
if ($LASTEXITCODE -ne 0) {
    throw "Could not create the USB reverse tunnel for device '$DeviceId'."
}

$forwarding = @(& $adb -s $DeviceId reverse --list)
if ($LASTEXITCODE -ne 0 -or -not ($forwarding -match 'tcp:8000\s+tcp:8000')) {
    throw 'adb did not confirm the backend USB tunnel (tcp:8000 -> tcp:8000).'
}

if ($TunnelOnly) {
    Write-Host "USB tunnel ready for ${DeviceId}: device localhost:8000 -> computer localhost:8000"
    exit 0
}

Write-Host "USB tunnel ready for ${DeviceId}: device localhost:8000 -> computer localhost:8000"
Set-Location $repositoryRoot
& flutter run --device-id $DeviceId --dart-define=API_BASE_URL=http://127.0.0.1:8000 --dart-define=API_USB_ONLY=true
exit $LASTEXITCODE
