param([switch]$Once)
Set-StrictMode -Version Latest
$ErrorActionPreference='Continue'
$AppDir=Split-Path -Parent $MyInvocation.MyCommand.Path
$Root=Split-Path -Parent $AppDir
$ConfigPath=Join-Path $AppDir 'config.json'
$KeyPath=Join-Path $AppDir 'remote-admin-key.txt'
$LogDir=Join-Path $Root 'logs'
$LogPath=Join-Path $LogDir 'remote-panel.log'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
. (Join-Path $AppDir 'HotspotCore.ps1')
. (Join-Path $AppDir 'WebsiteRules.ps1')
. (Join-Path $AppDir 'SpeedRules.ps1')
. (Join-Path $AppDir 'ConnectedDevices.ps1')

function Log([string]$m){ Add-Content -Path $LogPath -Encoding UTF8 -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" }
function Load-Config { Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json }
function Save-Config($c){ $tmp=$ConfigPath+'.remote.tmp'; $c|ConvertTo-Json -Depth 8|Set-Content $tmp -Encoding UTF8; Move-Item $tmp $ConfigPath -Force }
function Get-Key { if(Test-Path $KeyPath){return (Get-Content $KeyPath -Raw).Trim()} return '' }
function Read-Body($req){ $sr=New-Object IO.StreamReader($req.InputStream,$req.ContentEncoding); try{return $sr.ReadToEnd()}finally{$sr.Dispose()} }
function Send-Text($ctx,[int]$code,[string]$type,[string]$text){
    $b=[Text.Encoding]::UTF8.GetBytes($text); $ctx.Response.StatusCode=$code; $ctx.Response.ContentType=$type+'; charset=utf-8'; $ctx.Response.ContentLength64=$b.Length; $ctx.Response.OutputStream.Write($b,0,$b.Length); $ctx.Response.Close()
}
function Send-Json($ctx,$obj,[int]$code=200){ Send-Text $ctx $code 'application/json' ($obj|ConvertTo-Json -Depth 8 -Compress) }
function HtmlEncode([string]$s){ return [Net.WebUtility]::HtmlEncode($s) }

$sessions=@{}
function New-Session {
    $bytes=New-Object byte[] 24; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $tok=([Convert]::ToBase64String($bytes)).TrimEnd('=').Replace('+','-').Replace('/','_')
    $sessions[$tok]=(Get-Date).AddHours(12); return $tok
}
function Is-Authorized($req){
    $cookie=$req.Cookies['HWRSession']; if($null -eq $cookie){return $false}; $t=[string]$cookie.Value
    if(-not $sessions.ContainsKey($t)){return $false}; if($sessions[$t] -lt (Get-Date)){[void]$sessions.Remove($t); return $false}; return $true
}

$loginHtml=@'
<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Hadi WiFi Router</title><style>
body{font-family:Segoe UI,Arial,sans-serif;background:#f5f6f8;margin:0;color:#17191c}.box{max-width:420px;margin:60px auto;background:white;border:1px solid #d9dde3;border-radius:14px;padding:24px;box-sizing:border-box}h1{font-size:22px;margin:0 0 8px}.muted{color:#666;font-size:14px}input,button{font-size:16px;width:100%;box-sizing:border-box;padding:12px;margin-top:12px;border-radius:9px;border:1px solid #b9bec7}button{background:#17191c;color:white;border:0;font-weight:600}.err{color:#a11;margin-top:10px;min-height:20px}</style></head><body><div class="box"><h1>Hadi WiFi Router</h1><div class="muted">Remote administrator access</div><input id="k" type="password" placeholder="Administrator key" autocomplete="current-password"><button id="b">Sign in</button><div class="err" id="e"></div></div><script>
const k=document.getElementById('k'),e=document.getElementById('e');async function go(){e.textContent='';const r=await fetch('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({key:k.value})});if(r.ok){location.reload()}else{e.textContent='Incorrect administrator key.'}}document.getElementById('b').onclick=go;k.addEventListener('keydown',x=>{if(x.key==='Enter')go()});</script></body></html>
'@

$mainHtml=@'
<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Hadi WiFi Router</title><style>
