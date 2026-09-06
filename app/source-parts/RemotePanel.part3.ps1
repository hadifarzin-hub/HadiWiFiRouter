        if(-not $tsIp){Start-Sleep -Seconds 2}
    }
}
if(-not $tsIp){Log 'START ERROR: Tailscale IPv4 was not available after 60 seconds; exiting for scheduled retry.'; exit 2}
$listener.Prefixes.Add("http://${tsIp}:8787/")
try{$listener.Start();Log "Remote panel started on 127.0.0.1:8787 and ${tsIp}:8787 as $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"}catch{Log "START ERROR: $($_.Exception.Message)"; exit 1}

function Handle($ctx){
    $req=$ctx.Request; $path=$req.Url.AbsolutePath; $method=$req.HttpMethod
    if($path -eq '/health'){Send-Text $ctx 200 'text/plain' 'OK';return}
    if($path -eq '/api/login' -and $method -eq 'POST'){
        try{$o=(Read-Body $req)|ConvertFrom-Json; if((Get-Key) -and [string]$o.key -ceq (Get-Key)){ $tok=New-Session; $ck=New-Object Net.Cookie('HWRSession',$tok,'/'); $ck.HttpOnly=$true; $ck.Expires=(Get-Date).AddHours(12); $ctx.Response.Cookies.Add($ck); Send-Json $ctx @{ok=$true};return}}catch{}
        Send-Json $ctx @{error='Invalid administrator key'} 401;return
    }
    if(-not (Is-Authorized $req)){ if($path -like '/api/*'){Send-Json $ctx @{error='Unauthorized'} 401}else{Send-Text $ctx 200 'text/html' $loginHtml};return }
    if($path -eq '/api/logout' -and $method -eq 'POST'){ $cookie=$req.Cookies['HWRSession']; if($cookie){[void]$sessions.Remove([string]$cookie.Value)}; $del=New-Object Net.Cookie('HWRSession','deleted','/'); $del.HttpOnly=$true; $del.Expires=(Get-Date).AddDays(-1); $ctx.Response.Cookies.Add($del); Send-Json $ctx @{ok=$true};return }
    if($path -eq '/' -and $method -eq 'GET'){Send-Text $ctx 200 'text/html' $mainHtml;return}
    try{
        if($path -eq '/api/status' -and $method -eq 'GET'){
            $c=Load-Config; try{$h=Get-HotspotStatus}catch{$h=[pscustomobject]@{State='Unknown';Status=$_.Exception.Message;ClientCount=0;MaxClientCount=0}}
            $sub=if($c.PSObject.Properties['HotspotSubnet']){[string]$c.HotspotSubnet}else{'192.168.137.0/24'}; $dev=@(Get-HotspotClientRows -Subnet $sub)
            Send-Json $ctx @{config=$c;hotspot=$h;devices=$dev};return
        }
        if($path -eq '/api/hotspot/start' -and $method -eq 'POST'){ $o=(Read-Body $req)|ConvertFrom-Json; $r=Start-Hotspot -SSID ([string]$o.SSID) -Password ([string]$o.Password);Send-Json $ctx $r;return }
        if($path -eq '/api/hotspot/stop' -and $method -eq 'POST'){Send-Json $ctx (Stop-Hotspot);return}
        if($path -eq '/api/hotspot/save' -and $method -eq 'POST'){ $o=(Read-Body $req)|ConvertFrom-Json;$c=Load-Config;$c.HotspotEnabled=[bool]$o.HotspotEnabled;$c.SSID=[string]$o.SSID;$c.Password=[string]$o.Password;Save-Config $c;Send-Json $ctx @{ok=$true};return }
        if($path -eq '/api/schedule' -and $method -eq 'POST'){ $o=(Read-Body $req)|ConvertFrom-Json;$c=Load-Config;$c.ScheduleEnabled=[bool]$o.ScheduleEnabled;if($null -eq $c.PSObject.Properties['ScheduleRules']){$c|Add-Member -NotePropertyName ScheduleRules -NotePropertyValue @($o.ScheduleRules)}else{$c.ScheduleRules=@($o.ScheduleRules)};Save-Config $c;try{[void](Write-PacketEngineRules $c)}catch{};Send-Json $ctx @{ok=$true};return }
        if($path -eq '/api/website' -and $method -eq 'POST'){ $o=(Read-Body $req)|ConvertFrom-Json;$c=Load-Config;$c.WebsiteFilteringEnabled=[bool]$o.WebsiteFilteringEnabled;$c.FilteringMode='BlockList';$c.BlockedServices=@($o.BlockedServices);$c.BlockedDomains=@($o.BlockedDomains);$c.AllowedDomains=@($o.AllowedDomains);Save-Config $c;$m=Apply-ClientWebsiteRules $c;Send-Json $ctx @{ok=$true;message=$m};return }
        if($path -eq '/api/speed' -and $method -eq 'POST'){ $o=(Read-Body $req)|ConvertFrom-Json;$c=Load-Config;$c.SpeedControlEnabled=[bool]$o.SpeedControlEnabled;$c.SpeedRules=@($o.SpeedRules);Save-Config $c;$m=Apply-SpeedRules $c;Send-Json $ctx @{ok=$true;message=$m};return }
        Send-Json $ctx @{error='Not found'} 404
    }catch{ Log "REQUEST ERROR $method $path : $($_.Exception.Message)"; Send-Json $ctx @{error=$_.Exception.Message} 500 }
}

if($Once){try{$c=$listener.GetContext();Handle $c}finally{$listener.Stop()};exit}
while($listener.IsListening){ try{$ctx=$listener.GetContext();Handle $ctx}catch{if($listener.IsListening){Log "LOOP ERROR: $($_.Exception.Message)"}} }
