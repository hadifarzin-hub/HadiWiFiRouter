@echo off
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0app\Diagnostics.ps1"
echo.
type "%~dp0logs\diagnostics.txt"
echo.
pause
