Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:WebsiteRulesAppDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($script:WebsiteRulesAppDir)) {
    $script:WebsiteRulesAppDir = Split-Path -Parent $PSCommandPath
}

function Normalize-Domain([string]$d) {
    if ($null -eq $d) { return '' }
    return (($d -replace '^https?://','').Split('/')[0].Trim().Trim('.').ToLowerInvariant())
}

function Get-ServiceDomains([string]$Target) {
    $d = Normalize-Domain $Target
    switch -Regex ($d) {
        '^(youtube|youtube\.com|m\.youtube\.com|www\.youtube\.com)$' {
            return @(
                'youtube.com','youtu.be','googlevideo.com','ytimg.com','youtubei.googleapis.com',
                'youtube-nocookie.com','youtube.googleapis.com','youtubeembeddedplayer.googleapis.com',
                'youtubeeducation.com','youtube-ui.l.google.com','yt3.ggpht.com','ggpht.com'
            )
        }
        '^(tiktok|tiktok\.com|www\.tiktok\.com)$' {
            # Native TikTok uses a much wider ByteDance/CDN footprint than the public web site.
            # Wildcards are consumed by the packet engine's DNS/TLS-SNI matcher.
            return @(
                'tiktok.com','tiktokv.com','tiktokcdn.com','tiktokcdn-us.com','tiktokcdn-eu.com','tiktokv.us',
                'byteoversea.com','byteoversea.net','ibytedtos.com','ibyteimg.com','bytefcdn-oversea.com',
                'muscdn.com','musical.ly','isnssdk.com','snssdk.com','pstatp.com','ipstatp.com',
                'bytetcdn.com','byteimg.com','amemv.com','ttwstatic.com','ttlivecdn.com','ttdns2.com',
                'bytedance.com','toutiao.com','api16-normal-c-useast1a.tiktokv.com','frontier-va.tiktokv.com','gecko16-normal-c-useast1a.tiktokv.com','v19.tiktokcdn.com','v77.tiktokcdn.com','bytegeo.akadns.net','bytewlb.akadns.net','bytedance.akadns.net',
                'musical.ly.akadns.net','*tiktok*.akamaized.net','*muscdn*.akamaized.net','*ibyteimg*.akamaized.net'
            )
        }
        '^(instagram|instagram\.com|www\.instagram\.com)$' {
            # Instagram's native app also uses Meta messaging/CDN endpoints.
            return @(
                'instagram.com','cdninstagram.com','ig.me','instagramstatic-a.akamaihd.net','instagramstatic-a.akamaihd.net.edgesuite.net',
                'api.instagram.com','i.instagram.com','images.instagram.com','l.instagram.com','logger.instagram.com','platform.instagram.com','c10r.instagram.com',
                'graph.instagram.com','gateway.instagram.com','graph-fallback.instagram.com','i-fallback.instagram.com',
                'instagram.c10r.facebook.com','connect.facebook.net','cdn.fbsbx.com','edge-mqtt.facebook.com',
                'mqtt-mini.facebook.com','z-p42-chat-e2ee-ig.facebook.com','instagram.*.fbcdn.net'
            )
        }
        '^(snapchat|snapchat\.com|www\.snapchat\.com)$' {
            return @(
                'snapchat.com','app.snapchat.com','mvm.snapchat.com','auth.snapchat.com','pro-accounts.snapchat.com','api.snapchat.com','jaguar-prod.snapchat.com','chat-gateway-prod.chat.snapchat.com',
                'sc-cdn.net','gcs.sc-cdn.net','snapkit.com','api.snapkit.com','snapads.com','sc-jpl.com','sc-gw.com','sc-prod.net',
                'feelinsonice.com','feelinsonice.appspot.com','feelinsonice-hrd.appspot.com','snapchat.appspot.com',
                'sc-analytics.appspot.com','snapchat-proxy.appspot.com','cognac-prod.appspot.com','bitmoji.com',
                'snap-storage-cdn.l.google.com','snap.api.mapbox.com','snap.events.mapbox.com'
            )
        }
        default {
            if([string]::IsNullOrWhiteSpace($d)){ return @() }
            return @($d)
        }
    }
}

function Test-SchedulePeriod([datetime]$Now,[string]$Day,[string]$Start,[string]$Stop) {
    $dayNames=@('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday')
    $idx=[array]::IndexOf($dayNames,$Day); if($idx -lt 0){return $false}
    $s=[TimeSpan]::Parse($Start);$e=[TimeSpan]::Parse($Stop);$t=$Now.TimeOfDay;$todayIdx=[int]$Now.DayOfWeek
    if($s -eq $e){return ($todayIdx -eq $idx)}
    if($s -lt $e){return ($todayIdx -eq $idx -and $t -ge $s -and $t -lt $e)}
    if($todayIdx -eq $idx -and $t -ge $s){return $true}
    $next=($idx+1)%7; if($todayIdx -eq $next -and $t -lt $e){return $true}
    return $false
}

function Get-ScheduleBlockedServices {
    param($Config,[datetime]$Now=(Get-Date))
    $result=@()
    if(-not [bool]$Config.ScheduleEnabled){return @()}
    if($null -eq $Config.PSObject.Properties['ScheduleRules']){return @()}
    $all=@($Config.ScheduleRules)
    foreach($svc in @('YouTube','TikTok','Instagram','Snapchat')){
        $rules=@($all|Where-Object{[bool]$_.Enabled -and [string]$_.Target -eq $svc})
        if($rules.Count -eq 0){continue} # no schedule for service => no schedule restriction
        $allowed=$false
        foreach($r in $rules){if(Test-SchedulePeriod $Now ([string]$r.Day) ([string]$r.Start) ([string]$r.Stop)){$allowed=$true;break}}
        if(-not $allowed){$result+=$svc}
    }
    return @($result)
}

function Get-ExpandedBlockedDomains {
    param($Config)
    $domains=@()

    if($null -ne $Config.PSObject.Properties['BlockedServices']) {
        foreach($svc in @($Config.BlockedServices)) {
            foreach($x in @(Get-ServiceDomains ([string]$svc))) {
                $n=Normalize-Domain $x
                if(-not [string]::IsNullOrWhiteSpace($n)){ $domains += $n }
            }
        }
    }

    foreach($svc in @(Get-ScheduleBlockedServices $Config)) { foreach($x in @(Get-ServiceDomains ([string]$svc))){$n=Normalize-Domain $x;if(-not [string]::IsNullOrWhiteSpace($n)){$domains += $n}} }

    foreach($d in @($Config.BlockedDomains)) {
        foreach($x in @(Get-ServiceDomains ([string]$d))) {
            $n=Normalize-Domain $x
            if(-not [string]::IsNullOrWhiteSpace($n)){ $domains += $n }
        }
    }
    return @($domains | Sort-Object -Unique)
}

function Write-PacketEngineRules {
    param($Config)
    $AppDir=$script:WebsiteRulesAppDir
    $EngineDir=Join-Path $AppDir 'packetengine'
    New-Item -ItemType Directory -Force -Path $EngineDir | Out-Null
    $rules=Join-Path $EngineDir 'rules.txt'
    $tmp=$rules+'.tmp'
    $enabled=$false
    if($null -ne $Config.PSObject.Properties['WebsiteFilteringEnabled']){ $enabled=[bool]$Config.WebsiteFilteringEnabled }
    if(@(Get-ScheduleBlockedServices $Config).Count -gt 0){$enabled=$true}
    $lines=New-Object System.Collections.Generic.List[string]
    $lines.Add(('enabled=' + $(if($enabled){'1'}else{'0'})))
    $strictNative=$false
    if($null -ne $Config.PSObject.Properties['BlockedServices']) {
        foreach($svc in @($Config.BlockedServices)){ if(@('TikTok','Instagram','Snapchat') -contains [string]$svc){$strictNative=$true} }
    }
    foreach($svc in @(Get-ScheduleBlockedServices $Config)){ if(@('TikTok','Instagram','Snapchat') -contains [string]$svc){$strictNative=$true} }
    $lines.Add(('strictnative=' + $(if($strictNative){'1'}else{'0'})))
    if($strictNative){
        foreach($bypass in @('dns.google','cloudflare-dns.com','security.cloudflare-dns.com','family.cloudflare-dns.com','dns.quad9.net','doh.opendns.com','dns.nextdns.io','doh.cleanbrowsing.org')){ $lines.Add($bypass) }
    }
    if($enabled -and [string]$Config.FilteringMode -eq 'BlockList') {
        foreach($d in @(Get-ExpandedBlockedDomains $Config)){ $lines.Add($d) }
    }
    [IO.File]::WriteAllLines($tmp,[string[]]$lines,[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tmp -Destination $rules -Force
    return $rules
}

function Get-PacketEngineProcesses {
    try {
        return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object {
                ($_.Name -ieq 'powershell.exe' -or $_.Name -ieq 'pwsh.exe') -and
                $_.CommandLine -and $_.CommandLine -match 'PacketEngine\.ps1'
            })
    } catch { return @() }
}

function Ensure-PacketEngineRunning {
    $AppDir=$script:WebsiteRulesAppDir
    if(-not (Test-Path (Join-Path $AppDir 'packetengine\WinDivert.dll'))) {
        return 'Rules saved. Packet engine dependency is not installed; run Setup-Packet-Engine.cmd as Administrator once.'
    }
    try {
        $task=Get-ScheduledTask -TaskName 'HadiWiFiRouter-PacketEngine' -ErrorAction SilentlyContinue
        if($null -ne $task) {
            if($task.State -ne 'Running') { Start-ScheduledTask -TaskName 'HadiWiFiRouter-PacketEngine' }
            return 'Rules applied live. The packet engine will reload them automatically.'
        }
    } catch {}
    $engine=Join-Path $AppDir 'PacketEngine.ps1'
    try {
        Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$engine+'"')) | Out-Null
        return 'Rules applied live. Packet engine started for this session; run Setup-Packet-Engine.cmd once for pre-login operation.'
    } catch {
        return "Rules saved, but packet engine could not be started: $($_.Exception.Message)"
    }
}

function Apply-ClientWebsiteRules {
    param($Config)
    if([string]$Config.FilteringMode -ne 'BlockList' -and [bool]$Config.WebsiteFilteringEnabled) {
        return 'Strict AllowList is not enabled yet. Use BlockList for this build.'
    }
    [void](Write-PacketEngineRules $Config)
    return (Ensure-PacketEngineRunning)
}

function Apply-ExperimentalWebsiteRules { param($Config) return Apply-ClientWebsiteRules $Config }