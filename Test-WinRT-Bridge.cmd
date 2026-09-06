@echo off
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ". '.\app\HotspotCore.ps1'; try { Import-WinRTTypes; Write-Host 'PASS: Windows Runtime bridge and tethering types loaded.' -ForegroundColor Green } catch { Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red }; pause"
