# Hadi WiFi Router

A Windows-based controlled Wi-Fi gateway designed to provide scheduled, filtered and remotely managed Internet access to client devices without requiring a Windows user to log in.

## Current snapshot

This repository now preserves the **v2.3** implementation and the complete product specification developed through iterative testing on the target Windows PC.

Important: v2.3 creates the controlled Wi-Fi, supports boot-time execution, ordinary custom-domain blocking, service schedules, remote management scaffolding, packet-engine diagnostics, and now **Protected Windows Users**. Reliable native-app enforcement for TikTok/Instagram/Snapchat remains incomplete when using Windows Mobile Hotspot/ICS, so the planned v3 routing/WFP redesign is still the long-term architecture.

## Core product goal

Daily use should be:

`Power button -> Windows boots to sign-in screen -> background router starts -> controlled Wi-Fi becomes available -> client devices connect`

No Windows login should be required after the one-time setup.

## Main features

- Portable Windows Control Panel
- Controlled Wi-Fi SSID/password management
- Automatic startup before user login
- Weekly schedules by day
- Multiple schedule windows per day
- Schedule targets:
  - Whole traffic
  - YouTube
  - TikTok
  - Instagram
  - Snapchat
- Custom website block list
- Service profiles for major social/video services
- Speed-control interface with Low / Medium / Max levels
- Connected-device view
- **Protected Windows Users**: selected Standard local accounts can receive the same schedules/filtering/speed-policy definitions while the Administrator account remains unrestricted
- Remote management over Tailscale
- Packet-engine diagnostics and logs
- One-time `Setup-All.cmd` workflow

## Protected Windows Users

Windows cannot make a local account on this PC connect to the same PC's own hotspot. v2.3 implements the functional equivalent: the PC stays connected to the normal home Wi-Fi, while selected Standard Windows accounts are restricted at the Windows networking layer.

The current v2.3 implementation provides strong per-user enforcement for the **Whole traffic** schedule. Website/service blocking and speed limiting reuse the existing service definitions and apply per-user Firewall/QoS rules, but service-specific native-app enforcement is still best-effort until the v3 user-aware WFP/routing backend.

The included `app/config.json` preselects the local user name `Roshana`; at runtime the software resolves and stores the Windows SID through the Protected Users tab.

## Important architecture rule

Restrictions must apply only to controlled hotspot clients and explicitly selected Protected Windows Users. The Administrator account's own Internet connection must remain unrestricted.

## Repository documentation

Start with:

- `MASTER_SPEC_AND_REBUILD_PROMPT.md` — original canonical product/business specification and v3 direction.
- `README-v2.3.txt` — the latest Protected Windows Users implementation notes.
- `README-TEST.txt` — original test instructions/history.
- version-specific `README-v*.txt` files — incremental implementation notes.

## Current limitation / next architecture

Windows Mobile Hotspot/ICS proved adequate for Wi-Fi sharing and basic DNS-based filtering but is not a dependable foundation for precise pre-NAT service identification and throttling of modern native apps using cached CDN addresses, encrypted DNS, QUIC/HTTP3, ECH, and shared infrastructure.

The recommended next step is to retain the existing UI/control plane while replacing the filtering/routing backend with a **real pre-NAT/user-aware software-routing and WFP layer**. That redesign should support both hotspot clients and Protected Windows Users with the same policy model.

## Security

Do not commit runtime secrets, Tailscale authentication material, generated remote-admin keys, or real Wi-Fi passwords. The included configuration uses placeholder/example credentials. Runtime logs and generated secret files should remain ignored by Git.
