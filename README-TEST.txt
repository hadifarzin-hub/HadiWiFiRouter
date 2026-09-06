HADI WIFI ROUTER - PORTABLE TEST BUILD v0.5
==========================================

Goal of this build
------------------
1. Use the Windows PC as a controlled Wi-Fi hotspot.
2. Register a background engine that starts at Windows BOOT as SYSTEM,
   so a user logon is not required.
3. Automatically recover/retry if Internet or Wi-Fi is not ready yet.
4. Optional daily schedule.
5. Basic status/diagnostics and a GUI control panel.
6. Experimental block-list by resolved IPs (NOT bypass-proof yet).

IMPORTANT
---------
This is a hardware-compatibility test build, not the final parental-control build.
The critical thing we need to prove on your PC first is:

  Power ON -> Windows reaches sign-in screen -> controlled Wi-Fi exists -> phone gets Internet

Windows' supported tethering API requires the wiFiControl capability and behavior from a
SYSTEM/non-interactive session can depend on the Windows build and Wi-Fi driver. This build
logs the exact failure if the PC rejects that execution context.

FIRST TEST
----------
A) Extract the ZIP to a permanent folder, for example:
   C:\HadiWiFiRouter

B) Do NOT leave it in Downloads if you later plan to move/delete it; the startup task points
   to this folder.

C) Double-click:
   Open-Control-Panel.cmd

D) Change SSID and password, click Save.
   Password must be at least 8 characters.

E) Click "Start Wi-Fi now".
   If it turns on, connect your iPhone to the new SSID and test Internet.

F) If Start fails, run:
   Run-Diagnostics.cmd
   Send back the file logs\diagnostics.txt and logs\service.log.

BOOT / NO-LOGIN TEST
--------------------
1. Right-click or double-click Setup-AutoStart.cmd.
   It will request Administrator permission once.
2. Reboot the PC.
3. DO NOT sign in.
4. Wait until Windows is at the sign-in screen and the Internet/Wi-Fi adapter is ready.
5. On the iPhone, look for the configured SSID and connect.
6. Test a normal website.

If it does not appear, sign in only for diagnosis and send:
   logs\service.log
   logs\diagnostics.txt

SCHEDULE
--------
Open Control Panel -> Schedule.
If schedule is disabled, Wi-Fi should remain enabled whenever the PC is on.
If enabled, it starts/stops according to the selected times/days.
Overnight schedules are supported (e.g. 20:00 -> 07:00).

WEBSITE FILTERING IN v0.5
-------------------------
The GUI stores Block List and Allow List settings.
Only an EXPERIMENTAL IP-resolved Block List can be enabled in this build.
It is not yet suitable as a bypass-proof parental filter because modern websites may use
CDNs, changing IPs, QUIC, private DNS, or DNS-over-HTTPS.

I intentionally did NOT implement fake/fragile strict Allow List enforcement here.
After we prove boot-time hotspot support on your exact PC, the next build should add a true
packet-filter/DNS enforcement engine and device-level rules.

REMOVE
------
Run Remove-AutoStart.cmd as Administrator.
This deletes the startup task. The folder itself can then be deleted.


v0.5 FIX
--------
Fixed the Windows PowerShell 5.1 error:
  Unable to find type [System.WindowsRuntimeSystemExtensions]

The app now explicitly loads System.Runtime.WindowsRuntime before calling the Windows tethering API.


v0.5 CHANGE: Saving a new SSID/password now restarts an active hotspot so the new network name/password is broadcast immediately. The background engine also detects configuration changes while running.


V0.5 SCHEDULE UPDATE
--------------------
The Schedule tab now supports a different Enabled/Start/Stop setting for every day of the week. Overnight windows such as 20:00-02:00 are supported.

v0.6 additions
--------------
1. Connected Devices tab with manual and 3-second auto refresh.
2. Speed Control tab for website/domain rules with Max, Medium and Low presets.
   Max    = 5 Mbps
   Medium = 1 Mbps
   Low    = 256 Kbps
3. Speed rules are scoped to the configured hotspot client subnet (default 192.168.137.0/24)
   so the PC's own traffic is not intentionally matched.
4. Speed control currently uses Windows Policy-based QoS and resolved destination IPv4 addresses.
   This is a hardware/Windows compatibility test. Modern services such as TikTok use many domains,
   CDNs, QUIC and changing IPs, so one domain rule may not capture all service traffic yet.
5. Use "Save && apply now" in Speed Control, then test from a phone connected to the controlled Wi-Fi.
   If the rate does not change, send logs/service.log and a screenshot of the Speed Control status.

v0.9 FILTERING REWORK
---------------------
- Removed the old generic PC outbound website-block rule.
- Website blocking is now scoped to the configured hotspot client subnet.
- Saving Website Rules applies them immediately.
- Common service entries expand automatically: tiktok.com, youtube.com, instagram.com, snapchat.com.
- The PC's own traffic is not intentionally targeted by these rules.
- IMPORTANT: this is the client-scoped Windows filtering stage. A strict/bypass-resistant HTTPS/QUIC
  classifier still requires the WinDivert packet engine. WinDivert binaries are NOT silently bundled
  in this ZIP; the packet-engine component will be added only with its signed upstream driver files.
