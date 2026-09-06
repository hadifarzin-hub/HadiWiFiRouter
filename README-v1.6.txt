Hadi WiFi Router Portable v1.6
==============================

NEW: Secure remote control from iPhone over the Internet.

Architecture
------------
- app\RemotePanel.ps1 runs as SYSTEM at Windows startup.
- It listens ONLY on 127.0.0.1:8787, not on your LAN or the public Internet.
- Tailscale Serve exposes it only inside your private Tailscale network.
- Tailscale uses an encrypted private network, so no router port-forwarding is required.
- The remote panel has a separate administrator key in addition to Tailscale access.
- After one-time setup, Windows does not need to be logged in.

ONE-TIME SETUP
--------------
1. Keep this folder in a permanent location, e.g. C:\HadiWiFiRouter-v1.6
2. Run Setup-AutoStart.cmd as Administrator if not already registered from this version.
3. Run Setup-Packet-Engine.cmd as Administrator.
4. Run Setup-Remote-Access.cmd as Administrator.
   - If Tailscale is not installed, the script downloads the current stable official installer.
   - Authenticate Tailscale once when prompted.
   - The script enables unattended mode so Tailscale keeps running at the Windows sign-in screen.
   - It configures Tailscale Serve to proxy HTTPS to the local control panel.
5. On iPhone, install Tailscale, sign into the same account/tailnet, and turn it on.
6. Open REMOTE-ACCESS-INFO.txt and use the URL and administrator key shown there.

REMOTE PANEL FEATURES
---------------------
- Hotspot status / start / stop
- SSID and password
- Per-day weekly schedule
- Website blocking + YouTube/TikTok/Instagram/Snapchat profiles
- Speed-control rules
- Connected devices
- Auto refresh

SECURITY
--------
Do NOT forward port 8787 or any other control-panel port on your home router.
The local server is intentionally bound only to 127.0.0.1.
Remote access should go through Tailscale only.

TESTS
-----
- Test-Remote-Access.cmd checks the local panel, startup task, Tailscale and logs.
- Reboot, remain at the Windows sign-in screen, then access the panel from iPhone over cellular data with Tailscale enabled.
