Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

function Section([string]$Text) {
    Write-Host ''
    Write-Host ('=' * 68) -ForegroundColor DarkGray
    Write-Host $Text -ForegroundColor Cyan
    Write-Host ('=' * 68) -ForegroundColor DarkGray
}

function Run-PowerShellStep([string]$ScriptName, [string]$Label) {
    $scriptPath = Join-Path $Root $ScriptName
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "$Label script not found: $scriptPath"
    }

    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $scriptPath
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        throw "$Label returned exit code $code"
    }
}

try {
    Section 'STEP 1 of 3 - Register Wi-Fi / schedule engine for Windows startup'
    $taskName = 'HadiWiFiRouterEngine'
    $serviceScript = Join-Path $Root 'app\Service.ps1'
    if (-not (Test-Path -LiteralPath $serviceScript)) { throw "Service.ps1 not found: $serviceScript" }
    try { Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue } catch {}
    try { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue } catch {}
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $serviceScript)
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 10 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    Write-Host 'Wi-Fi startup engine: OK' -ForegroundColor Green

    Section 'STEP 2 of 3 - Install / register packet-filtering engine'
    Run-PowerShellStep 'Setup-Packet-Engine.ps1' 'Packet engine setup'
    Write-Host 'Packet engine: OK' -ForegroundColor Green

    Section 'STEP 3 of 3 - Configure secure remote access through Tailscale'
    Run-PowerShellStep 'Setup-Remote-Access.ps1' 'Remote access setup'
    Write-Host 'Remote access: OK' -ForegroundColor Green

    Section 'FINAL CHECK'
    Write-Host 'All components have been registered to run under SYSTEM at Windows startup.' -ForegroundColor Green
    Write-Host 'A Windows login is not required after reboot.'
    Write-Host 'Remote access details are in REMOTE-ACCESS-INFO.txt.'
    exit 0
}
catch {
    Write-Host ''
    Write-Host ('SETUP ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'The completed earlier steps are left in place; rerunning Setup-All.cmd is safe.' -ForegroundColor Yellow
    exit 1
}
