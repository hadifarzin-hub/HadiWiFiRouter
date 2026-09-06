@echo off
setlocal
cd /d "%~dp0"
net session >nul 2>&1
if not %errorlevel%==0 (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Unregister-ScheduledTask -TaskName 'HadiWiFiRouter-RemotePanel' -Confirm:$false -ErrorAction SilentlyContinue; $ts='C:\Program Files\Tailscale\tailscale.exe'; if(Test-Path $ts){ & $ts serve reset 2>$null }"
echo Remote-panel startup task and Tailscale Serve mapping removed.
echo Tailscale itself was NOT uninstalled and your app settings were preserved.
pause
