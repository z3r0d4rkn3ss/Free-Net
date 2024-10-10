Add-Type -AssemblyName System.Runtime.WindowsRuntime

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

Function Await($WinRtTask, $ResultType) {
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}

Function AwaitAction($WinRtAction) {
    $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and !$_.IsGenericMethod })[0]
    $netTask = $asTask.Invoke($null, @($WinRtAction))
    $netTask.Wait(-1) | Out-Null
}

# Function to get connected devices
Function Get-ConnectedDevices {
    param (
        [Parameter(Mandatory=$true)]
        $tetheringManager
    )

    $connectedDevices = $tetheringManager.GetTetheringClients() | ForEach-Object { 
        [PSCustomObject]@{
            MacAddress = $_.MacAddress
            IpAddress = if ($_.HostName) { $_.HostName } else { "Unknown IP" }
            ConnectionTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')  # Store current time as connection time
            StartTime = Get-Date  # Store the exact time of connection
        }
    }
    return $connectedDevices
}

# Function to resolve hostname or attempt device name lookup (if IP is available)
Function Resolve-DeviceName {
    param (
        [Parameter(Mandatory=$true)]
        $ipAddress
    )

    if ($ipAddress -ne "Unknown IP") {
        try {
            # Use DNS to try and resolve the hostname
            $deviceName = [System.Net.Dns]::GetHostEntry($ipAddress).HostName
            return $deviceName
        } catch {
            try {
                # Try NetBIOS resolution if DNS fails
                $netbiosName = nbtstat -A $ipAddress | Select-String -Pattern 'Name'
                if ($netbiosName) {
                    return $netbiosName -replace '.*<00>.*', '' # Clean up the output
                } else {
                    return $ipAddress
                }
            } catch {
                # Return IP if name resolution fails
                return $ipAddress
            }
        }
    } else {
        return "Unknown Device"
    }
}

# Function to resolve device name using ARP
Function Resolve-DeviceFromARP {
    param (
        [Parameter(Mandatory=$true)]
        $macAddress
    )

    try {
        # Get ARP cache and look for the matching MAC address
        $arpTable = arp -a
        $entry = $arpTable | Select-String $macAddress
        if ($entry) {
            return $entry -replace '.*(\d+\.\d+\.\d+\.\d+).*', '$1' # Extract IP address
        } else {
            return "Unknown Device"
        }
    } catch {
        return "Unknown Device"
    }
}

# Function to calculate connection duration
Function Get-ConnectionDuration {
    param (
        [Parameter(Mandatory=$true)]
        [datetime]$startTime
    )

    $currentTime = Get-Date
    $duration = $currentTime - $startTime
    $days = [math]::Floor($duration.TotalDays)
    $hours = [math]::Floor($duration.TotalHours % 24)
    $minutes = [math]::Floor($duration.TotalMinutes % 60)
    $seconds = [math]::Floor($duration.TotalSeconds % 60)

    # Manually construct the duration string
    $durationString = "$days days, $hours hours, $minutes minutes, $seconds seconds"
    return $durationString
}

$previousDevices = @()

while ($true) {
    # Get the connection profile
    $connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile()

    # Check if the connection profile is valid
    if ($connectionProfile -eq $null) {
        Write-Host "No valid connection profile found. Ensure you're connected to a network." -ForegroundColor Red
        Start-Sleep -Seconds 60
        continue
    }

    # Try to create a tethering manager
    try {
        $tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($connectionProfile)
    } catch {
        Write-Host "Failed to create tethering manager. Error: $_" -ForegroundColor Red
        Start-Sleep -Seconds 60
        continue
    }

    if ($tetheringManager.TetheringOperationalState -eq 1) {
        Write-Host "Hotspot is already On!" -ForegroundColor Green
    } else {
        Write-Host "Hotspot is off! Turning it on" -ForegroundColor Yellow
        Await ($tetheringManager.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])
    }

    # Check connected devices
    $currentDevices = Get-ConnectedDevices -tetheringManager $tetheringManager

    # Compare current devices to previous devices
    $newDevices = $currentDevices | Where-Object { $_.MacAddress -notin $previousDevices.MacAddress }

    if ($newDevices.Count -gt 0) {
        foreach ($device in $newDevices) {
            $deviceName = Resolve-DeviceName -ipAddress $device.IpAddress
            if ($deviceName -eq $device.IpAddress) {
                # If DNS and NetBIOS resolution fails, try ARP lookup
                $deviceName = Resolve-DeviceFromARP -macAddress $device.MacAddress
            }

            $connectionTime = $device.ConnectionTime
            $connectionDuration = Get-ConnectionDuration -startTime $device.StartTime

            # Spice up the output with colors
            Write-Host "New device connected!" -ForegroundColor Cyan
            Write-Host ("   Device Name: " + $deviceName) -ForegroundColor Green
            Write-Host ("   MAC Address: " + $device.MacAddress) -ForegroundColor Yellow
            Write-Host ("   Connection Time: " + $connectionTime) -ForegroundColor Magenta
            Write-Host ("   Duration: " + $connectionDuration) -ForegroundColor Blue

            # Optionally add a sound notification
            [console]::beep(1000, 200)  
        }
    }

    # Update the previous device list
    $previousDevices = $currentDevices

    # Sleep for 60 seconds
    Start-Sleep -Seconds 60
}