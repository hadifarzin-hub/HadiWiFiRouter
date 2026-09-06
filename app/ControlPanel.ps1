# Loader for the preserved v2.2 Control Panel source.
# The source is split only to keep the repository upload connector manageable.
$parts = @(
    (Join-Path $PSScriptRoot 'source-parts\ControlPanel.part1.ps1'),
    (Join-Path $PSScriptRoot 'source-parts\ControlPanel.part2.ps1'),
    (Join-Path $PSScriptRoot 'source-parts\ControlPanel.part3.ps1')
)
$code = ($parts | ForEach-Object { Get-Content -LiteralPath $_ -Raw -Encoding UTF8 }) -join "`r`n"
Invoke-Expression $code
