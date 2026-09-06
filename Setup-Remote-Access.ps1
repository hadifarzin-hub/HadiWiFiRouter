Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=$PSScriptRoot
$AppDir=Join-Path $Root 'app'
$Engine=Join-Path $AppDir 'RemotePanel.ps1'
$KeyPath=Join-Path $AppDir 'remote-admin-key.txt'
$InfoPath=Join-Path $Root 'REMOTE-ACCESS-INFO.txt'
$Task='HadiWiFiRouter-RemotePanel'
$FirewallRule='Hadi WiFi Router - Tailscale Remote Panel'

function Random-Key {
    $chars='ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
    $b=New-Object byte[] 18
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
    -join ($b|ForEach-Object{$chars[$_ % $chars.Length]})
}
function Get-TailscaleExe {
    $p='C:\Program Files\Tailscale\tailscale.exe'
    if(Test-Path $p){return $p}
    $cmd=Get-Command tailscale.exe -ErrorAction SilentlyContinue
    if($cmd){return $cmd.Source}
    return $null
}
function Get-TailscaleIPv4([string]$Exe) {
    try {
        $v = @(& $Exe ip -4 2>$null) | Select-Object -First 1
        if($v){$v=[string]$v;$v=$v.Trim();if($v -match '^100\.') { return $v }}
    } catch {}
    return $null
}

if(-not (Test-Path $KeyPath)){
    $key=Random-Key
    [IO.File]::WriteAllText($KeyPath,$key,[Text.UTF8Encoding]::new($false))
}else{$key=(Get-Content $KeyPath -Raw).Trim()}
try{ & icacls.exe $KeyPath /inheritance:r /grant:r 'SYSTEM:F' 'Administrators:F' | Out-Null }catch{}

$ts=Get-TailscaleExe
if(-not $ts){
    Write-Host 'Tailscale is not installed. Downloading the official stable installer...'
    $installer=Join-Path $env:TEMP 'tailscale-setup-latest.exe'
    Invoke-WebRequest -Uri 'https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe' -OutFile $installer -UseBasicParsing
    Write-Host 'Installing Tailscale...'
    Start-Process $installer -ArgumentList '/S' -Wait
    Start-Sleep -Seconds 4
    $ts=Get-TailscaleExe
}
if(-not $ts){throw 'Tailscale installation did not produce tailscale.exe.'}
try{Start-Service Tailscale -ErrorAction SilentlyContinue}catch{}
Start-Sleep -Seconds 2

$tsIp=Get-TailscaleIPv4 $ts
if(-not $tsIp){
    Write-Host ''
    Write-Host 'ONE-TIME TAILSCALE SIGN-IN REQUIRED' -ForegroundColor Yellow
    Write-Host 'A browser window may open. Complete the Tailscale sign-in.' -ForegroundColor Yellow
    Write-Host 'This command has a 5-minute timeout so setup cannot hang forever.' -ForegroundColor Yellow
    & $ts up --unattended=true --timeout=5m
    if($LASTEXITCODE -ne 0){throw "Tailscale sign-in/up did not complete (exit code $LASTEXITCODE). Run Setup-All.cmd again after signing in."}
    Start-Sleep -Seconds 3
    $tsIp=Get-TailscaleIPv4 $ts
}else{
    Write-Host "Tailscale is already connected at $tsIp" -ForegroundColor Green
    & $ts up --unattended=true --timeout=30s | Out-Host
    if($LASTEXITCODE -ne 0){Write-Warning "Could not reapply unattended mode automatically (exit code $LASTEXITCODE). Existing Tailscale connection is still present."}
    Start-Sleep -Seconds 2
    $tsIp=Get-TailscaleIPv4 $ts
}
if(-not $tsIp){throw 'Tailscale is connected but no 100.x IPv4 address could be detected.'}

Write-Host "Tailscale private address: $tsIp" -ForegroundColor Green

try { Remove-NetFirewallRule -DisplayName $FirewallRule -ErrorAction SilentlyContinue } catch {}
New-NetFirewallRule -DisplayName $FirewallRule -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8787 -LocalAddress $tsIp -RemoteAddress '100.64.0.0/10' -Profile Any | Out-Null

Write-Host 'Registering remote panel to start at Windows boot as SYSTEM...'
try{Stop-ScheduledTask -TaskName $Task -ErrorAction SilentlyContinue}catch{}
try{Unregister-ScheduledTask -TaskName $Task -Confirm:$false -ErrorAction SilentlyContinue}catch{}
$action=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+$Engine+'"')
$trigger=New-ScheduledTaskTrigger -AtStartup
$principal=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 99 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName $Task -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $Task
Start-Sleep -Seconds 4

$localOk=$false
try{$r=Invoke-WebRequest 'http://127.0.0.1:8787/health' -UseBasicParsing -TimeoutSec 4;if($r.StatusCode -eq 200){$localOk=$true}}catch{}
if($localOk){Write-Host 'Remote panel local health: OK' -ForegroundColor Green}else{Write-Warning 'Remote panel did not answer on localhost yet. The startup task will retry automatically.'}

$remoteUrl="http://${tsIp}:8787/"
$info=@"
Hadi WiFi Router Remote Access
==============================
Remote URL: $remoteUrl
Administrator key: $key
Tailscale PC address: $tsIp

HOW TO CONNECT FROM IPHONE
--------------------------
1. Install/open the Tailscale app on the iPhone.
2. Sign in to the SAME Tailscale account/tailnet as this PC.
3. Turn Tailscale ON.
4. You can turn iPhone Wi-Fi OFF and use cellular data for the real Internet test.
5. Open this URL in Safari:
   $remoteUrl
6. Enter the Administrator key shown above.

SECURITY
--------
- Port 8787 is bound to localhost and this PC's Tailscale address only.
- Windows Firewall allows it only from the Tailscale private address range.
- No home-router port forwarding is used or required.
- The browser URL is HTTP because encryption is provided by the end-to-end Tailscale tunnel underneath it.
- Do not forward TCP port 8787 on your home router.
- Tailscale and the remote panel are configured to work before Windows user login.
"@
[IO.File]::WriteAllText($InfoPath,$info,[Text.UTF8Encoding]::new($false))
Write-Host ''
Write-Host $info
Write-Host 'Remote access setup completed.' -ForegroundColor Green
