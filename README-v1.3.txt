Hadi WiFi Router Portable v1.5

Fix in this build:
- Setup-Packet-Engine.cmd no longer embeds a long PowerShell command containing nested quotes.
- Packet-engine setup is now performed by Setup-Packet-Engine.ps1.
- Fixed the Get-CimInstance process query that produced:
  "A positional parameter cannot be found that accepts argument 'OR'."
- Existing Hadi packet-engine processes are detected without a CIM -Filter expression.
- Startup task is registered as SYSTEM and started immediately after setup.

After extracting this version to a permanent folder:
1. Run Setup-Packet-Engine.cmd as Administrator once.
2. Confirm it says "Setup completed successfully".
3. Open Open-Control-Panel.cmd and test Website Rules.
4. If needed, run Test-Packet-Engine.cmd and send the output/log.
