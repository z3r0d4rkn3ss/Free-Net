# Define the Wi-Fi adapter name
$wifiAdapter = "WiFi"

# Function to get available Wi-Fi networks
function Get-WiFiNetworks {
    $networks = netsh wlan show networks mode=bssid
    $networkList = @()
    
    # Extract SSID and Security Information
    foreach ($network in $networks) {
        if ($network -match "SSID\s\d+\s*:\s*(.+)") {
            $ssid = $matches[1].Trim()
        }
        if ($network -match "Network type\s*:\s*(.+)") {
            $networkType = $matches[1].Trim()
        }
        if ($network -match "Authentication\s*:\s*(.+)") {
            $auth = $matches[1].Trim()
        }
        if ($network -match "Encryption\s*:\s*(.+)") {
            $encryption = $matches[1].Trim()
        }
        if ($network -match "BSSID\s*1\s*:\s*(.+)") {
            $bssid = $matches[1].Trim()
            $networkList += [PSCustomObject]@{
                SSID          = $ssid
                Security      = if ($auth -ne "Open") { "Password Protected" } else { "Open" }
                Encryption    = $encryption
                BSSID         = $bssid
            }
        }
    }
    return $networkList
}

# Function to get saved Wi-Fi profiles with all connection data
function Get-SavedProfiles {
    $profiles = netsh wlan show profiles
    $profileList = @()

    foreach ($profile in $profiles) {
        if ($profile -match "Profile\s*:\s*(.+)") {
            $profileName = $matches[1].Trim()
            # Get profile details including password and connection info
            $profileDetails = netsh wlan show profile name="$profileName" key=clear

            # Extract security, encryption, password, connection mode, and other details
            $security = if ($profileDetails -match "Authentication\s*:\s*(.+)") { $matches[1].Trim() } else { "N/A" }
            $encryption = if ($profileDetails -match "Cipher\s*:\s*(.+)") { $matches[1].Trim() } else { "N/A" }
            $password = if ($profileDetails -match "Key Content\s*:\s*(.+)") { $matches[1].Trim() } else { "None" }
            $connectionMode = if ($profileDetails -match "Connection mode\s*:\s*(.+)") { $matches[1].Trim() } else { "N/A" }
            $radioType = if ($profileDetails -match "Radio type\s*:\s*(.+)") { $matches[1].Trim() } else { "N/A" }
            $interfaceType = if ($profileDetails -match "Interface type\s*:\s*(.+)") { $matches[1].Trim() } else { "N/A" }
            $authMethod = if ($profileDetails -match "Authentication method\s*:\s*(.+)") { $matches[1].Trim() } else { "N/A" }

            # Add to profile list
            $profileList += [PSCustomObject]@{
                SSID            = $profileName
                Security        = $security
                Encryption      = $encryption
                Password        = $password
                ConnectionMode  = $connectionMode
                RadioType       = $radioType
                InterfaceType   = $interfaceType
                AuthMethod      = $authMethod
            }
        }
    }
    return $profileList
}

# Function to perform a speed test
function Test-Speed {
    try {
        $testUrl = "http://www.speedtest.net/speedtest-servers.php" # Speed test URL
        $response = Invoke-WebRequest -Uri $testUrl -UseBasicP
        return $response.StatusCode
    }
    catch {
        Write-Host "Speed test failed. $_"
        return "Error"
    }
}

# Function to save networks to a CSV file
function Save-Networks {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [Parameter(Mandatory=$true)]
        [array]$Networks
    )
    $Networks | Sort-Object SSID -Unique | Export-Csv -Path $FilePath -NoTypeInformation
}

# Main execution
Write-Host "Scanning for Wi-Fi networks and saved profiles..."

# Get networks and profiles
$networkList = Get-WiFiNetworks
$savedProfileList = Get-SavedProfiles

# Combine lists and remove duplicates
$combinedList = $networkList + $savedProfileList | Sort-Object SSID -Unique

# Perform speed test and add result
$combinedList | ForEach-Object {
    $speedTestResult = Test-Speed
    $_ | Add-Member -MemberType NoteProperty -Name "SpeedTestResult" -Value $speedTestResult
}

# Save the list to a CSV file
Save-Networks -FilePath "C:\Users\YOUR PATH HERE\WIFI Project\SSID Database\WiFiNetworks.csv" -Networks $combinedList

Write-Host "Scan complete. Results saved to C:\Users\YOUR PATH HERE\WIFI Project\SSID Database\WiFiNetworks.csv"
