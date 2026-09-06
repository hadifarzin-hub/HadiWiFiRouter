# HadiWiFiRouter v2.3 — Latest Rebuild / Continuation Prompt

Use this document together with the repository source as the authoritative starting point for continuing HadiWiFiRouter.

## Product objective
Build a portable Windows application that turns a home Windows PC into a controlled Internet gateway. Daily use must require only powering on the PC. Windows should be allowed to stop at the sign-in screen; background components run as SYSTEM and must not require any user to log in.

The PC may receive Internet through its normal Windows connection. It broadcasts a separate controlled Wi-Fi for phones/tablets. Restrictions must never intentionally limit the Administrator account's own Internet traffic.

## Existing v2.3 capabilities
- Portable Windows Forms Control Panel launched by `Open-Control-Panel.cmd`.
- Wi-Fi SSID/password configuration and Start/Stop controls.
- Background startup as SYSTEM using the existing setup scripts.
- One-time `Setup-All.cmd` flow.
- Weekly scheduling with multiple periods per day.
- Schedule targets: Whole traffic, YouTube, TikTok, Instagram, Snapchat.
- Website BlockList and custom domains.
- Service profiles for YouTube, TikTok, Instagram and Snapchat.
- Experimental/best-effort service blocking using DNS, TLS SNI, resolved destination IPs, QUIC suppression and WinDivert.
- Speed Control UI with Max / Medium / Low presets.
- Connected Devices view.
- Remote administration over Tailscale.
- Diagnostics/logging.
- Protected Windows Users added in v2.3.

## Protected Windows Users — latest requirement
A local Standard Windows user named `Roshana` exists on the same PC. Roshana must not receive unrestricted Internet simply because the machine is connected to the Administrator's main home Wi-Fi.

Windows cannot make a local Windows account connect to the same PC's own hotspot; network adapters are machine-wide. Therefore implement the functional equivalent:
- The PC remains connected to the normal home Wi-Fi.
- Administrator traffic stays unrestricted.
- Selected Standard Windows users are marked as **Protected Users**.
- Identify protected users by Windows SID, not only by user name.
- Protected users use the same HadiWiFiRouter policy definitions as hotspot clients.
- The background SYSTEM service refreshes protected-user policy enforcement automatically.
- The protected user must not need Administrator permissions.

### v2.3 implementation
`app/ProtectedUsers.ps1` implements:
- enumeration of local Windows users;
- exclusion of Administrator accounts from selectable protected users;
- SID resolution;
- per-user Windows Firewall rules using `LocalUser` SDDL;
- strong Whole-traffic schedule enforcement by blocking all outbound traffic for a protected SID outside allowed Whole-traffic periods;
- best-effort per-user website/service destination blocking using the same expanded service domains resolved to IP addresses;
- QUIC UDP/443 and DoT/853 suppression for protected users while strict TikTok/Instagram/Snapchat blocking is active;
- best-effort Windows QoS throttling using `UserMatchCondition` plus resolved destination IPs;
- automatic refresh from `app/Service.ps1` approximately every 20 seconds.

The Control Panel includes a **Protected Users** tab. It lists Standard local accounts, shows SID, and allows enabling `Same as controlled Wi-Fi`. The shipped `app/config.json` contains a preselection for user name `Roshana`; on the target PC the UI resolves the actual SID.

## Policy behavior
Schedules define when a target is ALLOWED. Outside configured periods the target is blocked.

For example:
- Monday / Whole traffic / 06:00–22:00: protected clients have Internet only in that window.
- Monday / TikTok / 17:00–19:00: TikTok is intended to be available only during that period.
- Multiple windows for the same day/service are supported.
- Overnight windows such as 22:00–02:00 are supported.

Speed presets:
- Max: approximately 5 Mbps.
- Medium: approximately 1 Mbps.
- Low: approximately 256 Kbps.

## Critical known limitation
Do not claim that v2.3 reliably identifies and blocks/throttles every native TikTok, Instagram or Snapchat flow. Testing proved that Windows Mobile Hotspot/ICS plus DNS/TLS/IP heuristics can block websites and some service traffic but cannot reliably identify all native-app traffic because of dynamic/shared CDN addresses, encrypted DNS, QUIC/HTTP3, ECH, cached endpoints and NAT behavior.

Whole-traffic schedule enforcement for Protected Windows Users is materially stronger because it is a per-user outbound firewall block, independent of service identification.

## Required v3 architecture
Retain the current UI, configuration model, schedules, remote management and business behavior, but replace the service-identification/routing backend with a robust **user-aware WFP / pre-NAT routing layer**.

The v3 backend should:
1. Identify hotspot-client flows before NAT whenever possible.
2. Attribute local-PC flows to process/token Windows SID so Protected Users can be enforced directly.
3. Maintain one unified policy model for hotspot clients and protected Windows users.
4. Enforce Whole traffic schedules strongly.
5. Enforce YouTube/TikTok/Instagram/Snapchat policies against native apps, not only browsers.
6. Implement service throttling at Low/Medium/Max levels against established as well as new flows.
7. Preserve unrestricted Administrator traffic.
8. Continue running before login as SYSTEM.
9. Continue remote management through Tailscale without public port forwarding.
10. Log policy decisions clearly enough to diagnose which client/user, service, rule and flow were matched.

## Security requirements
- Never store actual Wi-Fi passwords, Tailscale auth material or generated remote-admin keys in Git.
- Keep runtime secret files and logs ignored.
- A Standard protected account must not be able to stop or alter the SYSTEM enforcement service.
- Remote management must remain private/authenticated; do not expose an unauthenticated public port.

## Development instruction
Continue from the repository's latest `main` branch. Preserve working functionality while improving the backend. Do not regress boot-before-login, admin-traffic isolation, per-day schedules, remote access, Connected Devices or Protected Users. When implementing a new version, update this reconstruction document and the version README so another coding agent can resume without the original conversation.
