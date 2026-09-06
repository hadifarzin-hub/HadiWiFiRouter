Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $AppDir
$Out = Join-Path $Root 'logs\diagnostics.txt'
. (Join-Path $AppDir 'HotspotCore.ps1')

$lines = New-Object System.Collections.Generic.List[string]
function Add($x) { $lines.Add([string]$x) }
Add "Hadi WiFi Router diagnostics"
Add "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add "Computer: $env:COMPUTERNAME"
Add "User: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Add "PowerShell: $($PSVersionTable.PSVersion)"
Add "OS: $([Environment]::OSVersion.VersionString)"
Add ""
Add "=== netsh wlan show drivers ==="
(netsh wlan show drivers 2>&1) | ForEach-Object { Add $_ }
Add ""
Add "=== netsh wlan show interfaces ==="
(netsh wlan show interfaces 2>&1) | ForEach-Object { Add $_ }
Add ""
Add "=== ipconfig ==="
(ipconfig /all 2>&1) | ForEach-Object { Add $_ }
Add ""
Add "=== Tethering API test ==="
try {
    $s = Get-HotspotStatus
    Add "TetheringOperationalState: $($s.State)"
    Add "ClientCount: $($s.ClientCount)"
    Add "MaxClientCount: $($s.MaxClientCount)"
} catch {
    Add "ERROR: $($_.Exception.Message)"
}
$lines | Set-Content -Path $Out -Encoding UTF8
Write-Host "Diagnostics saved to $Out"
