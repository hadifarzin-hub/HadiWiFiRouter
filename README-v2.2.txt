Hadi WiFi Router Portable v2.2

Native-app enforcement update:
- Dynamically learns the current IPv4 addresses behind blocked native-app hostnames as those DNS queries are observed.
- Drops subsequent hotspot-client traffic to those learned destinations, including sessions where TLS SNI is hidden by ECH.
- Keeps v2.1 DNS, TLS-SNI, QUIC/HTTP3 suppression, DoT blocking, and forwarded IPv6 strict-mode protection.
- PC-originated traffic is not intentionally filtered.

SETUP
Run Setup-All.cmd as Administrator once from the permanent v2.2 folder, then Open-Control-Panel.cmd.

TEST
Block one service at a time, Save, force-close the native app, reopen it, and refresh.
If it still loads, run Test-Packet-Engine.cmd and look for LEARN IP and BLOCK IP entries.
