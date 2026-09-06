@echo off
setlocal
cd /d "%~dp0"
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo Requesting Administrator permission...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo ============================================================
echo Hadi WiFi Router v1.8 - Complete one-time setup
echo ============================================================
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-All.ps1"
set "rc=%errorlevel%"
echo.
if not "%rc%"=="0" (
  echo SETUP DID NOT COMPLETE. Exit code: %rc%
  echo Please take a screenshot of this window and send it to me.
) else (
  echo ============================================================
  echo ALL ONE-TIME SETUP STEPS COMPLETED SUCCESSFULLY.
  echo ============================================================
  echo You can now use Open-Control-Panel.cmd.
  echo For remote access, open REMOTE-ACCESS-INFO.txt.
)
echo.
pause
exit /b %rc%
