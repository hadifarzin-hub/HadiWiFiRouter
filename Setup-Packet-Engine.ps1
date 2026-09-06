Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$engineDir = Join-Path $root 'app\packetengine'
New-Item -ItemType Directory -Force -Path $engineDir | Out-Null

$zipPath = Join-Path $env:TEMP 'WinDivert-2.2.2-A.zip'
$extractPath = Join-Path $env:TEMP 'HadiWinDivert'

Write-Host 'Downloading official WinDivert 2.2.2...'
Invoke-WebRequest -UseBasicParsing 'https://github.com/basil00/WinDivert/releases/download/v2.2.2/WinDivert-2.2.2-A.zip' -OutFile $zipPath

Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

$base = Get-ChildItem -LiteralPath $extractPath -Directory | Select-Object -First 1
if ($null -eq $base) { throw 'Unable to locate extracted WinDivert folder.' }

$dll = Join-Path $base.FullName 'x64\WinDivert.dll'
$sys = Join-Path $base.FullName 'x64\WinDivert64.sys'
if (-not (Test-Path -LiteralPath $dll)) { throw "WinDivert.dll was not found at $dll" }
if (-not (Test-Path -LiteralPath $sys)) { throw "WinDivert64.sys was not found at $sys" }

Copy-Item -LiteralPath $dll -Destination $engineDir -Force
Copy-Item -LiteralPath $sys -Destination $engineDir -Force

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
Write-Host 'You can now open the Control Panel and test Website Rules.'
