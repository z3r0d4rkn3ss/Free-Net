# Wi-Fi network and adapter details
$SSID = ""
$Password = ""
$Interface = "WiFi"  # Corrected interface name
$CheckInterval = 60  # Interval in seconds

# Function to check if there is an active internet connection
function Test-InternetConnection {
    try {
        # Ping a reliable server (Google's DNS server 8.8.8.8 in this case)
        Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet
    } catch {
        return $false
    }
}

# Function to create the Wi-Fi profile
function Create-WiFiProfile {
    Write-Host "Creating Wi-Fi profile for $SSID..."
    $ProfileXml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$SSID</name>
    <SSIDConfig>
        <SSID>
            <name>$SSID</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$Password</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@

    # Save profile to a temporary XML file
    $ProfilePath = "$env:TEMP\$SSID.xml"
    $ProfileXml | Out-File -Encoding ASCII -FilePath $ProfilePath

    # Add the profile
    netsh wlan add profile filename=$ProfilePath interface=$Interface

    # Remove the temporary profile file
    Remove-Item $ProfilePath
}

# Function to connect to the Wi-Fi network
function Connect-WiFi {
    Write-Host "Attempting to connect to $SSID..."

    # Check if the network profile exists
    $profileExists = netsh wlan show profiles | Select-String $SSID

    if (-not $profileExists) {
        Write-Host "Network profile for $SSID not found. Creating profile..."
        Create-WiFiProfile
    }

    # Attempt to connect to the network
    try {
        netsh wlan connect name=$SSID interface=$Interface
        Start-Sleep -Seconds 10  # Wait for the connection to establish
        Write-Host "Connected to $SSID."
    } catch {
        Write-Host "Error: Failed to connect to $SSID."
    }
}

# Function to reconnect if no internet
function Reconnect-IfNeeded {
    if (-not (Test-InternetConnection)) {
        Write-Host "No internet connection detected. Reconnecting..."
        try {
            netsh wlan disconnect interface=$Interface
            Start-Sleep -Seconds 5
            Connect-WiFi
        } catch {
            Write-Host "Error: Failed to reconnect."
        }
    } else {
        Write-Host "Internet connection is active."
    }
}

# Initial connection attempt
Connect-WiFi

# Main loop: check connection status every $CheckInterval seconds
while ($true) {
    Reconnect-IfNeeded
    Start-Sleep -Seconds $CheckInterval
}

# Prevent the PowerShell window from closing immediately
Write-Host "Press Enter to exit."
pause