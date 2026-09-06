Label $tabWeb 'Mode' 30 30 | Out-Null
$mode=New-Object Windows.Forms.ComboBox; $mode.Location=New-Object Drawing.Point(220,27); $mode.Size=New-Object Drawing.Size(220,28); [void]$mode.Items.AddRange(@('BlockList','AllowList')); $mode.SelectedItem=$c.FilteringMode; $tabWeb.Controls.Add($mode)
$exp=New-Object Windows.Forms.CheckBox; $exp.Text='Enable blocking for hotspot clients'; $exp.Location=New-Object Drawing.Point(30,75); $exp.Size=New-Object Drawing.Size(360,30); $exp.Checked=if($null -ne $c.PSObject.Properties['WebsiteFilteringEnabled']){[bool]$c.WebsiteFilteringEnabled}else{[bool]$c.ExperimentalFiltering}; $tabWeb.Controls.Add($exp)
Label $tabWeb 'Service profiles' 30 118 220 | Out-Null
$svcYoutube=New-Object Windows.Forms.CheckBox; $svcYoutube.Text='YouTube'; $svcYoutube.Location=New-Object Drawing.Point(30,145); $svcYoutube.Size=New-Object Drawing.Size(120,28); $tabWeb.Controls.Add($svcYoutube)
$svcTikTok=New-Object Windows.Forms.CheckBox; $svcTikTok.Text='TikTok'; $svcTikTok.Location=New-Object Drawing.Point(155,145); $svcTikTok.Size=New-Object Drawing.Size(100,28); $tabWeb.Controls.Add($svcTikTok)
$svcInstagram=New-Object Windows.Forms.CheckBox; $svcInstagram.Text='Instagram'; $svcInstagram.Location=New-Object Drawing.Point(260,145); $svcInstagram.Size=New-Object Drawing.Size(120,28); $tabWeb.Controls.Add($svcInstagram)
$svcSnapchat=New-Object Windows.Forms.CheckBox; $svcSnapchat.Text='Snapchat'; $svcSnapchat.Location=New-Object Drawing.Point(385,145); $svcSnapchat.Size=New-Object Drawing.Size(120,28); $tabWeb.Controls.Add($svcSnapchat)
$blockedServices=@(); if($null -ne $c.PSObject.Properties['BlockedServices']){$blockedServices=@($c.BlockedServices)}
$svcYoutube.Checked=($blockedServices -contains 'YouTube'); $svcTikTok.Checked=($blockedServices -contains 'TikTok'); $svcInstagram.Checked=($blockedServices -contains 'Instagram'); $svcSnapchat.Checked=($blockedServices -contains 'Snapchat')

Label $tabWeb 'Custom blocked domains (one per line)' 30 188 280 | Out-Null
$blocked=New-Object Windows.Forms.TextBox; $blocked.Multiline=$true; $blocked.ScrollBars='Vertical'; $blocked.Location=New-Object Drawing.Point(30,220); $blocked.Size=New-Object Drawing.Size(310,205); $blocked.Text=(@($c.BlockedDomains)-join [Environment]::NewLine); $tabWeb.Controls.Add($blocked)
Label $tabWeb 'Allowed domains (strict mode - packet engine required)' 375 188 330 | Out-Null
$allowed=New-Object Windows.Forms.TextBox; $allowed.Multiline=$true; $allowed.ScrollBars='Vertical'; $allowed.Location=New-Object Drawing.Point(375,220); $allowed.Size=New-Object Drawing.Size(310,205); $allowed.Text=(@($c.AllowedDomains)-join [Environment]::NewLine); $tabWeb.Controls.Add($allowed)
$warn=Label $tabWeb 'v2.2 adds strict native-app service blocking for TikTok, Instagram and Snapchat using expanded service profiles, TLS SNI inspection and QUIC fallback control. PC-originated traffic is not filtered.' 30 442 700; $warn.Height=70
$saveWeb=Button $tabWeb 'Save website rules' 30 525 190

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
    foreach($r in @($c.SpeedRules)){[void]$speedGrid.Rows.Add([bool]$r.Enabled,[string]$r.Domain,[string]$r.Level)}
}
$addSpeed=Button $tabSpeed 'Add target' 30 455 150
$removeSpeed=Button $tabSpeed 'Remove selected' 195 455 165
$saveSpeed=Button $tabSpeed 'Save && apply now' 375 455 180
Label $tabSpeed 'Hotspot subnet' 580 463 115 | Out-Null
$subnet=TextBox $tabSpeed 695 458 125
$subnet.Text = if($null -ne $c.PSObject.Properties['HotspotSubnet']){[string]$c.HotspotSubnet}else{'192.168.137.0/24'}
$speedStatus=Label $tabSpeed 'Enter YouTube, TikTok, Instagram, Snapchat, or a custom domain. Service names expand to multiple domains/CDNs. Status: not applied yet.' 30 520 790; $speedStatus.Height=75

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

$puTitle=Label $tabUsers 'Protect selected non-administrator Windows accounts with the same HadiWiFiRouter policies.' 30 25 790
$puTitle.Font=New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)
$puInfo=Label $tabUsers 'The PC stays connected to the normal home Wi-Fi. The selected Windows account is restricted at the Windows network layer, so the administrator account remains unrestricted.' 30 60 790; $puInfo.Height=55
$puGrid=New-Object Windows.Forms.DataGridView
$puGrid.Location=New-Object Drawing.Point(30,125);$puGrid.Size=New-Object Drawing.Size(790,300);$puGrid.AllowUserToAddRows=$false;$puGrid.AllowUserToDeleteRows=$false;$puGrid.RowHeadersVisible=$false;$puGrid.AutoSizeColumnsMode='Fill';$puGrid.SelectionMode='FullRowSelect';$tabUsers.Controls.Add($puGrid)
$puEn=New-Object Windows.Forms.DataGridViewCheckBoxColumn;$puEn.Name='Protected';$puEn.HeaderText='Protect';$puEn.FillWeight=15
$puName=New-Object Windows.Forms.DataGridViewTextBoxColumn;$puName.Name='UserName';$puName.HeaderText='Windows user';$puName.ReadOnly=$true;$puName.FillWeight=30
$puSid=New-Object Windows.Forms.DataGridViewTextBoxColumn;$puSid.Name='SID';$puSid.HeaderText='SID';$puSid.ReadOnly=$true;$puSid.FillWeight=42
