Hadi WiFi Router Portable v1.5

Fix in this build:
- Packet engine no longer exits when filtering is disabled or the block list is empty.
- Website-rule changes are hot-reloaded from app\packetengine\rules.txt.
- The Control Panel does not try to kill/restart the SYSTEM packet engine every time you edit a domain.
- UDP and TCP port-53 DNS queries from hotspot clients are inspected.
- PC-originated traffic remains outside the hotspot-client prefix filter.

IMPORTANT: run Setup-Packet-Engine.cmd as Administrator once after extracting v1.5 to its permanent folder.

Test with a fresh domain first (for example example.org), then inspect logs\packetengine.log for RULES RELOADED and BLOCK DNS lines.
Encrypted DNS / Private Relay / VPN traffic is not yet handled in this build.
