# Hadi WiFi Router — Master Product Specification and Rebuild Prompt

## Purpose

This is the canonical specification for **Hadi WiFi Router**. It preserves the business goal, user experience, architecture, implemented behavior, test findings, known limitations, and the requirements for rebuilding or continuing the project without needing the original ChatGPT conversation.

Current preserved implementation: **v2.2**.

The next architectural rewrite should be treated as **v3.0**, because the main remaining problem requires replacing the routing/enforcement data plane rather than adding more domain names.

---

## 1. Business problem

A Windows PC at home should operate as a controlled Internet gateway for a child's iPhone and potentially other devices.

The child does **not** use the PC and should not have a Windows account on it. Normal daily operation must be:

`Press PC power button -> Windows boots to sign-in screen -> nobody logs in -> controlled Wi-Fi starts -> child connects from iPhone -> configured rules apply`

The parent does not want the solution to depend on Apple Family Sharing or Apple parental-control workflows. The main policy enforcement point should be the Windows gateway.

The parent must be able to manage the router locally and remotely over the Internet.

---

## 2. Non-negotiable principles

### 2.1 No Windows login required

After one-time administrator setup, all networking, scheduling, filtering, and remote-management components must start at Windows boot under `SYSTEM` or an equivalent boot-time service context.

The machine may remain at the Windows sign-in screen indefinitely.

### 2.2 Host-PC Internet remains unrestricted

Policies are for clients connected to the controlled Wi-Fi only.

Conceptually:

`PC local traffic -> Internet -> unrestricted`

`Controlled Wi-Fi clients -> routing/filtering/scheduling layer -> Internet -> restricted`

Do not intentionally apply parental website blocking, service blocking, throttling, or service schedules to the PC owner's own traffic.

### 2.3 Portable distribution

Preferred installation model:

1. Download/extract ZIP to a permanent folder.
2. Run one consolidated `Setup-All.cmd` as Administrator.
3. No traditional MSI/setup wizard required.
4. Control Panel remains directly runnable from the folder.

A one-time privileged step is acceptable for registering startup tasks/services, drivers, routing configuration, firewall rules, and unattended remote access.

### 2.4 Parent owns the control plane

The child only receives Internet access through the controlled Wi-Fi and should not have administrative access to the management interface.

Remote management must not expose an unauthenticated public Internet port.

---

## 3. Hotspot / controlled Wi-Fi

The application creates and manages a Wi-Fi network from the Windows PC.

Required controls:

- Enable/disable controlled Wi-Fi.
- Configurable SSID.
- Configurable Wi-Fi password.
- Start Wi-Fi now.
- Stop Wi-Fi now.
- Saving a changed SSID/password must actually update the broadcast network; if necessary restart the active hotspot.
- Retry automatically if the Wi-Fi adapter or upstream Internet is not ready immediately at boot.

The v2.x implementation uses Windows tethering/Windows Mobile Hotspot APIs and this successfully created a usable Wi-Fi network on the target PC.

---

## 4. Boot-time operation

One-time setup registers background components to run at Windows startup as `SYSTEM`.

The boot-time engine is responsible for:

- starting/stopping controlled Wi-Fi,
- applying whole-traffic schedules,
- applying service schedules,
- keeping packet/routing components running,
- retrying after adapter/upstream failures,
- operating before interactive user login.

Primary one-time entry point: `Setup-All.cmd`.

It must be safe to rerun after extracting a new version into a new permanent folder so scheduled-task paths are updated.

---

## 5. Weekly scheduling

The parent can define different schedule rules for every day of the week.

Each rule contains:

- Enabled
- Day
- Target
- Start
- Stop

Days:

- Monday
- Tuesday
- Wednesday
- Thursday
- Friday
- Saturday
- Sunday

Targets:

1. Whole traffic
2. YouTube
3. TikTok
4. Instagram
5. Snapchat

Requirements:

- multiple rules per day,
- multiple windows for the same target/day,
- overnight windows such as `22:00 -> 02:00`,
- service-specific schedules independent of whole-traffic availability.

Interpretation: schedule windows define when the selected target is **allowed**. Outside configured service windows, that service is blocked.

Examples:

- `Monday | Whole traffic | 07:00 | 22:00`
- `Monday | TikTok | 17:00 | 19:00`
- `Saturday | TikTok | 10:00 | 12:00`
- `Saturday | TikTok | 18:00 | 20:00`

Schedules must continue to work while Windows remains at the sign-in screen.

---

## 6. Website blocking

The Website Rules section supports a custom Block List.

Requirements:

- arbitrary custom domains, one per line,
- hotspot-client traffic only,
- live/hot reload,
- adding a domain should block it quickly,
- removing it should allow it again,
- adding it back should re-block it without requiring Wi-Fi restart or forgetting/rejoining the Wi-Fi network.

Required regression sequence:

`add trentu.ca -> blocked`

`remove trentu.ca -> opens`

`add trentu.ca again -> blocked again`

Ordinary custom-domain blocking was demonstrated successfully during testing.

---

## 7. First-class service profiles

The product treats the following as first-class services:

- YouTube
- TikTok
- Instagram
- Snapchat

A service profile is **not** equivalent to a single public domain. It must represent the service's web, native-app API, authentication, messaging, media, CDN, and dynamic endpoints as required.

There must be **one canonical service-definition source** reused by:

- Website Blocking
- Service Schedule
- Speed Control

Do not maintain inconsistent separate lists for each feature.

### Current test status

- YouTube blocking worked for both browser and native YouTube app.
- TikTok/Instagram/Snapchat browser blocking was easier to achieve.
- Native TikTok and Instagram remained able to load fresh content in v2.2 despite strict filtering attempts.
- Snapchat should be treated with the same native-app requirement.

---

## 8. Native-app enforcement requirement

User-facing meaning must be literal:

`TikTok -> Block` means both `tiktok.com` and the TikTok native app cannot load/refresh content.

Same requirement for Instagram, Snapchat, and YouTube.

### v2.2 enforcement attempts

The v2.2 packet engine attempted:

- DNS blocking,
- wildcard service-domain matching,
- TLS ClientHello/SNI inspection,
- QUIC/HTTP3 suppression by dropping UDP/443 in strict mode,
- DNS-over-TLS blocking on port 853,
- common DoH resolver blocking,
- forwarded IPv6 suppression in strict native-app mode,
- dynamic learning of IPv4 addresses from blocked DNS hostnames,
- dropping traffic to learned/resolved destination IPs.

Testing was performed with iPhone Cellular Data completely OFF and VPN/Tailscale OFF. TikTok and Instagram still loaded fresh content.

Logs proved that the Windows packet engine was actually intercepting and dropping many TikTok/Instagram DNS and some TLS-SNI requests.

Therefore the remaining problem is **architectural**, not simply a missing `tiktok.com`/`instagram.com` domain entry.

Do not keep solving this by endlessly expanding hostname lists on top of Windows Mobile Hotspot/ICS.

---

## 9. Speed control

The parent wants per-site/per-service bandwidth control.

Levels:

- Unlimited — no throttling
- Max — approximately 5 Mbps / 5000 Kbps
- Medium — approximately 1 Mbps / 1000 Kbps
- Low — approximately 256 Kbps

Targets must include custom domains and:

- YouTube
- TikTok
- Instagram
- Snapchat

Examples:

- `TikTok -> Low`
- `YouTube -> Medium`
- `Instagram -> Max`
- `Snapchat -> Low`

The same service classifier used for blocking must be used for speed control.

Throttling must apply only to controlled Wi-Fi clients, not to the host PC.

Earlier builds prototyped Windows Policy-based QoS against resolved destination IPv4 addresses. This is not considered robust enough for modern native-app service shaping and should be replaced by shaping inside the new routing data plane.

Changes should affect active flows as quickly as technically practical, not only future DNS resolutions.

---

## 10. Connected Devices

The Control Panel should show connected controlled-Wi-Fi clients in near real time.

Desired information:

- device/friendly name when available,
- IP address,
- MAC address when available,
- connected/disconnected state,
- connected since and/or last seen where practical.

Refresh automatically while GUI is open, approximately every few seconds.

Future-ready design should support:

- remembered friendly names,
- allow/block device,
- disconnect device,
- allow only approved devices,
- per-device schedules,
- per-device blocking/service rules,
- per-device speed limits,
- current/cumulative traffic usage.

Be aware that iPhones can use Private Wi-Fi Address/randomized MAC addresses.

---

## 11. Remote management

The parent must be able to manage the router from an iPhone over the Internet while the PC remains at the Windows sign-in screen.

Preferred architecture:

- Tailscale private network,
- Tailscale unattended mode before login,
- remote web panel runs as `SYSTEM`,
- no public router port-forwarding,
- current intended local management port: `8787`.

Remote panel should provide the important local controls:

- Wi-Fi status/start/stop,
- SSID/password management,
- weekly schedules,
- custom website rules,
- service blocking,
- speed rules,
- connected devices,
- status/diagnostics.

The controlled child Wi-Fi must not automatically grant administrative access to the control panel.

A previous `tailscale serve` setup path hung interactively. Later design changed to direct access through the Tailscale private IPv4 address and firewall scoping rather than relying on a blocking interactive Serve command.

---

## 12. Diagnostics and logging

Provide scripts/tools to inspect:

- WinRT/tethering compatibility,
- startup task state,
- packet/routing engine state,
- current live rules,
- connected clients,
- remote-access state,
- logs.

Existing useful entry points include:

- `Run-Diagnostics.cmd`
- `Test-WinRT-Bridge.cmd`
- `Test-Engine-Once.cmd`
- `Test-Packet-Engine.cmd`
- `Test-Remote-Access.cmd`

Logs should be useful for debugging but must not intentionally contain passwords, Tailscale auth keys, generated admin keys, or other secrets.

---

## 13. Existing v2.2 source structure

The current project is primarily PowerShell + Windows Forms + CMD wrappers.

Important files/modules:

- `app/ControlPanel.ps1` — local Windows Forms GUI
- `app/Service.ps1` — boot-time orchestration/schedule loop
- `app/HotspotCore.ps1` — Windows Runtime tethering API bridge
- `app/WebsiteRules.ps1` — domain/service expansion and packet-rule generation
- `app/SpeedRules.ps1` — prototype QoS speed rules
- `app/ConnectedDevices.ps1` — client discovery
- `app/Diagnostics.ps1` — diagnostics
- `app/PacketEngine.ps1` — v2.2 WinDivert-based packet engine
- `app/RemotePanel.ps1` — remote web management panel
- `app/config.json` / `app/config.example.json`
- `Setup-All.cmd` / `Setup-All.ps1`
- `Setup-Packet-Engine.cmd` / `.ps1`
- `Setup-Remote-Access.cmd` / `.ps1`
- startup removal scripts
- diagnostic/test scripts

Downloaded WinDivert binaries/drivers are intentionally not committed and are fetched by setup.

---

## 14. Important historical bugs and lessons

Any rebuild must explicitly avoid regressions discovered during iterative testing:

1. Windows PowerShell 5.1 may not preload `System.Runtime.WindowsRuntime`; explicitly load the bridge required by the tethering API.
2. Changing SSID/password while hotspot is already active may require restart before Windows broadcasts the new values.
3. Windows Forms `DataGridView.Columns.AddRange()` can fail in PowerShell when a generic `Object[]` is passed; add columns individually or use the correct typed collection.
4. Website Rules previously called functions before loading/importing their module; module initialization must be explicit.
5. `$MyInvocation...Path` can be unreliable depending on call context; use robust `$PSScriptRoot`/captured script-directory logic.
6. Do not restart/kill a `SYSTEM` packet-engine process every time rules change; use live/hot reload.
7. Setup scripts must not assume `$LASTEXITCODE` already exists.
8. Complex nested quoting in CMD -> PowerShell -> CIM filters caused setup failures; keep setup logic in dedicated `.ps1` files.
9. Do not create global Windows Firewall or QoS rules that accidentally affect host-PC traffic.
10. Native social-media apps cannot be treated as one public hostname.
11. DNS-only enforcement is insufficient against modern native apps, encrypted DNS, cached flows, QUIC, ECH, and shared CDN infrastructure.
12. A packet engine logging `BLOCK DNS`/`BLOCK TLS-SNI` does not prove the whole native app is blocked; test actual fresh app content.

---

## 15. Configuration model

Preserve equivalents of these settings:

- `HotspotEnabled`
- `SSID`
- `Password`
- `RetrySeconds`
- `WebsiteFilteringEnabled`
- `FilteringMode`
- `BlockedDomains`
- `BlockedServices`
- `AllowedDomains`
- `HotspotSubnet`
- `SpeedControlEnabled`
- `SpeedPresets`
- `SpeedRules`
- `RemotePanelEnabled`
- `RemotePanelPort`
- `ScheduleEnabled`
- `ScheduleRules`

Configuration writes should be atomic/safe. Secrets should not be committed to Git.

---

## 16. Current v2.2 status

### Working / demonstrated

- Windows Control Panel opens.
- Windows controlled Wi-Fi can be created and used by an iPhone.
- SSID/password management works after restart/apply fixes.
- Boot/startup tasks can run components as `SYSTEM`.
- Ordinary custom-domain blocking works in testing.
- YouTube can be blocked in browser and native app.
- Service/domain rules can hot reload.
- Packet engine produces real block diagnostics.
- Weekly schedule UI exists.
- Service-specific schedule target concept exists.
- Connected-device view exists.
- Tailscale installation/authentication worked during remote-access development.

### Not considered solved

- reliable native TikTok blocking,
- reliable native Instagram blocking,
- reliable native Snapchat blocking,
- robust service-aware speed throttling,
- complete final end-to-end pre-login validation of every feature after the latest upgrades,
- final pre-NAT software-routing architecture.

---

## 17. Recommended v3.0 architecture

Do **not** continue merely expanding DNS/domain lists on top of Windows ICS.

Preserve the existing Control Panel, configuration concepts, schedules, remote-management UX, and boot workflow, but redesign the **data plane**.

Required conceptual pipeline:

`Controlled Wi-Fi client -> pre-NAT routing/classification/policy layer -> allow/block/shape -> NAT/forward -> upstream Internet`

Host PC traffic stays on a separate unrestricted path.

The routing/policy layer must retain client-flow visibility **before NAT** so it can reliably associate flows with the controlled client and apply service-level rules.

Evaluate Windows-compatible implementations based on reliability and maintainability, for example:

- Windows Filtering Platform callout/driver,
- a dedicated user-mode router with supported packet capture/injection and explicit NAT,
- an embedded router/firewall component,
- another maintainable pre-NAT architecture.

The chosen approach must:

- start before login,
- not require a Windows account for the child,
- preserve host-PC Internet,
- support service blocking and shaping,
- support remote control,
- fail safely.

---

# STANDALONE REBUILD / CONTINUATION PROMPT

Copy everything between `BEGIN REBUILD PROMPT` and `END REBUILD PROMPT` into a capable coding agent when continuing this project.

## BEGIN REBUILD PROMPT

You are rebuilding and continuing a Windows application named **Hadi WiFi Router**. Treat this prompt as the canonical product specification. Do not simplify requirements or silently remove features.

### Product goal

Build a portable Windows software router/control system for a home PC. The PC creates a controlled Wi-Fi network for client devices such as an iPhone. The parent controls Internet availability, selected services, schedules, blocking, connected devices, and speed limits. The child does not use the Windows PC and has no Windows login.

### Critical boot requirement

After one-time administrator setup, normal operation is:

`Press power -> Windows boots to sign-in screen -> nobody logs in -> router/filter services run as SYSTEM -> controlled Wi-Fi becomes available according to policy.`

The GUI must not need to be open. Recover/retry when Wi-Fi or upstream connectivity is temporarily unavailable during startup.

### Portability

Distribute as an extracted ZIP/folder. Avoid a traditional installer. Provide a single `Setup-All.cmd` that requests Administrator privilege and safely configures all boot-time tasks/services/drivers/routing and remote access. It must be safe to rerun after moving to a new version folder.

### Host-PC isolation

The PC owner's own Internet must remain unrestricted. All parental restrictions target only devices using the controlled Wi-Fi/gateway path.

### Local GUI

Provide at least these sections/tabs:

1. **Hotspot**
   - enable controlled Wi-Fi
   - SSID
   - password
   - Save
   - Start Wi-Fi now
   - Stop Wi-Fi now
   - status

2. **Schedule**
   - multiple rules
   - Enabled, Day, Target, Start, Stop
   - Monday-Sunday
   - Targets: Whole traffic, YouTube, TikTok, Instagram, Snapchat
   - overnight windows
   - multiple windows for same target/day

3. **Website Rules**
   - arbitrary blocked domains one per line
   - service-level blocking for YouTube/TikTok/Instagram/Snapchat
   - live apply/hot reload

4. **Speed Control**
   - custom domain or service target
   - Unlimited / Max / Medium / Low
   - default Max=5000 Kbps, Medium=1000 Kbps, Low=256 Kbps
   - controlled-client traffic only

5. **Connected Devices**
   - near-real-time refresh
   - IP, MAC if available, hostname/friendly name if available, status/last-seen/connected-since where practical

6. **Remote Access**
   - Tailscale/private management
   - runs before login
   - authenticated management

7. **Status / Diagnostics**
   - startup task/service state
   - routing/packet engine state
   - logs
   - live rules
   - remote-access status

### Canonical service profiles

Maintain one service-definition source reused by Blocking, Schedule, and Speed Control.

Services:

- YouTube
- TikTok
- Instagram
- Snapchat

A service profile must cover native apps as well as websites. Do not pretend that `tiktok.com` alone equals TikTok.

### Native-app enforcement

A blocked service must fail in the native app, not only in Safari/browser.

Existing v2.2 attempted DNS blocking, wildcard domains, TLS SNI, QUIC suppression, DoT/DoH blocking, IPv6 strict-mode controls, dynamic IPv4 learning, and IP drops. TikTok/Instagram still loaded fresh content even with cellular data and VPN disabled. Logs showed the filtering engine was genuinely blocking many requests.

Therefore **do not merely add more domains on top of Windows Mobile Hotspot/ICS**. Redesign the routing/data plane so policy enforcement occurs **before NAT**, with reliable client-flow visibility.

YouTube was successfully blocked in both browser and native app; preserve that behavior while improving other services.

### Website-rule regression test

This must work without restarting Wi-Fi:

`add trentu.ca -> blocked`

`remove trentu.ca -> opens`

`add trentu.ca again -> blocked again`

Apply changes quickly, preferably within about one second.

### Speed control

Use the same service recognition used for blocking. Changing a speed rule should affect native/active service traffic as quickly as technically possible.

### Remote access

Provide an authenticated web control panel from the parent's iPhone over the Internet using Tailscale/private tunnel rather than public port forwarding. Tailscale and the remote panel must operate unattended before Windows login. Port 8787 is the historical default.

Avoid an interactive `tailscale serve` setup step that can hang. Direct Tailscale-private-IP access with appropriately scoped Windows Firewall rules is acceptable.

### Existing source technology

Current v2.2 uses PowerShell + Windows Forms + CMD wrappers with modules analogous to:

- ControlPanel.ps1
- Service.ps1
- HotspotCore.ps1
- WebsiteRules.ps1
- SpeedRules.ps1
- ConnectedDevices.ps1
- Diagnostics.ps1
- PacketEngine.ps1
- RemotePanel.ps1
- config.json

You may refactor to a compiled Windows application/service if that materially improves reliability, but preserve the portable UX, one-time setup, migration path, and all product features.

### Historical bugs to avoid

- explicitly load Windows Runtime bridge for tethering APIs
- restart/apply hotspot after SSID/password changes
- avoid PowerShell DataGridView `AddRange(Object[])` type failures
- explicitly import rule modules before use
- robust `$PSScriptRoot` path handling
- hot reload rules rather than restarting a SYSTEM process for every edit
- setup scripts must not assume `$LASTEXITCODE` exists
- avoid brittle nested CMD/PowerShell quoting
- never globally block/shape host-PC traffic

### Security

- do not expose management directly to public Internet
- do not log secrets
- do not commit real Wi-Fi passwords, Tailscale auth keys, or generated admin keys
- use atomic configuration writes
- privileged components should be narrowly scoped
- filtering failures must not cripple the host PC's own connectivity

### Required deliverables

Produce:

1. complete source tree
2. portable ZIP
3. single one-time `Setup-All.cmd`
4. `Open-Control-Panel.cmd`
5. removal/uninstall scripts for registered tasks/services/components
6. diagnostics/test scripts
7. README with setup/test instructions
8. architecture documentation
9. changelog/version
10. automated tests for schedule evaluation, service expansion, configuration read/write, and routing-policy logic

Before claiming a feature works, test it. Do not claim TikTok/Instagram/Snapchat native-app blocking is solved unless the data-plane design actually supports it and test evidence exists.

## END REBUILD PROMPT

---

## Repository security policy

Keep runtime secrets and personal network information out of Git.

Do not commit:

- real Wi-Fi passwords,
- Tailscale authentication keys,
- generated remote-admin keys,
- private device logs,
- downloaded WinDivert binaries/drivers when setup can fetch them.

Recommended `.gitignore` should exclude runtime logs, generated remote-access files, secrets, temp files, and downloaded packet-engine binaries.
