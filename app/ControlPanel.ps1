# Loader for HadiWiFiRouter Control Panel v2.3.
$parts = @(
    (Join-Path $PSScriptRoot 'source-parts\ControlPanel.v2.3.part1.ps1'),
    (Join-Path $PSScriptRoot 'source-parts\ControlPanel.v2.3.part2.ps1'),
    (Join-Path $PSScriptRoot 'source-parts\ControlPanel.v2.3.part3.ps1'),
    (Join-Path $PSScriptRoot 'source-parts\ControlPanel.v2.3.part4.ps1')
)
$code = ($parts | ForEach-Object { Get-Content -LiteralPath $_ -Raw -Encoding UTF8 }) -join "`r`n"
Invoke-Expression $code
