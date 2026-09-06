Hadi WiFi Router Portable v1.1

Fix in this build:
- Website Rules no longer fails with: The property Path cannot be found on this object.
- The WebsiteRules module now captures its own script directory at load time and reliably finds PacketEngine.ps1 and the packetengine dependency folder.

Test:
1. Keep using the same extracted folder only if you re-run Setup-Packet-Engine.cmd from this v1.1 folder, because the scheduled task contains the packet-engine path.
2. Open Open-Control-Panel.cmd.
3. Enable Website Blocking, add trentu.ca, and Save website rules.
4. If the site still opens, run Test-Packet-Engine.cmd and send logs\packetengine.log.
