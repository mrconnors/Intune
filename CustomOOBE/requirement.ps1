$registryPath = "HKLM:\Software\CustomOOBE"
$pattern = '^CustomOOBEv\d+\.\d+Complete$'

try {
    if (Test-Path $registryPath) {
        $props = Get-ItemProperty -Path $registryPath | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $match = $props | Where-Object { $_ -match $pattern }

        if ($match) {
            return $true
        }
    }
} catch {
    # optionally log or handle error
}

return $false