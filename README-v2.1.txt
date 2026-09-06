Hadi WiFi Router v2.1

Native-app blocking hardening:
- Forces hotspot forwarded IPv6 off while TikTok/Instagram/Snapchat strict blocking is active, so iOS cannot bypass the IPv4 inspection path.
- Suppresses QUIC/HTTP3 (UDP 443) and DNS-over-TLS (TCP/UDP 853) for hotspot clients in strict mode.
- Adds common public DoH resolver hostnames to strict-mode blocking.
- Expands TikTok, Instagram and Snapchat service-domain profiles.
- PC-originated traffic remains outside the forwarded IPv6 rule.

Run Setup-All.cmd as Administrator once from the permanent v2.1 folder, then Open-Control-Panel.cmd.

If a native app still works, run Test-Packet-Engine.cmd immediately after refreshing the app and send the final log section.
