# Loader for the preserved v2.2 Remote Panel source.
# The source is split only to keep the repository upload connector manageable.
param([switch]$Once)
$parts = @(
    (Join-Path $PSScriptRoot 'source-parts\RemotePanel.part1.ps1'),
    (Join-Path $PSScriptRoot 'source-parts\RemotePanel.part2.ps1'),
    (Join-Path $PSScriptRoot 'source-parts\RemotePanel.part3.ps1')
)
$code = ($parts | ForEach-Object { Get-Content -LiteralPath $_ -Raw -Encoding UTF8 }) -join "`r`n"
if ($Once) { $code = $code -replace '^param\(\[switch\]\$Once\)', 'param([switch]$Once); $Once=$true' }
Invoke-Expression $code
