Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# v1.4 service-aware speed control. The same service-domain profiles used by
# Website Rules are expanded here, so entering YouTube/TikTok/Instagram/Snapchat
# applies to the service's known domains rather than only the literal hostname.

function Remove-HadiSpeedPolicies {
    try {
        Get-NetQosPolicy -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'HadiWiFiRouter-Speed-*' } |
            ForEach-Object { Remove-NetQosPolicy -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue }
    } catch { }
}

function Get-SpeedTargetDomains([string]$Target) {
    if(Get-Command Get-ServiceDomains -ErrorAction SilentlyContinue) {
        return @(Get-ServiceDomains $Target)
    }
    $d = ($Target -replace '^https?://','').Split('/')[0].Trim().Trim('.').ToLowerInvariant()
    if(-not $d){ return @() }
    return @($d)
}

function Resolve-SpeedDomainIPs {
    param([string]$Domain)
    $set = New-Object System.Collections.Generic.HashSet[string]
    $d = ($Domain -replace '^https?://','').Split('/')[0].Trim().Trim('.').ToLowerInvariant()
    if (-not $d) { return @() }
    foreach ($name in @($d, "www.$d")) {
        try {
            [System.Net.Dns]::GetHostAddresses($name) | ForEach-Object {
                if ($_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
                    [void]$set.Add($_.IPAddressToString)
                }
            }
        } catch { }
    }
    return @($set)
}

function Get-SpeedBitsPerSecond {
    param([string]$Level, $Config)
    switch ($Level) {
        'Low'    { return [uint64]($Config.SpeedPresets.LowKbps * 1000) }
        'Medium' { return [uint64]($Config.SpeedPresets.MediumKbps * 1000) }
        'Max'    { return [uint64]($Config.SpeedPresets.MaxKbps * 1000) }
        default  { return [uint64]($Config.SpeedPresets.MediumKbps * 1000) }
    }
}

function Apply-SpeedRules {
    param($Config)
    Remove-HadiSpeedPolicies

    if ($null -eq $Config.PSObject.Properties['SpeedControlEnabled'] -or -not [bool]$Config.SpeedControlEnabled) {
        return 'Website/service speed control disabled.'
    }
    if (-not (Get-Command New-NetQosPolicy -ErrorAction SilentlyContinue)) {
        return 'NetQos PowerShell module is not available on this Windows installation.'
    }

    $subnet = [string]$Config.HotspotSubnet
    if ([string]::IsNullOrWhiteSpace($subnet)) { $subnet = '192.168.137.0/24' }
    $created = 0
    $resolvedCount = 0
    $expandedCount = 0
    $index = 0

    foreach ($rule in @($Config.SpeedRules)) {
        if ($null -eq $rule -or -not [bool]$rule.Enabled) { continue }
        $target = [string]$rule.Domain
        if ([string]::IsNullOrWhiteSpace($target)) { continue }
        $bps = Get-SpeedBitsPerSecond -Level ([string]$rule.Level) -Config $Config
        foreach($domain in @(Get-SpeedTargetDomains $target)) {
            $expandedCount++
            $ips = @(Resolve-SpeedDomainIPs -Domain $domain)
            $resolvedCount += $ips.Count
            foreach ($ip in $ips) {
                $index++
                $safeTarget = ($target -replace '[^A-Za-z0-9]','_')
                if ($safeTarget.Length -gt 24) { $safeTarget = $safeTarget.Substring(0,24) }
                $name = "HadiWiFiRouter-Speed-$index-$safeTarget"
                try {
                    New-NetQosPolicy -Name $name -IPSrcPrefixMatchCondition $subnet -IPDstPrefixMatchCondition "$ip/32" -IPProtocolMatchCondition Both -ThrottleRateActionBitsPerSecond $bps -ErrorAction Stop | Out-Null
                    $created++
                } catch { }
            }
        }
    }
    return "Service-aware speed refresh: $created QoS policy/policies created from $resolvedCount IPv4 address(es) across $expandedCount expanded domain(s), source subnet $subnet."
}