Hadi WiFi Router Portable v1.0 - packet-engine test build

Purpose of this build
- Keeps the existing Hotspot and per-day Schedule features.
- Replaces the ineffective Windows Firewall website blocker with a DNS packet-filter engine scoped to hotspot clients.
- The PC's own DNS traffic is not intentionally filtered; the engine only blocks DNS queries whose source address is in the hotspot client subnet (default 192.168.137.x).
- Website speed shaping is still NOT considered production-ready in this build.

FIRST-TIME SETUP
1) Extract this ZIP to a permanent folder, e.g. C:\HadiWiFiRouter-v1.0
2) Run Setup-Packet-Engine.cmd as Administrator.
   It downloads the official WinDivert 2.2.2 x64 binaries from the WinDivert GitHub release and registers HadiWiFiRouter-PacketEngine to start as SYSTEM at Windows boot.
3) Open Open-Control-Panel.cmd.
4) Website Rules -> BlockList -> Enable blocking -> enter trentu.ca -> Save website rules.
5) Connect the iPhone to the Hadi hotspot. Turn off cellular data temporarily for the first test so the result is unambiguous.
6) In Safari, try trentu.ca.

DIAGNOSTICS
- Run Test-Packet-Engine.cmd
- Check logs\packetengine.log
- A successful block will create a line such as: BLOCK DNS 192.168.137.x -> trentu.ca

IMPORTANT LIMITATION
This test build filters ordinary DNS (UDP/53). Apps/browsers that use encrypted DNS (DoH/DoT), VPNs, iCloud Private Relay paths, cached IP addresses, or direct IP connections can bypass DNS-only blocking. The next hardening step is to add encrypted-DNS/VPN bypass controls and then move speed shaping onto the same packet engine.

THIRD PARTY
WinDivert is not bundled in this ZIP; Setup-Packet-Engine.cmd downloads the official prebuilt WinDivert 2.2.2 package. WinDivert is open-source software under LGPLv3/GPLv2 licensing; see https://github.com/basil00/WinDivert and its distribution for license details.
