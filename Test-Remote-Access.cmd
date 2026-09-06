@echo off
setlocal
cd /d "%~dp0"
set "TS=C:\Program Files\Tailscale\tailscale.exe"
echo === Remote panel local health ===
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try{$r=Invoke-WebRequest 'http://127.0.0.1:8787/health' -UseBasicParsing -TimeoutSec 3; Write-Host ('HTTP '+$r.StatusCode+' '+$r.Content)}catch{Write-Host ('ERROR: '+$_.Exception.Message)}"
echo.
echo === Startup task ===
schtasks /Query /TN "HadiWiFiRouter-RemotePanel" /V /FO LIST 2>nul
echo.
echo === Tailscale ===
if exist "%TS%" (
  "%TS%" status
  echo.
  for /f "delims=" %%I in ('"%TS%" ip -4 2^>nul') do set "TSIP=%%I"
  if defined TSIP (
    echo Tailscale IPv4: %TSIP%
    echo Remote URL: http://%TSIP%:8787/
  )
) else (
  echo Tailscale executable not found.
)
echo.
echo === Recent remote-panel log ===
if exist "%~dp0logs\remote-panel.log" powershell.exe -NoProfile -Command "Get-Content -LiteralPath '%~dp0logs\remote-panel.log' -Tail 40"
pause
