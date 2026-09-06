Hadi WiFi Router Portable v1.5

New in v1.5
- Fixes the re-block problem seen when a site was removed from BlockList, opened on the phone, and then added back.
- A dedicated rule watcher reloads rules every ~0.5 second even if the phone is using cached DNS and sends no new DNS query.
- The packet engine resolves blocked domains to their current IPv4 addresses and drops hotspot-client packets to those addresses.
- Existing/cached sessions therefore stop working after a domain is newly blocked instead of waiting for the phone's DNS cache or connection to expire.
- PC-originated traffic remains outside the hotspot-client rule check.
- Logs now include RULES RELOADED ... resolvedIPv4=N and BLOCK IP entries.

Important
After extracting v1.5 to its permanent folder, run Setup-Packet-Engine.cmd as Administrator once so the SYSTEM startup task points to this version.

Recommended re-block test
1. Add trentu.ca and save -> verify blocked.
2. Remove trentu.ca and save -> verify it opens.
3. Add trentu.ca again and save.
4. Wait about 1 second, then refresh/open it again. It should be blocked without restarting Wi-Fi or forgetting the network.
5. If not, run Test-Packet-Engine.cmd and send logs\packetengine.log.

Note
Large services such as YouTube/TikTok use many domains and changing CDN IPs. Service profiles improve coverage, but complete enforcement will continue to be refined based on live testing.
