Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $AppDir
$ConfigPath = Join-Path $AppDir 'config.json'
$LogPath = Join-Path $Root 'logs\service.log'
. (Join-Path $AppDir 'HotspotCore.ps1')
. (Join-Path $AppDir 'WebsiteRules.ps1')
. (Join-Path $AppDir 'SpeedRules.ps1')
. (Join-Path $AppDir 'ConnectedDevices.ps1')
. (Join-Path $AppDir 'ProtectedUsers.ps1')

function LoadConfig { Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json }
function SaveConfig($c) { $c | ConvertTo-Json -Depth 6 | Set-Content $ConfigPath -Encoding UTF8 }

$form = New-Object Windows.Forms.Form
$form.Text = 'Hadi WiFi Router - Portable Control Panel v2.3'
$form.Size = New-Object Drawing.Size(900,720)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI',10)

$tabs = New-Object Windows.Forms.TabControl
$tabs.Dock='Fill'
$form.Controls.Add($tabs)

$tabHot = New-Object Windows.Forms.TabPage; $tabHot.Text='Hotspot'
$tabSchedule = New-Object Windows.Forms.TabPage; $tabSchedule.Text='Schedule'
$tabWeb = New-Object Windows.Forms.TabPage; $tabWeb.Text='Website Rules'
$tabSpeed = New-Object Windows.Forms.TabPage; $tabSpeed.Text='Speed Control'
$tabDevices = New-Object Windows.Forms.TabPage; $tabDevices.Text='Connected Devices'
$tabUsers = New-Object Windows.Forms.TabPage; $tabUsers.Text='Protected Users'
$tabRemote = New-Object Windows.Forms.TabPage; $tabRemote.Text='Remote Access'
$tabDiag = New-Object Windows.Forms.TabPage; $tabDiag.Text='Status / Diagnostics'
[void]$tabs.TabPages.AddRange(@($tabHot,$tabSchedule,$tabWeb,$tabSpeed,$tabDevices,$tabUsers,$tabRemote,$tabDiag))

function Label($parent,$text,$x,$y,$w=180) { $l=New-Object Windows.Forms.Label; $l.Text=$text; $l.Location=New-Object Drawing.Point($x,$y); $l.Size=New-Object Drawing.Size($w,28); $parent.Controls.Add($l); return $l }
function TextBox($parent,$x,$y,$w=360) { $t=New-Object Windows.Forms.TextBox; $t.Location=New-Object Drawing.Point($x,$y); $t.Size=New-Object Drawing.Size($w,28); $parent.Controls.Add($t); return $t }
function Button($parent,$text,$x,$y,$w=150) { $b=New-Object Windows.Forms.Button; $b.Text=$text; $b.Location=New-Object Drawing.Point($x,$y); $b.Size=New-Object Drawing.Size($w,38); $parent.Controls.Add($b); return $b }

$c = LoadConfig
$enable = New-Object Windows.Forms.CheckBox; $enable.Text='Enable controlled Wi-Fi'; $enable.Location=New-Object Drawing.Point(30,30); $enable.Size=New-Object Drawing.Size(240,30); $enable.Checked=[bool]$c.HotspotEnabled; $tabHot.Controls.Add($enable)
Label $tabHot 'Wi-Fi name (SSID)' 30 85 | Out-Null; $ssid=TextBox $tabHot 220 82; $ssid.Text=$c.SSID
Label $tabHot 'Password' 30 130 | Out-Null; $pass=TextBox $tabHot 220 127; $pass.Text=$c.Password
$saveHot=Button $tabHot 'Save' 30 190
$start=Button $tabHot 'Start Wi-Fi now' 200 190
$stop=Button $tabHot 'Stop Wi-Fi now' 370 190
$statusLabel=Label $tabHot 'Status: not checked' 30 255 660; $statusLabel.Height=45
$note=Label $tabHot 'The background engine is designed to run as SYSTEM at Windows startup, before user logon.' 30 305 650; $note.Height=60

$sch = New-Object Windows.Forms.CheckBox; $sch.Text='Enable schedules'; $sch.Location=New-Object Drawing.Point(30,20); $sch.Size=New-Object Drawing.Size(220,30); $sch.Checked=[bool]$c.ScheduleEnabled; $tabSchedule.Controls.Add($sch)
Label $tabSchedule 'Each rule defines when a target is ALLOWED. Outside its configured periods that target is blocked.' 30 55 760 | Out-Null
Label $tabSchedule 'Targets: Whole traffic, YouTube, TikTok, Instagram, Snapchat. Multiple periods per day/target are supported.' 30 80 790 | Out-Null

$grid = New-Object Windows.Forms.DataGridView
$grid.Location = New-Object Drawing.Point(30,115)
$grid.Size = New-Object Drawing.Size(790,345)
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.RowHeadersVisible = $false
$grid.AutoSizeColumnsMode = 'Fill'
$grid.SelectionMode = 'FullRowSelect'
$grid.MultiSelect = $false
$tabSchedule.Controls.Add($grid)

$colEnabled = New-Object Windows.Forms.DataGridViewCheckBoxColumn; $colEnabled.Name='Enabled'; $colEnabled.HeaderText='Enabled'; $colEnabled.FillWeight=14
$colDay = New-Object Windows.Forms.DataGridViewComboBoxColumn; $colDay.Name='Day'; $colDay.HeaderText='Day'; $colDay.FillWeight=22; [void]$colDay.Items.AddRange(@('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'))
$colTarget = New-Object Windows.Forms.DataGridViewComboBoxColumn; $colTarget.Name='Target'; $colTarget.HeaderText='Apply to'; $colTarget.FillWeight=28; [void]$colTarget.Items.AddRange(@('Whole traffic','YouTube','TikTok','Instagram','Snapchat'))
$colStart = New-Object Windows.Forms.DataGridViewTextBoxColumn; $colStart.Name='Start'; $colStart.HeaderText='Start (HH:mm)'; $colStart.FillWeight=18
$colStop = New-Object Windows.Forms.DataGridViewTextBoxColumn; $colStop.Name='Stop'; $colStop.HeaderText='Stop (HH:mm)'; $colStop.FillWeight=18
[void]$grid.Columns.Add($colEnabled);[void]$grid.Columns.Add($colDay);[void]$grid.Columns.Add($colTarget);[void]$grid.Columns.Add($colStart);[void]$grid.Columns.Add($colStop)

$dayNames=@('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')
if($null -ne $c.PSObject.Properties['ScheduleRules'] -and @($c.ScheduleRules).Count -gt 0){
    foreach($r in @($c.ScheduleRules)){ [void]$grid.Rows.Add([bool]$r.Enabled,[string]$r.Day,[string]$r.Target,[string]$r.Start,[string]$r.Stop) }
} else {
    foreach($d in $dayNames){
        $enabledDay=$true; $startTime='06:00'; $stopTime='22:00'
        if($null -ne $c.DaySchedules -and $null -ne $c.DaySchedules.$d){$enabledDay=[bool]$c.DaySchedules.$d.Enabled;$startTime=[string]$c.DaySchedules.$d.Start;$stopTime=[string]$c.DaySchedules.$d.Stop}
        if($enabledDay){[void]$grid.Rows.Add($true,$d,'Whole traffic',$startTime,$stopTime)}
    }
}
$addSchedule=Button $tabSchedule 'Add rule' 30 480 130
$removeSchedule=Button $tabSchedule 'Remove selected' 175 480 160
$copySchedule=Button $tabSchedule 'Copy selected to all days' 350 480 210
$saveSch=Button $tabSchedule 'Save schedules' 575 480 165
$schNote=Label $tabSchedule 'Example: Monday 16:00–21:00 + TikTok means TikTok is available only during that period on Monday. Overnight periods such as 20:00–02:00 are supported.' 30 535 790; $schNote.Height=65
