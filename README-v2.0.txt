Hadi WiFi Router Portable v2.1

Native-app blocking update
--------------------------
- Expanded TikTok, Instagram, and Snapchat service profiles.
- DNS wildcard matching for dynamic CDN hostnames.
- TLS ClientHello SNI filtering for hotspot-client HTTPS traffic.
- Strict native-app mode disables QUIC/HTTP3 (UDP 443) for hotspot clients whenever TikTok, Instagram, or Snapchat is actively blocked, causing compliant apps to fall back to TCP/TLS where service filtering can be enforced.
- YouTube service profile retained.
- Website blocking, service schedules, and speed-control domain expansion share the same service definitions.
- PC-originated traffic is not intentionally filtered; rules target hotspot clients.

IMPORTANT
---------
Run Setup-All.cmd as Administrator once from the permanent v2.1 folder so startup tasks point to this version.

Test native apps after force-closing and reopening them. If a service still works, run Test-Packet-Engine.cmd and send logs\packetengine.log.

Strict native-app blocking may make unrelated hotspot-client apps fall back from QUIC/HTTP3 to TCP while one of TikTok/Instagram/Snapchat is blocked. This can slightly affect performance but should not block unrelated sites.
