@echo off
cd /d "%~dp0"
net session >nul 2>&1
if not %errorlevel%==0 (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
schtasks /End /TN "HadiWiFiRouterEngine" >nul 2>&1
schtasks /Delete /TN "HadiWiFiRouterEngine" /F
echo Removed.
pause
