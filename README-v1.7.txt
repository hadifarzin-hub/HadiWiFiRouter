Hadi WiFi Router Portable v1.7
==============================

NEW IN v1.7
-----------
1. One-click one-time setup: run Setup-All.cmd as Administrator.
   It performs all three setup stages in order:
   - Wi-Fi/schedule engine startup task
   - Packet-filtering engine setup
   - Secure Tailscale remote access setup
2. Remote access no longer uses Tailscale Serve, so setup cannot hang at
   "Publishing the local control panel..." waiting for Serve/HTTPS consent.
3. The remote panel is available directly on the PC's private Tailscale IPv4
   address at port 8787. The Tailscale tunnel encrypts the connection.
4. RemotePanel runs as SYSTEM at boot and retries automatically if Tailscale
   is not ready yet.

ONE-TIME SETUP
--------------
Keep this folder permanently in one location, e.g. C:\HadiWiFiRouter-v1.7
Then right-click Setup-All.cmd and choose Run as administrator.

If Tailscale is not authenticated yet, one browser sign-in is required.
The setup command has a five-minute timeout so it will never wait forever.
Rerunning Setup-All.cmd is safe if a step was interrupted.

REMOTE ACCESS
-------------
After successful setup, open REMOTE-ACCESS-INFO.txt for the private URL and
administrator key. Install Tailscale on the iPhone and sign in to the same
Tailscale account.

No Windows login is required after reboot.
No router port-forwarding is used or required.
Do NOT forward TCP port 8787 on your home router.
