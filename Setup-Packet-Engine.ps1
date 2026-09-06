Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$engineDir = Join-Path $root 'app\packetengine'
New-Item -ItemType Directory -Force -Path $engineDir | Out-Null
$destDll = Join-Path $engineDir 'WinDivert.dll'
$destSys = Join-Path $engineDir 'WinDivert64.sys'

function Test-EngineFiles([string]$Dir) {
    if ([string]::IsNullOrWhiteSpace($Dir)) { return $false }
    return (Test-Path -LiteralPath (Join-Path $Dir 'WinDivert.dll')) -and
           (Test-Path -LiteralPath (Join-Path $Dir 'WinDivert64.sys'))
}

function Copy-EngineFiles([string]$SourceDir) {
    Copy-Item -LiteralPath (Join-Path $SourceDir 'WinDivert.dll') -Destination $destDll -Force
    Copy-Item -LiteralPath (Join-Path $SourceDir 'WinDivert64.sys') -Destination $destSys -Force
}

$haveEngine = Test-EngineFiles $engineDir
if ($haveEngine) {
    Write-Host 'WinDivert files already exist in this package; download not required.' -ForegroundColor Green
}

# If this is an upgrade from an earlier HadiWiFiRouter version, reuse the already
# installed official WinDivert binaries before attempting any Internet download.
if (-not $haveEngine) {
    try {
        $oldTask = Get-ScheduledTask -TaskName 'HadiWiFiRouter-PacketEngine' -ErrorAction SilentlyContinue
        if ($null -ne $oldTask) {
            foreach ($a in @($oldTask.Actions)) {
                $args = [string]$a.Arguments
                if ($args -match '(?i)-File\s+"([^"]*PacketEngine\.ps1)"') {
                    $oldScript = $matches[1]
                } elseif ($args -match '(?i)-File\s+([^\s]+PacketEngine\.ps1)') {
                    $oldScript = $matches[1]
                } else {
                    $oldScript = $null
                }
                if ($oldScript) {
                    $oldApp = Split-Path -Parent $oldScript
                    $oldEngine = Join-Path $oldApp 'packetengine'
                    if (Test-EngineFiles $oldEngine) {
                        Write-Host ("Reusing WinDivert binaries from previous installation: {0}" -f $oldEngine) -ForegroundColor Green
                        Copy-EngineFiles $oldEngine
                        $haveEngine = $true
                        break
                    }
                }
            }
        }
    } catch {
        Write-Host ("Previous-installation lookup warning: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
}

# Also look in common previous portable-version folders on C: if the scheduled task
# was removed but an earlier extracted package is still present.
if (-not $haveEngine) {
    try {
        $candidates = Get-ChildItem -LiteralPath 'C:\' -Directory -Filter 'HadiWiFiRouter*' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending
        foreach ($folder in $candidates) {
            $oldEngine = Join-Path $folder.FullName 'app\packetengine'
            if ((Resolve-Path -LiteralPath $oldEngine -ErrorAction SilentlyContinue).Path -eq (Resolve-Path -LiteralPath $engineDir).Path) { continue }
            if (Test-EngineFiles $oldEngine) {
                Write-Host ("Reusing WinDivert binaries from: {0}" -f $oldEngine) -ForegroundColor Green
                Copy-EngineFiles $oldEngine
                $haveEngine = $true
                break
            }
        }
    } catch {}
}

if (-not $haveEngine) {
    $zipPath = Join-Path $env:TEMP 'WinDivert-2.2.2-A.zip'
    $extractPath = Join-Path $env:TEMP 'HadiWinDivert'
    Write-Host 'No local WinDivert copy found. Downloading official WinDivert 2.2.2...'
    try {
        Invoke-WebRequest -UseBasicParsing 'https://github.com/basil00/WinDivert/releases/download/v2.2.2/WinDivert-2.2.2-A.zip' -OutFile $zipPath
    } catch {
        throw "Unable to download WinDivert because this PC cannot currently reach github.com. Connect the PC to the Internet and rerun Setup-All.cmd, or keep an earlier HadiWiFiRouter installation on C: so its existing WinDivert files can be reused. Original error: $($_.Exception.Message)"
    }

    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
    $base = Get-ChildItem -LiteralPath $extractPath -Directory | Select-Object -First 1
    if ($null -eq $base) { throw 'Unable to locate extracted WinDivert folder.' }
    $dll = Join-Path $base.FullName 'x64\WinDivert.dll'
    $sys = Join-Path $base.FullName 'x64\WinDivert64.sys'
    if (-not (Test-Path -LiteralPath $dll)) { throw "WinDivert.dll was not found at $dll" }
    if (-not (Test-Path -LiteralPath $sys)) { throw "WinDivert64.sys was not found at $sys" }
    Copy-Item -LiteralPath $dll -Destination $destDll -Force
    Copy-Item -LiteralPath $sys -Destination $destSys -Force
}

Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        ($_.Name -ieq 'powershell.exe' -or $_.Name -ieq 'pwsh.exe') -and
        $_.CommandLine -and
        $_.CommandLine -match 'PacketEngine\.ps1'
    } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }

$taskName = 'HadiWiFiRouter-PacketEngine'
try { Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue } catch {}
try { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue } catch {}

$engineScript = Join-Path $root 'app\PacketEngine.ps1'
if (-not (Test-Path -LiteralPath $engineScript)) { throw "PacketEngine.ps1 was not found at $engineScript" }

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $engineScript)
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Start-Sleep -Seconds 2
$task = Get-ScheduledTask -TaskName $taskName
$info = Get-ScheduledTaskInfo -TaskName $taskName

Write-Host ''
Write-Host 'Packet engine installed and startup task registered.' -ForegroundColor Green
Write-Host ("Task state: {0}" -f $task.State)
Write-Host ("Last task result: {0}" -f $info.LastTaskResult)
Write-Host 'You can now open the Control Panel and test Website Rules / Protected Users.'
