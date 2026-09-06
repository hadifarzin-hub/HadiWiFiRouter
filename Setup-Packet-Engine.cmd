@echo off
setlocal
cd /d "%~dp0"
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo Requesting Administrator access...
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)

echo Installing Hadi WiFi Router packet engine...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-Packet-Engine.ps1"
set "rc=%errorlevel%"
echo.
if not "%rc%"=="0" (
  echo Setup failed with exit code %rc%.
) else (
  echo Setup completed successfully.
)
echo Press any key to close.
pause >nul
exit /b %rc%
