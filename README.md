# Hadi WiFi Router

A Windows-based controlled Wi-Fi gateway designed to provide scheduled, filtered and remotely managed Internet access to client devices without requiring a Windows user to log in.

## Current snapshot

This repository preserves the **v2.2** implementation and the complete product specification developed through iterative testing on the target Windows PC.

Important: v2.2 successfully creates the controlled Wi-Fi, supports boot-time execution, ordinary custom-domain blocking, service schedules, remote management scaffolding, and packet-engine diagnostics. However, reliable native-app enforcement for TikTok/Instagram/Snapchat remains incomplete when using Windows Mobile Hotspot/ICS. See `MASTER_SPEC_AND_REBUILD_PROMPT.md` for the full history, current limitation, and recommended v3.0 routing redesign.

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
- Remote management over Tailscale
- Packet-engine diagnostics and logs
- One-time `Setup-All.cmd` workflow

## Important architecture rule

Restrictions must apply only to clients using the controlled Wi-Fi. The Windows PC's own Internet connection must remain unrestricted.

## Repository documentation

Start with:

- `MASTER_SPEC_AND_REBUILD_PROMPT.md` — canonical product/business specification, history, architecture, known issues, and a standalone prompt for rebuilding/continuing the project.
- `README-TEST.txt` — original test instructions/history.
- version-specific `README-v*.txt` files — incremental implementation notes.

## Current limitation / next architecture

Windows Mobile Hotspot/ICS proved adequate for Wi-Fi sharing and basic DNS-based filtering but is not a dependable foundation for precise pre-NAT service identification and throttling of modern native apps using cached CDN addresses, encrypted DNS, QUIC/HTTP3, ECH, and shared infrastructure.

The recommended next step is to retain the existing UI/control plane while replacing the filtering/routing backend with a **real pre-NAT software-routing layer**. The master specification describes the intended v3.0 direction.

## Security

Do not commit runtime secrets, Tailscale authentication material, generated remote-admin keys, or real Wi-Fi passwords. The included configuration uses placeholder/example credentials. Runtime logs and generated secret files should remain ignored by Git.
