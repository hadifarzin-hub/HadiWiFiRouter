$saveSch.Add_Click({
    $rules=@()
    foreach($row in $grid.Rows){
        $d=[string]$row.Cells['Day'].Value;$target=[string]$row.Cells['Target'].Value;$startText=[string]$row.Cells['Start'].Value;$stopText=[string]$row.Cells['Stop'].Value
        if($d -notin $dayNames){[Windows.Forms.MessageBox]::Show('Select a valid day for every schedule row.')|Out-Null;return}
        if($target -notin @('Whole traffic','YouTube','TikTok','Instagram','Snapchat')){[Windows.Forms.MessageBox]::Show('Select a valid target for every schedule row.')|Out-Null;return}
        $tmp=[TimeSpan]::Zero
        if(-not [TimeSpan]::TryParseExact($startText,'hh\:mm',$null,[ref]$tmp)){[Windows.Forms.MessageBox]::Show("Invalid start time for $d / $target. Use HH:mm.")|Out-Null;return}
        if(-not [TimeSpan]::TryParseExact($stopText,'hh\:mm',$null,[ref]$tmp)){[Windows.Forms.MessageBox]::Show("Invalid stop time for $d / $target. Use HH:mm.")|Out-Null;return}
        $rules += [pscustomobject]@{Enabled=[bool]$row.Cells['Enabled'].Value;Day=$d;Target=$target;Start=$startText;Stop=$stopText}
    }
    $x=LoadConfig;$x.ScheduleEnabled=$sch.Checked
    if($null -eq $x.PSObject.Properties['ScheduleRules']){$x|Add-Member -NotePropertyName ScheduleRules -NotePropertyValue $rules}else{$x.ScheduleRules=$rules}
    SaveConfig $x
    try{[void](Write-PacketEngineRules $x)}catch{}
    [Windows.Forms.MessageBox]::Show('Target schedules saved and applied. Changes take effect automatically.')|Out-Null
})
$saveWeb.Add_Click({ try{$x=LoadConfig;$x.FilteringMode=$mode.SelectedItem.ToString();$x.ExperimentalFiltering=$false;if($null -eq $x.PSObject.Properties['WebsiteFilteringEnabled']){$x|Add-Member -NotePropertyName WebsiteFilteringEnabled -NotePropertyValue $exp.Checked}else{$x.WebsiteFilteringEnabled=$exp.Checked};$services=@();if($svcYoutube.Checked){$services+='YouTube'};if($svcTikTok.Checked){$services+='TikTok'};if($svcInstagram.Checked){$services+='Instagram'};if($svcSnapchat.Checked){$services+='Snapchat'};if($null -eq $x.PSObject.Properties['BlockedServices']){$x|Add-Member -NotePropertyName BlockedServices -NotePropertyValue $services}else{$x.BlockedServices=$services};$x.BlockedDomains=@($blocked.Lines|?{$_.Trim()});$x.AllowedDomains=@($allowed.Lines|?{$_.Trim()});SaveConfig $x;$msg=Apply-ClientWebsiteRules $x;[Windows.Forms.MessageBox]::Show("Website rules saved. $msg")|Out-Null}catch{[Windows.Forms.MessageBox]::Show("Website filter error: $($_.Exception.Message)")|Out-Null} })

$addSpeed.Add_Click({
    [void]$speedGrid.Rows.Add($true,'','Medium')
    if($speedGrid.Rows.Count -gt 0){ $speedGrid.CurrentCell=$speedGrid.Rows[$speedGrid.Rows.Count-1].Cells['Domain']; $speedGrid.BeginEdit($true) }
})
$removeSpeed.Add_Click({if($null -ne $speedGrid.CurrentRow){ $speedGrid.Rows.Remove($speedGrid.CurrentRow) }})
$saveSpeed.Add_Click({
    try{
        $rules=@()
        foreach($row in $speedGrid.Rows){
            $domain=[string]$row.Cells['Domain'].Value
            if([string]::IsNullOrWhiteSpace($domain)){ continue }
            $level=[string]$row.Cells['Level'].Value
            if($level -notin @('Max','Medium','Low')){$level='Medium'}
            $rules += [pscustomobject]@{Enabled=[bool]$row.Cells['Enabled'].Value;Domain=$domain.Trim();Level=$level}
        }
        $x=LoadConfig
        if($null -eq $x.PSObject.Properties['SpeedControlEnabled']){$x|Add-Member -NotePropertyName SpeedControlEnabled -NotePropertyValue $speedEnable.Checked}else{$x.SpeedControlEnabled=$speedEnable.Checked}
        if($null -eq $x.PSObject.Properties['HotspotSubnet']){$x|Add-Member -NotePropertyName HotspotSubnet -NotePropertyValue $subnet.Text.Trim()}else{$x.HotspotSubnet=$subnet.Text.Trim()}
        if($null -eq $x.PSObject.Properties['SpeedPresets']){$x|Add-Member -NotePropertyName SpeedPresets -NotePropertyValue ([pscustomobject]@{MaxKbps=5000;MediumKbps=1000;LowKbps=256})}
        if($null -eq $x.PSObject.Properties['SpeedRules']){$x|Add-Member -NotePropertyName SpeedRules -NotePropertyValue $rules}else{$x.SpeedRules=$rules}
        SaveConfig $x
        $speedStatus.Text='Applying speed rules...'
        [Windows.Forms.Application]::DoEvents()
        $msg=Apply-SpeedRules $x
        $speedStatus.Text="Status: $msg"
    }catch{$speedStatus.Text="ERROR: $($_.Exception.Message)"}
})

$refreshUsers.Add_Click({Refresh-ProtectedUserGrid})
$saveUsers.Add_Click({
    try{
        $arr=@()
        foreach($row in $puGrid.Rows){
            if([bool]$row.Cells['Protected'].Value){$arr += [pscustomobject]@{Enabled=$true;UserName=[string]$row.Cells['UserName'].Value;SID=[string]$row.Cells['SID'].Value;Policy='Same as controlled Wi-Fi'}}
        }
        $x=LoadConfig
        if($null -eq $x.PSObject.Properties['ProtectedUsersEnabled']){$x|Add-Member -NotePropertyName ProtectedUsersEnabled -NotePropertyValue $true}else{$x.ProtectedUsersEnabled=$true}
        if($null -eq $x.PSObject.Properties['ProtectedUsers']){$x|Add-Member -NotePropertyName ProtectedUsers -NotePropertyValue $arr}else{$x.ProtectedUsers=$arr}
        SaveConfig $x
        $puStatus.Text='Applying protected-user policies...';[Windows.Forms.Application]::DoEvents()
        $puStatus.Text='Status: '+(Apply-ProtectedUserRules $x)
    }catch{$puStatus.Text='ERROR: '+$_.Exception.Message}
})

function Refresh-DeviceGrid {
    try{
        $x=LoadConfig
        $hs = if($null -ne $x.PSObject.Properties['HotspotSubnet']){[string]$x.HotspotSubnet}else{'192.168.137.0/24'}
        $rows=@(Get-HotspotClientRows -Subnet $hs)
        $deviceGrid.Rows.Clear()
        foreach($r in $rows){ [void]$deviceGrid.Rows.Add($r.Device,$r.IPAddress,$r.MACAddress,$r.State,$r.Interface) }
        try{ $st=Get-HotspotStatus; $deviceCount.Text="Connected devices: $($st.ClientCount)  |  Visible in neighbor table: $($rows.Count)" }
        catch{ $deviceCount.Text="Visible devices: $($rows.Count)" }
    }catch{ $deviceCount.Text="Device refresh error: $($_.Exception.Message)" }
}
$refreshDevices.Add_Click({ Refresh-DeviceGrid })
$deviceTimer=New-Object Windows.Forms.Timer
$deviceTimer.Interval=3000
$deviceTimer.Add_Tick({ if($autoDevices.Checked -and $tabs.SelectedTab -eq $tabDevices){ Refresh-DeviceGrid } })
$deviceTimer.Start()
$tabs.Add_SelectedIndexChanged({ if($tabs.SelectedTab -eq $tabDevices){ Refresh-DeviceGrid }; if($tabs.SelectedTab -eq $tabRemote){ Refresh-RemoteStatus } })
$runDiag.Add_Click({ & (Join-Path $AppDir 'Diagnostics.ps1'); $outBox.Text=Get-Content (Join-Path $Root 'logs\diagnostics.txt') -Raw })
$refresh.Add_Click({ $logText = 'No service log yet.'; if(Test-Path $LogPath){ $logText = (Get-Content $LogPath -Tail 60 | Out-String) }; try{$s=Get-HotspotStatus;$outBox.Text="Hotspot state: $($s.State)`r`nClients: $($s.ClientCount) / $($s.MaxClientCount)`r`n`r`n" + $logText}catch{$outBox.Text="ERROR: $($_.Exception.Message)`r`n`r`n" + $logText} })
$openLogs.Add_Click({ Start-Process explorer.exe (Join-Path $Root 'logs') })

[void]$form.ShowDialog()
