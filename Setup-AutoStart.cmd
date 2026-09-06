@echo off
setlocal
cd /d "%~dp0"
net session >nul 2>&1
if not %errorlevel%==0 (
  echo Requesting Administrator permission...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
set "TASK=HadiWiFiRouterEngine"
set "SCRIPT=%~dp0app\Service.ps1"
echo Registering boot-time engine as SYSTEM...
schtasks /Delete /TN "%TASK%" /F >nul 2>&1
schtasks /Create /TN "%TASK%" /SC ONSTART /RU SYSTEM /RL HIGHEST /TR "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%SCRIPT%\"" /F
if errorlevel 1 (
  echo.
  echo ERROR: Could not register the startup task.
  pause
  exit /b 1
)
echo.
echo Startup task installed successfully.
echo Starting it now for testing...
schtasks /Run /TN "%TASK%"
echo.
echo Open the Control Panel and Diagnostics next.
pause
