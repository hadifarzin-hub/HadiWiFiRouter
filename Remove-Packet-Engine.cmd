@echo off
cd /d "%~dp0"
net session >nul 2>&1
if not "%errorlevel%"=="0" (powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'" & exit /b)
schtasks /End /TN "HadiWiFiRouter-PacketEngine" >nul 2>&1
schtasks /Delete /TN "HadiWiFiRouter-PacketEngine" /F >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process | ?{$_.CommandLine -match 'PacketEngine\.ps1'} | %%{Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}"
echo Packet-engine startup task removed.
pause
