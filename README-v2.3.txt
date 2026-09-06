HadiWiFiRouter v2.3 - Protected Windows Users

NEW FEATURE
- Adds a Protected Users tab to the Control Panel.
- Detects local Standard (non-Administrator) Windows accounts such as Roshana.
- A selected account can be assigned "Same as controlled Wi-Fi" policy.
- The PC remains on its normal Internet connection; it does NOT connect to its own hotspot.
- The administrator account is intentionally excluded and remains unrestricted.

ENFORCEMENT
- Whole traffic schedule: strong per-user Windows Firewall outbound block outside allowed periods.
- Custom website/service rules: best-effort per-user destination-IP firewall rules using the same service profiles and current schedule state.
- TikTok/Instagram/Snapchat strict mode also disables QUIC (UDP 443) and DoT (853) for the protected Windows user so traffic falls back to inspectable paths where possible.
- Speed Control: best-effort per-user Windows QoS rules using UserMatchCondition + resolved destination IPs.
- Rules refresh automatically from the SYSTEM background service every ~20 seconds and do not require the protected user to be an administrator.

IMPORTANT
Modern native apps can use dynamic/shared CDN addresses and encrypted service discovery. v2.3 therefore guarantees the whole-Internet schedule at the Windows-user level, but service-specific blocking/throttling remains best-effort until the planned v3 user-aware WFP/pre-NAT routing redesign.
