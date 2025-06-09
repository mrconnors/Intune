# Define registry path and value name
$RegistryPath = "SOFTWARE\CustomOOBE"
$ValueName = "CustomOOBEv2.3Complete"

# Open the registry key in 64-bit view
try {
    $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
    $regKey = $baseKey.OpenSubKey($RegistryPath)

    if ($regKey -ne $null -and $regKey.GetValueNames() -contains $ValueName) {
        Write-Output "64-bit registry key and value name exist."
        exit 0
    } else {
        Write-Output "Registry key or value name does not exist."
        exit 1
    }
} catch {
    Write-Output "Error accessing 64-bit registry: $($_.Exception.Message)"
    exit 1
}