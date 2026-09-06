@echo off
cd /d "%~dp0"
echo === Packet Engine Task ===
schtasks /Query /TN "HadiWiFiRouter-PacketEngine" /V /FO LIST 2>nul | findstr /I /C:"Status:" /C:"Task To Run:" /C:"Run As User:"
echo.
echo === Live Rules ===
if exist "app\packetengine\rules.txt" (type "app\packetengine\rules.txt") else (echo rules.txt is missing)
echo.
echo === Latest Packet Engine Log ===
powershell -NoProfile -Command "if(Test-Path '.\logs\packetengine.log'){Get-Content '.\logs\packetengine.log' -Tail 60}else{Write-Host 'No packetengine.log yet.'}"
echo.
pause
