Set-StrictMode -Version Latest
$ErrorActionPreference='Continue'
$script:ProtectedUsersGroup='HadiWiFiRouter Protected Users'
$script:ProtectedUsersQosPrefix='HadiWiFiRouter-Protected-'

function Get-HadiLocalUsers {
    $items=@()
    try {
        foreach($u in @(Get-LocalUser -ErrorAction Stop)) {
            $sid=[string]$u.SID.Value
            $isAdmin=$false
            try {
                $admins=@(Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue)
                $isAdmin=($admins | Where-Object { $_.SID -and [string]$_.SID.Value -eq $sid }).Count -gt 0
            } catch {}
            if($u.Name -in @('DefaultAccount','Guest','WDAGUtilityAccount')){continue}
            $items += [pscustomobject]@{UserName=[string]$u.Name;SID=$sid;Enabled=[bool]$u.Enabled;IsAdministrator=$isAdmin}
        }
    } catch {}
    return @($items)
}

function Resolve-HadiProtectedUserSid([string]$UserName,[string]$Sid) {
    if(-not [string]::IsNullOrWhiteSpace($Sid)){return $Sid}
    try { return [string](Get-LocalUser -Name $UserName -ErrorAction Stop).SID.Value } catch { return '' }
}

function ConvertTo-HadiLocalUserSddl([string]$Sid) {
    if([string]::IsNullOrWhiteSpace($Sid)){return ''}
    return "D:(A;;CC;;;$Sid)"
}

function Test-HadiWholeTrafficAllowed($Config,[datetime]$Now=(Get-Date)) {
    if(-not [bool]$Config.ScheduleEnabled){return $true}
    if($null -eq $Config.PSObject.Properties['ScheduleRules']){return $true}
    $rules=@($Config.ScheduleRules | Where-Object { [bool]$_.Enabled -and [string]$_.Target -eq 'Whole traffic' })
    if($rules.Count -eq 0){return $true}
    foreach($r in $rules){ if(Test-SchedulePeriod $Now ([string]$r.Day) ([string]$r.Start) ([string]$r.Stop)){return $true} }
    return $false
}

function Resolve-HadiDomainIPv4([string[]]$Domains,[int]$Max=300) {
    $ips=New-Object System.Collections.Generic.HashSet[string]
    foreach($d0 in @($Domains)) {
        $d=Normalize-Domain ([string]$d0)
        if([string]::IsNullOrWhiteSpace($d) -or $d.Contains('*')){continue}
        try {
            foreach($ip in [System.Net.Dns]::GetHostAddresses($d)) {
                if($ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork){[void]$ips.Add($ip.IPAddressToString)}
                if($ips.Count -ge $Max){return @($ips)}
            }
        } catch {}
    }
    return @($ips)
}

function Remove-HadiProtectedFirewallRules {
    try { Get-NetFirewallRule -Group $script:ProtectedUsersGroup -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue } catch {}
}

function Remove-HadiProtectedQosRules {
    try { Get-NetQosPolicy -ErrorAction SilentlyContinue | Where-Object {$_.Name -like "$($script:ProtectedUsersQosPrefix)*"} | Remove-NetQosPolicy -Confirm:$false -ErrorAction SilentlyContinue } catch {}
}

function New-HadiProtectedFirewallRule {
    param([string]$Name,[string]$Sid,[string[]]$RemoteAddress=@(),[string]$Protocol='Any',[string]$RemotePort='Any',[string]$Description='')
    $sddl=ConvertTo-HadiLocalUserSddl $Sid
    if([string]::IsNullOrWhiteSpace($sddl)){return}
    $params=@{DisplayName=$Name;Group=$script:ProtectedUsersGroup;Direction='Outbound';Action='Block';Profile='Any';LocalUser=$sddl;Enabled='True';ErrorAction='Stop'}
    if($RemoteAddress.Count -gt 0){$params.RemoteAddress=$RemoteAddress}
    if($Protocol -ne 'Any'){$params.Protocol=$Protocol}
    if($RemotePort -ne 'Any'){$params.RemotePort=$RemotePort}
    if(-not [string]::IsNullOrWhiteSpace($Description)){$params.Description=$Description}
    New-NetFirewallRule @params | Out-Null
}

function Get-HadiProtectedUsers($Config) {
    if($null -eq $Config.PSObject.Properties['ProtectedUsers']){return @()}
    return @($Config.ProtectedUsers | Where-Object {[bool]$_.Enabled})
}

function Apply-ProtectedUserRules {
    param($Config)
    Remove-HadiProtectedFirewallRules
    Remove-HadiProtectedQosRules
    $users=@(Get-HadiProtectedUsers $Config)
    if($users.Count -eq 0){return 'No protected Windows users are enabled.'}

    $wholeAllowed=Test-HadiWholeTrafficAllowed $Config
    $expanded=@()
    try { $expanded=@(Get-ExpandedBlockedDomains $Config) } catch {}
    $blockedIps=@()
    if($expanded.Count -gt 0){$blockedIps=@(Resolve-HadiDomainIPv4 $expanded 300)}
    $scheduleBlocked=@()
    try {$scheduleBlocked=@(Get-ScheduleBlockedServices $Config)}catch{}
    $strictService=(@($Config.BlockedServices)+$scheduleBlocked | Where-Object {$_ -in @('TikTok','Instagram','Snapchat')}).Count -gt 0

    $messages=@()
    foreach($u in $users) {
        $name=[string]$u.UserName
        $sid=Resolve-HadiProtectedUserSid $name ([string]$u.SID)
        if([string]::IsNullOrWhiteSpace($sid)){$messages += "$name: SID not found";continue}
        $safe=($name -replace '[^A-Za-z0-9_-]','_')
        if(-not $wholeAllowed) {
            try { New-HadiProtectedFirewallRule -Name "HadiWiFiRouter - $name - Whole traffic schedule" -Sid $sid -Description 'Blocks all outbound traffic for this protected Windows user outside the configured Whole traffic schedule.'; $messages += "$name: whole Internet blocked by schedule" } catch {$messages += "$name: whole-traffic rule error $($_.Exception.Message)"}
            continue
        }
        if($blockedIps.Count -gt 0) {
            try { New-HadiProtectedFirewallRule -Name "HadiWiFiRouter - $name - Website/service block" -Sid $sid -RemoteAddress $blockedIps -Description 'Best-effort IP enforcement of HadiWiFiRouter website/service rules for this Windows user.'; $messages += "$name: $($blockedIps.Count) blocked destination IPs applied" } catch {$messages += "$name: block-rule error $($_.Exception.Message)"}
        } else {$messages += "$name: Internet allowed; no resolved blocked destinations currently"}
        if($strictService) {
            try { New-HadiProtectedFirewallRule -Name "HadiWiFiRouter - $name - QUIC fallback" -Sid $sid -Protocol UDP -RemotePort '443' -Description 'Disables QUIC for the protected Windows user while strict native-service blocking is active.' } catch {}
            try { New-HadiProtectedFirewallRule -Name "HadiWiFiRouter - $name - DoT" -Sid $sid -Protocol TCP -RemotePort '853' -Description 'Blocks DNS-over-TLS for the protected Windows user while strict service filtering is active.' } catch {}
            try { New-HadiProtectedFirewallRule -Name "HadiWiFiRouter - $name - DoT UDP" -Sid $sid -Protocol UDP -RemotePort '853' -Description 'Blocks DNS-over-TLS/QUIC DNS on port 853 for the protected Windows user.' } catch {}
        }

        if($null -ne $Config.PSObject.Properties['SpeedControlEnabled'] -and [bool]$Config.SpeedControlEnabled -and $null -ne $Config.PSObject.Properties['SpeedRules']) {
            $policyIndex=0
            foreach($sr in @($Config.SpeedRules | Where-Object {[bool]$_.Enabled})) {
                $level=[string]$sr.Level; $kbps=1000
                if($level -eq 'Max'){$kbps=[int]$Config.SpeedPresets.MaxKbps}elseif($level -eq 'Low'){$kbps=[int]$Config.SpeedPresets.LowKbps}else{$kbps=[int]$Config.SpeedPresets.MediumKbps}
                $targets=@(Get-ServiceDomains ([string]$sr.Domain)); $targetIps=@(Resolve-HadiDomainIPv4 $targets 40)
                foreach($ip in $targetIps) {
                    if($policyIndex -ge 80){break}
                    $pname="$($script:ProtectedUsersQosPrefix)$safe-$policyIndex"
                    try { New-NetQosPolicy -Name $pname -UserMatchCondition "$env:COMPUTERNAME\$name" -IPDstPrefixMatchCondition "$ip/32" -ThrottleRateActionBitsPerSecond ([uint64]($kbps*1000)) -PolicyStore ActiveStore -ErrorAction Stop | Out-Null } catch {}
                    $policyIndex++
                }
            }
        }
    }
    return ($messages -join '; ')
}
