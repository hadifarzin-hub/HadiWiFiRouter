Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Import-WinRTRuntime {
    # Windows PowerShell 5.1 does not always preload the assembly that exposes
    # System.WindowsRuntimeSystemExtensions. Load it explicitly before awaiting WinRT APIs.
    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop
    } catch {
        $runtimeDll = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\System.Runtime.WindowsRuntime.dll'
        if (-not (Test-Path $runtimeDll)) {
            $runtimeDll = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\System.Runtime.WindowsRuntime.dll'
        }
        if (Test-Path $runtimeDll) {
            Add-Type -Path $runtimeDll -ErrorAction Stop
        } else {
            throw "Windows Runtime bridge could not be loaded. System.Runtime.WindowsRuntime.dll was not found. $($_.Exception.Message)"
        }
    }
    $t = [Type]::GetType('System.WindowsRuntimeSystemExtensions, System.Runtime.WindowsRuntime', $false)
    if (-not $t) {
        try { $t = [System.WindowsRuntimeSystemExtensions] } catch { }
    }
    if (-not $t) { throw 'Windows Runtime bridge loaded, but System.WindowsRuntimeSystemExtensions is unavailable.' }
    return $t
}

function Import-WinRTTypes {
    [void](Import-WinRTRuntime)
    [void][Windows.Networking.Connectivity.NetworkInformation, Windows.Networking.Connectivity, ContentType=WindowsRuntime]
    [void][Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager, Windows.Networking.NetworkOperators, ContentType=WindowsRuntime]
    [void][Windows.Networking.NetworkOperators.NetworkOperatorTetheringAccessPointConfiguration, Windows.Networking.NetworkOperators, ContentType=WindowsRuntime]
    [void][Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult, Windows.Networking.NetworkOperators, ContentType=WindowsRuntime]
}

function Await-WinRT {
    param(
        [Parameter(Mandatory=$true)]$Operation,
        [Parameter(Mandatory=$true)][Type]$ResultType
    )
    $extType = Import-WinRTRuntime
    $methods = $extType.GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1
    }
    $method = $methods | Select-Object -First 1
    if (-not $method) { throw 'Could not find AsTask<T>(IAsyncOperation<T>) in the Windows Runtime bridge.' }
    $generic = $method.MakeGenericMethod($ResultType)
    $task = $generic.Invoke($null, @($Operation))
    $task.GetAwaiter().GetResult() | Out-Null
    return $task.Result
}

function Await-WinRTAction {
    param([Parameter(Mandatory=$true)]$Operation)
    $extType = Import-WinRTRuntime
    $method = $extType.GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and -not $_.IsGenericMethod -and $_.GetParameters().Count -eq 1
    } | Select-Object -First 1
    if (-not $method) { throw 'Could not find AsTask(IAsyncAction) in the Windows Runtime bridge.' }
    $task = $method.Invoke($null, @($Operation))
    $task.GetAwaiter().GetResult() | Out-Null
}

function Get-InternetProfile {
    Import-WinRTTypes
    $profile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
    if (-not $profile) { throw 'Windows reports no active Internet connection profile.' }
    return $profile
}

function Get-TetheringManager {
    $profile = Get-InternetProfile
    try {
        return [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager]::CreateFromConnectionProfile($profile)
    } catch {
        throw "Unable to create Windows tethering manager from the current Internet profile. $($_.Exception.Message)"
    }
}

function Set-HotspotConfiguration {
    param([string]$SSID, [string]$Password)
    if ([string]::IsNullOrWhiteSpace($SSID)) { throw 'SSID cannot be blank.' }
    if ([string]::IsNullOrEmpty($Password) -or $Password.Length -lt 8) { throw 'Wi-Fi password must be at least 8 characters.' }
    $manager = Get-TetheringManager
    $cfg = New-Object Windows.Networking.NetworkOperators.NetworkOperatorTetheringAccessPointConfiguration
    $cfg.Ssid = $SSID
    $cfg.Passphrase = $Password
    Await-WinRTAction ($manager.ConfigureAccessPointAsync($cfg))
    return $manager
}

function Start-Hotspot {
    param([string]$SSID, [string]$Password)
    $manager = Set-HotspotConfiguration -SSID $SSID -Password $Password
    try {
        $disableOp = $manager.DisableNoConnectionsTimeoutAsync()
        # Depending on Windows build this API can surface as an action or operation.
        try { Await-WinRTAction $disableOp } catch { }
    } catch { }
    $resultType = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult]
    $result = Await-WinRT ($manager.StartTetheringAsync()) $resultType
    return [pscustomobject]@{
        Status = $result.Status.ToString()
        AdditionalErrorMessage = $result.AdditionalErrorMessage
        State = $manager.TetheringOperationalState.ToString()
        ClientCount = $manager.ClientCount
        MaxClientCount = $manager.MaxClientCount
    }
}

function Stop-Hotspot {
    $manager = Get-TetheringManager
    $resultType = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult]
    $result = Await-WinRT ($manager.StopTetheringAsync()) $resultType
    return [pscustomobject]@{
        Status = $result.Status.ToString()
        AdditionalErrorMessage = $result.AdditionalErrorMessage
        State = $manager.TetheringOperationalState.ToString()
    }
}


function Restart-Hotspot {
    param([string]$SSID, [string]$Password)
    try {
        $s = Get-HotspotStatus
        if ($s.State -eq 'On') {
            [void](Stop-Hotspot)
            Start-Sleep -Milliseconds 800
        }
    } catch { }
    return Start-Hotspot -SSID $SSID -Password $Password
}

function Get-HotspotStatus {
    $manager = Get-TetheringManager
    return [pscustomobject]@{
        State = $manager.TetheringOperationalState.ToString()
        ClientCount = $manager.ClientCount
        MaxClientCount = $manager.MaxClientCount
    }
}
