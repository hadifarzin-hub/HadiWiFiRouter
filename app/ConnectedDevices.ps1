Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

function Get-HotspotClientRows {
    param([string]$Subnet = '192.168.137.0/24')

    $prefix = '192.168.137.'
    if ($Subnet -match '^(\d+\.\d+\.\d+)\.\d+/24$') { $prefix = "$($Matches[1])." }

    $rows = @()
    try {
        $neighbors = Get-NetNeighbor -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object {
                $_.IPAddress -like "$prefix*" -and
                $_.IPAddress -ne ($prefix + '1') -and
                $_.LinkLayerAddress -and
                $_.LinkLayerAddress -ne '00-00-00-00-00-00' -and
                $_.State -notin @('Unreachable','Incomplete')
            }
        foreach ($n in $neighbors) {
            $host = ''
            try {
                $entry = [System.Net.Dns]::GetHostEntry($n.IPAddress)
                if ($entry.HostName -and $entry.HostName -ne $n.IPAddress) { $host = $entry.HostName }
            } catch { }
            $rows += [pscustomobject]@{
                Device = $host
                IPAddress = $n.IPAddress
                MACAddress = $n.LinkLayerAddress
                State = $n.State.ToString()
                Interface = $n.InterfaceAlias
            }
        }
    } catch { }
    return $rows | Sort-Object IPAddress -Unique
}
