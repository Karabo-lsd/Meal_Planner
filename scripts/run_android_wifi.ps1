param(
    [string]$DeviceId,
    [string]$ServerAddress
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
$devices = @(
    $deviceLines |
        Where-Object {
            $_ -match '^\S+\s+device\s+' -and
            ($_ -split '\s+')[0] -notlike 'emulator-*'
        } |
        ForEach-Object { ($_ -split '\s+')[0] }
)
if ($DeviceId) {
    if ($devices -notcontains $DeviceId) {
        throw "Device '$DeviceId' is not listed as an authorized Android device."
    }
} elseif ($devices.Count -eq 1) {
    $DeviceId = $devices[0]
} elseif ($devices.Count -gt 1) {
    throw "More than one Android device is connected ($($devices -join ', ')). Rerun with -DeviceId <serial>."
} else {
    throw 'No authorized Android device found. Connect it by USB or Android wireless debugging to install the app.'
}

if (-not $ServerAddress) {
    $wifiAdapters = @(
        Get-NetIPConfiguration |
            Where-Object {
                $_.InterfaceAlias -match 'Wi-?Fi' -and
                $_.IPv4DefaultGateway -and
                $_.IPv4Address
            }
    )
    if ($wifiAdapters.Count -ne 1) {
        throw 'Could not identify one active Wi-Fi IPv4 address. Rerun with -ServerAddress <PC Wi-Fi IPv4 address>.'
    }
    $ServerAddress = $wifiAdapters[0].IPv4Address[0].IPAddress
}

$parsedAddress = $null
if (-not [System.Net.IPAddress]::TryParse($ServerAddress, [ref]$parsedAddress) -or
    $parsedAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
    throw "ServerAddress '$ServerAddress' is not a valid IPv4 address."
}

$apiUrl = "http://${ServerAddress}:8000"
try {
    $health = Invoke-RestMethod -Uri "$apiUrl/health" -TimeoutSec 5
    if ($health.status -ne 'healthy') {
        throw 'Unexpected backend health response.'
    }
} catch {
    throw "Backend health check failed at $apiUrl/health. Ensure the API is listening on the Wi-Fi interface and Windows Firewall allows inbound TCP port 8000."
}

Set-Location $repositoryRoot
& flutter build apk --debug "--dart-define=API_BASE_URL=$apiUrl"
if ($LASTEXITCODE -ne 0) {
    throw 'Flutter failed to build the Wi-Fi-configured Android APK.'
}

$apkPath = Join-Path $repositoryRoot 'build\app\outputs\flutter-apk\app-debug.apk'
& $adb -s $DeviceId install -r $apkPath
if ($LASTEXITCODE -ne 0) {
    throw "Could not install the app on device '$DeviceId'."
}

& $adb -s $DeviceId shell monkey -p com.example.system 1
if ($LASTEXITCODE -ne 0) {
    throw "Could not launch the app on device '$DeviceId'."
}

Write-Host "Meal Planner is running on device $DeviceId and will reach the PC at $apiUrl."
Write-Host 'The USB cable can now be disconnected; the phone and PC must remain on the same Wi-Fi.'
