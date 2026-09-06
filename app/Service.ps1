param([switch]$Once)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $AppDir
$ConfigPath = Join-Path $AppDir 'config.json'
$LogPath = Join-Path $Root 'logs\service.log'
. (Join-Path $AppDir 'HotspotCore.ps1')
. (Join-Path $AppDir 'WebsiteRules.ps1')
. (Join-Path $AppDir 'SpeedRules.ps1')

function Log([string]$Text) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Text"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Load-Config {
    return (Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-DaySchedule($c, [string]$dayName) {
    if ($null -ne $c.DaySchedules -and $null -ne $c.DaySchedules.$dayName) {
        return $c.DaySchedules.$dayName
    }
    # Backward compatibility with v0.4 settings.
    return [pscustomobject]@{
        Enabled = (@($c.Days) -contains $dayName)
        Start = [string]$c.StartTime
        Stop = [string]$c.StopTime
    }
}

function Test-Window([TimeSpan]$now, [TimeSpan]$start, [TimeSpan]$stop) {
    if ($start -eq $stop) { return $true } # 24 hours
    if ($start -lt $stop) { return ($now -ge $start -and $now -lt $stop) }
    return ($now -ge $start) # overnight portion before midnight is handled today
}

function Is-InSchedule($c) {
    if (-not $c.HotspotEnabled) { return $false }
    if (-not $c.ScheduleEnabled) { return $true }
    if($null -ne $c.PSObject.Properties['ScheduleRules']){
        $whole=@($c.ScheduleRules|Where-Object{[bool]$_.Enabled -and [string]$_.Target -eq 'Whole traffic'})
        if($whole.Count -eq 0){return $true} # schedules exist only for services; keep Wi-Fi on
        $now=Get-Date
        foreach($r in $whole){ if(Test-SchedulePeriod $now ([string]$r.Day) ([string]$r.Start) ([string]$r.Stop)){return $true} }
        return $false
    }
    $nowDate = Get-Date;$todayName=$nowDate.DayOfWeek.ToString();$today=Get-DaySchedule $c $todayName;$now=$nowDate.TimeOfDay
    if([bool]$today.Enabled){$start=[TimeSpan]::Parse($today.Start);$stop=[TimeSpan]::Parse($today.Stop);if($start -eq $stop){return $true};if($start -lt $stop){if($now -ge $start -and $now -lt $stop){return $true}}else{if($now -ge $start){return $true}}}
    $yesterdayDate=$nowDate.AddDays(-1);$yesterday=Get-DaySchedule $c $yesterdayDate.DayOfWeek.ToString();if([bool]$yesterday.Enabled){$ystart=[TimeSpan]::Parse($yesterday.Start);$ystop=[TimeSpan]::Parse($yesterday.Stop);if($ystart -gt $ystop -and $now -lt $ystop){return $true}}
    return $false
}

$lastDesired = $null
$lastConfigSignature = $null
$filterRefresh = [datetime]::MinValue
$speedRefresh = [datetime]::MinValue
Log "Background engine started as $([Security.Principal.WindowsIdentity]::GetCurrent().Name)."

while ($true) {
    try {
        $c = Load-Config
        $desired = Is-InSchedule $c
        $configSignature = "$($c.SSID)`n$($c.Password)"
        if ($desired) {
            try {
                $s = Get-HotspotStatus
                if ($s.State -ne 'On') {
                    $r = Start-Hotspot -SSID $c.SSID -Password $c.Password
                    $lastConfigSignature = $configSignature
                    Log "Start hotspot requested. Status=$($r.Status), State=$($r.State), Message=$($r.AdditionalErrorMessage)"
                } elseif ($null -ne $lastConfigSignature -and $lastConfigSignature -ne $configSignature) {
                    $r = Restart-Hotspot -SSID $c.SSID -Password $c.Password
                    $lastConfigSignature = $configSignature
                    Log "Hotspot configuration changed; restarted. Status=$($r.Status), State=$($r.State), Message=$($r.AdditionalErrorMessage)"
                } elseif ($null -eq $lastConfigSignature) {
                    $lastConfigSignature = $configSignature
                }
            } catch {
                Log "Hotspot start/status error: $($_.Exception.Message)"
            }
        } else {
            try {
                $s = Get-HotspotStatus
                if ($s.State -eq 'On') {
                    $r = Stop-Hotspot
                    Log "Stop hotspot requested. Status=$($r.Status), State=$($r.State)"
                }
            } catch {
                Log "Hotspot stop/status error: $($_.Exception.Message)"
            }
        }

        if ((Get-Date) -gt $filterRefresh.AddSeconds(15)) {
            try { [void](Write-PacketEngineRules $c) } catch { Log "Filter-rule refresh error: $($_.Exception.Message)" }
            $filterRefresh = Get-Date
        }

        if ((Get-Date) -gt $speedRefresh.AddMinutes(2)) {
            try { Log (Apply-SpeedRules $c) } catch { Log "Speed-control error: $($_.Exception.Message)" }
            $speedRefresh = Get-Date
        }
    } catch {
        Log "Engine loop error: $($_.Exception.Message)"
    }
    if ($Once) { break }
    Start-Sleep -Seconds 20
}