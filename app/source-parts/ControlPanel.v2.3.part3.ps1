$puAdmin=New-Object Windows.Forms.DataGridViewTextBoxColumn;$puAdmin.Name='Type';$puAdmin.HeaderText='Type';$puAdmin.ReadOnly=$true;$puAdmin.FillWeight=18
[void]$puGrid.Columns.Add($puEn);[void]$puGrid.Columns.Add($puName);[void]$puGrid.Columns.Add($puSid);[void]$puGrid.Columns.Add($puAdmin)
$refreshUsers=Button $tabUsers 'Refresh users' 30 450 150
$saveUsers=Button $tabUsers 'Save && apply' 195 450 170
$puStatus=Label $tabUsers 'Select Roshana (or another Standard user), then Save && apply.' 385 457 430;$puStatus.Height=65
$puWarn=Label $tabUsers 'Current v2.3 enforcement: Whole-traffic schedules are strong per-user firewall rules. Custom-domain/service blocking and speed limits are best-effort destination-IP/QoS rules; the planned v3 user-aware WFP/routing backend will make service identification more robust.' 30 520 790;$puWarn.Height=85
function Refresh-ProtectedUserGrid {
    $cfg=LoadConfig;$existing=@{};$existingName=@{};if($null -ne $cfg.PSObject.Properties['ProtectedUsers']){foreach($x in @($cfg.ProtectedUsers)){if(-not [string]::IsNullOrWhiteSpace([string]$x.SID)){$existing[[string]$x.SID]=[bool]$x.Enabled};$existingName[[string]$x.UserName]=[bool]$x.Enabled}}
    $puGrid.Rows.Clear()
    foreach($u in @(Get-HadiLocalUsers)){
        if($u.IsAdministrator){continue}
        $checked=$false;if($existing.ContainsKey([string]$u.SID)){$checked=$existing[[string]$u.SID]}elseif($existingName.ContainsKey([string]$u.UserName)){$checked=$existingName[[string]$u.UserName]}
        [void]$puGrid.Rows.Add($checked,[string]$u.UserName,[string]$u.SID,'Standard')
    }
}
Refresh-ProtectedUserGrid

$remoteTitle=Label $tabRemote 'Secure remote control over the Internet' 30 30 520; $remoteTitle.Font=New-Object Drawing.Font('Segoe UI',12,[Drawing.FontStyle]::Bold)
$remoteInfo=Label $tabRemote 'The remote panel runs before Windows logon and is exposed only through your private Tailscale network. No router port-forwarding is used.' 30 72 760; $remoteInfo.Height=55
$remoteStatus=Label $tabRemote 'Remote status: not checked' 30 140 760; $remoteStatus.Height=75
$setupRemote=Button $tabRemote 'Setup / Repair Remote Access' 30 225 240
$openLocalRemote=Button $tabRemote 'Open local web panel' 290 225 190
$refreshRemote=Button $tabRemote 'Refresh remote status' 500 225 190
Label $tabRemote 'Remote URL / administrator key' 30 300 300 | Out-Null
$remoteDetails=New-Object Windows.Forms.TextBox; $remoteDetails.Multiline=$true; $remoteDetails.ReadOnly=$true; $remoteDetails.ScrollBars='Vertical'; $remoteDetails.Location=New-Object Drawing.Point(30,335); $remoteDetails.Size=New-Object Drawing.Size(660,170); $tabRemote.Controls.Add($remoteDetails)
$remoteNote=Label $tabRemote 'One-time requirement: Tailscale must be installed and authenticated on this PC and on your iPhone. After setup, Tailscale runs unattended as SYSTEM, so Windows login is not required.' 30 525 760; $remoteNote.Height=70

function Refresh-RemoteStatus {
    $infoPath=Join-Path $Root 'REMOTE-ACCESS-INFO.txt'
    $taskState='Not installed'
    try{ $t=Get-ScheduledTask -TaskName 'HadiWiFiRouter-RemotePanel' -ErrorAction SilentlyContinue; if($null -ne $t){$taskState=[string]$t.State} }catch{}
    $local='Not responding'
    try{ $r=Invoke-WebRequest -Uri 'http://127.0.0.1:8787/health' -UseBasicParsing -TimeoutSec 2; if($r.StatusCode -eq 200){$local='Running'} }catch{}
    $ts='Not found'
    try{
        $tsExe='C:\Program Files\Tailscale\tailscale.exe'
        if(-not (Test-Path $tsExe)){ $cmd=Get-Command tailscale.exe -ErrorAction SilentlyContinue; if($cmd){$tsExe=$cmd.Source} }
        if(Test-Path $tsExe){ $out=& $tsExe status --json 2>$null | ConvertFrom-Json; if($out -and $out.BackendState){$ts=[string]$out.BackendState}else{$ts='Installed'} }
    }catch{$ts='Installed / status unavailable'}
    $remoteStatus.Text="Remote service task: $taskState`r`nLocal web panel: $local    |    Tailscale: $ts"
    if(Test-Path $infoPath){$remoteDetails.Text=Get-Content $infoPath -Raw}else{$remoteDetails.Text="Run Setup-Remote-Access.cmd once as Administrator."}
}
$setupRemote.Add_Click({ Start-Process (Join-Path $Root 'Setup-Remote-Access.cmd') -Verb RunAs })
$openLocalRemote.Add_Click({ Start-Process 'http://127.0.0.1:8787/' })
$refreshRemote.Add_Click({ Refresh-RemoteStatus })

$runDiag=Button $tabDiag 'Run diagnostics' 30 30 180
$refresh=Button $tabDiag 'Refresh status' 230 30 180
$openLogs=Button $tabDiag 'Open logs folder' 430 30 180
$outBox=New-Object Windows.Forms.TextBox; $outBox.Multiline=$true; $outBox.ScrollBars='Both'; $outBox.ReadOnly=$true; $outBox.Location=New-Object Drawing.Point(30,90); $outBox.Size=New-Object Drawing.Size(655,455); $tabDiag.Controls.Add($outBox)

$saveHot.Add_Click({
    try {
        $x=LoadConfig
        $x.HotspotEnabled=$enable.Checked
        $x.SSID=$ssid.Text.Trim()
        $x.Password=$pass.Text
        SaveConfig $x
        $s = Get-HotspotStatus
        if ($x.HotspotEnabled -and $s.State -eq 'On') {
            $statusLabel.Text='Applying changes: restarting Wi-Fi...'
            [Windows.Forms.Application]::DoEvents()
            $r = Restart-Hotspot -SSID $x.SSID -Password $x.Password
            $statusLabel.Text="Status: $($r.State) / $($r.Status) $($r.AdditionalErrorMessage)"
            [Windows.Forms.MessageBox]::Show('Saved and applied. The Wi-Fi was restarted with the new name/password.') | Out-Null
        } else {
            [Windows.Forms.MessageBox]::Show('Saved. The new name/password will be used the next time Wi-Fi starts.') | Out-Null
        }
    } catch {
        $statusLabel.Text="ERROR: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show("Could not apply settings:`r`n$($_.Exception.Message)") | Out-Null
    }
})
$start.Add_Click({ try{$r=Start-Hotspot -SSID $ssid.Text -Password $pass.Text; $statusLabel.Text="Status: $($r.State) / $($r.Status) $($r.AdditionalErrorMessage)"}catch{$statusLabel.Text="ERROR: $($_.Exception.Message)"} })
$stop.Add_Click({ try{$r=Stop-Hotspot; $statusLabel.Text="Status: $($r.State) / $($r.Status)"}catch{$statusLabel.Text="ERROR: $($_.Exception.Message)"} })
$addSchedule.Add_Click({
    $today=(Get-Date).DayOfWeek.ToString(); if($today -eq 'Sunday'){$today='Sunday'}
    [void]$grid.Rows.Add($true,$today,'Whole traffic','06:00','22:00')
})
$removeSchedule.Add_Click({ if($null -ne $grid.CurrentRow){$grid.Rows.Remove($grid.CurrentRow)} })
$copySchedule.Add_Click({
    if($null -eq $grid.CurrentRow){return}
    $r=$grid.CurrentRow
    $target=[string]$r.Cells['Target'].Value;$startT=[string]$r.Cells['Start'].Value;$stopT=[string]$r.Cells['Stop'].Value;$en=[bool]$r.Cells['Enabled'].Value
    foreach($d in $dayNames){ if($d -ne [string]$r.Cells['Day'].Value){[void]$grid.Rows.Add($en,$d,$target,$startT,$stopT)} }
})
