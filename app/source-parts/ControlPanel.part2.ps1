
# Speed Control tab
$speedEnable = New-Object Windows.Forms.CheckBox
$speedEnable.Text='Enable website speed control for hotspot clients'
$speedEnable.Location=New-Object Drawing.Point(30,25)
$speedEnable.Size=New-Object Drawing.Size(420,30)
$speedEnable.Checked=($null -ne $c.PSObject.Properties['SpeedControlEnabled'] -and [bool]$c.SpeedControlEnabled)
$tabSpeed.Controls.Add($speedEnable)

Label $tabSpeed 'Presets:  Max = 5 Mbps     Medium = 1 Mbps     Low = 256 Kbps' 30 62 760 | Out-Null
Label $tabSpeed 'These rules target hotspot-client traffic only; the PC itself is not intentionally throttled.' 30 90 780 | Out-Null

$speedGrid = New-Object Windows.Forms.DataGridView
$speedGrid.Location=New-Object Drawing.Point(30,130)
$speedGrid.Size=New-Object Drawing.Size(790,300)
$speedGrid.AllowUserToAddRows=$false
$speedGrid.AllowUserToDeleteRows=$false
$speedGrid.RowHeadersVisible=$false
$speedGrid.AutoSizeColumnsMode='Fill'
$speedGrid.SelectionMode='FullRowSelect'
$speedGrid.MultiSelect=$false
$tabSpeed.Controls.Add($speedGrid)

$spEnabled=New-Object Windows.Forms.DataGridViewCheckBoxColumn; $spEnabled.Name='Enabled'; $spEnabled.HeaderText='Enabled'; $spEnabled.FillWeight=15
$spDomain=New-Object Windows.Forms.DataGridViewTextBoxColumn; $spDomain.Name='Domain'; $spDomain.HeaderText='Website / service'; $spDomain.FillWeight=55
$spLevel=New-Object Windows.Forms.DataGridViewComboBoxColumn; $spLevel.Name='Level'; $spLevel.HeaderText='Speed'; $spLevel.FillWeight=30; [void]$spLevel.Items.AddRange(@('Max','Medium','Low'))
[void]$speedGrid.Columns.Add($spEnabled)
[void]$speedGrid.Columns.Add($spDomain)
[void]$speedGrid.Columns.Add($spLevel)

if($null -ne $c.PSObject.Properties['SpeedRules']){
    foreach($r in @($c.SpeedRules)){
        [void]$speedGrid.Rows.Add([bool]$r.Enabled,[string]$r.Domain,[string]$r.Level)
    }
}

$addSpeed=Button $tabSpeed 'Add target' 30 455 150
$removeSpeed=Button $tabSpeed 'Remove selected' 195 455 165
$saveSpeed=Button $tabSpeed 'Save && apply now' 375 455 180
Label $tabSpeed 'Hotspot subnet' 580 463 115 | Out-Null
$subnet=TextBox $tabSpeed 695 458 125
$subnet.Text = if($null -ne $c.PSObject.Properties['HotspotSubnet']){[string]$c.HotspotSubnet}else{'192.168.137.0/24'}
$speedStatus=Label $tabSpeed 'Enter YouTube, TikTok, Instagram, Snapchat, or a custom domain. Service names expand to multiple domains/CDNs. Status: not applied yet.' 30 520 790; $speedStatus.Height=75

# Connected Devices tab
$refreshDevices=Button $tabDevices 'Refresh now' 30 25 150
$autoDevices=New-Object Windows.Forms.CheckBox; $autoDevices.Text='Auto refresh every 3 seconds'; $autoDevices.Location=New-Object Drawing.Point(205,30); $autoDevices.Size=New-Object Drawing.Size(260,30); $autoDevices.Checked=$true; $tabDevices.Controls.Add($autoDevices)
$deviceCount=Label $tabDevices 'Connected devices: checking...' 500 31 320

$deviceGrid=New-Object Windows.Forms.DataGridView
$deviceGrid.Location=New-Object Drawing.Point(30,85)
$deviceGrid.Size=New-Object Drawing.Size(790,430)
$deviceGrid.ReadOnly=$true
$deviceGrid.AllowUserToAddRows=$false
$deviceGrid.AllowUserToDeleteRows=$false
$deviceGrid.RowHeadersVisible=$false
$deviceGrid.AutoSizeColumnsMode='Fill'
$deviceGrid.SelectionMode='FullRowSelect'
$tabDevices.Controls.Add($deviceGrid)
foreach($spec in @(@('Device','Device',28),@('IPAddress','IP address',20),@('MACAddress','MAC address',24),@('State','State',14),@('Interface','Interface',28))){
    $col=New-Object Windows.Forms.DataGridViewTextBoxColumn; $col.Name=$spec[0]; $col.HeaderText=$spec[1]; $col.FillWeight=$spec[2]; [void]$deviceGrid.Columns.Add($col)
}
$deviceNote=Label $tabDevices 'Private/randomized MAC addresses may be used by phones. A device can still usually be recognized consistently on this Wi-Fi network.' 30 535 790; $deviceNote.Height=55

# Remote Access tab
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
