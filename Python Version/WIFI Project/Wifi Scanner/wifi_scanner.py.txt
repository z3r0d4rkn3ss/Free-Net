import subprocess
import re
import csv
import os
from dataclasses import dataclass, asdict
from typing import List
import speedtest
import pandas as pd

# Define the Wi-Fi adapter name
WIFI_ADAPTER = "WiFi"

@dataclass
class WiFiNetwork:
    SSID: str
    Security: str
    Encryption: str
    BSSID: str
    SpeedTestResult: str = ""

@dataclass
class SavedProfile:
    SSID: str
    Security: str
    Encryption: str
    Password: str
    ConnectionMode: str
    RadioType: str
    InterfaceType: str
    AuthMethod: str
    SpeedTestResult: str = ""

def run_command(command: List[str]) -> str:
    """Run a system command and return its output."""
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Command {' '.join(command)} failed with error: {e.stderr}")
        return ""

def get_wifi_networks() -> List[WiFiNetwork]:
    """Retrieve available Wi-Fi networks."""
    command = ["netsh", "wlan", "show", "networks", "mode=Bssid"]
    output = run_command(command)
    networks = []
    
    ssid_pattern = re.compile(r"SSID\s+\d+\s+:\s+(.+)")
    network_type_pattern = re.compile(r"Network type\s+:\s+(.+)")
    auth_pattern = re.compile(r"Authentication\s+:\s+(.+)")
    encryption_pattern = re.compile(r"Encryption\s+:\s+(.+)")
    bssid_pattern = re.compile(r"BSSID\s+\d+\s+:\s+(.+)")
    
    ssid = ""
    network_type = ""
    auth = ""
    encryption = ""
    
    for line in output.splitlines():
        ssid_match = ssid_pattern.match(line)
        if ssid_match:
            ssid = ssid_match.group(1).strip()
            continue
        
        network_type_match = network_type_pattern.match(line)
        if network_type_match:
            network_type = network_type_match.group(1).strip()
            continue
        
        auth_match = auth_pattern.match(line)
        if auth_match:
            auth = auth_match.group(1).strip()
            continue
        
        encryption_match = encryption_pattern.match(line)
        if encryption_match:
            encryption = encryption_match.group(1).strip()
            continue
        
        bssid_match = bssid_pattern.match(line)
        if bssid_match:
            bssid = bssid_match.group(1).strip()
            security = "Password Protected" if auth.lower() != "open" else "Open"
            networks.append(WiFiNetwork(SSID=ssid, Security=security, Encryption=encryption, BSSID=bssid))
    
    return networks

def get_saved_profiles() -> List[SavedProfile]:
    """Retrieve saved Wi-Fi profiles with their details."""
    command = ["netsh", "wlan", "show", "profiles"]
    output = run_command(command)
    profiles = []
    
    profile_pattern = re.compile(r"All User Profile\s+:\s+(.+)")
    
    profile_names = []
    for line in output.splitlines():
        profile_match = profile_pattern.match(line)
        if profile_match:
            profile_names.append(profile_match.group(1).strip())
    
    for profile in profile_names:
        profile_command = ["netsh", "wlan", "show", "profile", f'name="{profile}"', "key=clear"]
        profile_details = run_command(profile_command)
        
        security = extract_value(profile_details, r"Authentication\s+:\s+(.+)")
        encryption = extract_value(profile_details, r"Cipher\s+:\s+(.+)")
        password = extract_value(profile_details, r"Key Content\s+:\s+(.+)", default="None")
        connection_mode = extract_value(profile_details, r"Connection mode\s+:\s+(.+)", default="N/A")
        radio_type = extract_value(profile_details, r"Radio type\s+:\s+(.+)", default="N/A")
        interface_type = extract_value(profile_details, r"Interface type\s+:\s+(.+)", default="N/A")
        auth_method = extract_value(profile_details, r"Authentication method\s+:\s+(.+)", default="N/A")
        
        profiles.append(SavedProfile(
            SSID=profile,
            Security=security,
            Encryption=encryption,
            Password=password,
            ConnectionMode=connection_mode,
            RadioType=radio_type,
            InterfaceType=interface_type,
            AuthMethod=auth_method
        ))
    
    return profiles

def extract_value(text: str, pattern: str, default: str = "N/A") -> str:
    """Extract value using regex pattern."""
    match = re.search(pattern, text, re.IGNORECASE)
    return match.group(1).strip() if match else default

def perform_speed_test() -> str:
    """Perform an internet speed test and return the result."""
    try:
        st = speedtest.Speedtest()
        st.get_best_server()
        download_speed = st.download() / 1_000_000  # Convert to Mbps
        upload_speed = st.upload() / 1_000_000      # Convert to Mbps
        ping = st.results.ping
        return f"Download: {download_speed:.2f} Mbps, Upload: {upload_speed:.2f} Mbps, Ping: {ping} ms"
    except Exception as e:
        print(f"Speed test failed: {e}")
        return "Error"

def save_networks_to_csv(file_path: str, networks: List[dict]):
    """Save network data to a CSV file."""
    df = pd.DataFrame(networks)
    df.to_csv(file_path, index=False)
    print(f"Results saved to {file_path}")

def main():
    print("Scanning for Wi-Fi networks and saved profiles...")
    
    # Get available networks and saved profiles
    network_list = get_wifi_networks()
    saved_profile_list = get_saved_profiles()
    
    # Combine lists
    combined_list = []
    
    # Convert dataclass instances to dictionaries
    for network in network_list:
        combined_list.append(asdict(network))
    
    for profile in saved_profile_list:
        combined_list.append(asdict(profile))
    
    # Remove duplicates based on SSID
    df = pd.DataFrame(combined_list)
    df = df.drop_duplicates(subset=['SSID'])
    
    # Perform speed test and add result
    speed_test_result = perform_speed_test()
    df['SpeedTestResult'] = speed_test_result
    
    # Define the CSV file path
    csv_file_path = r"C:\Users\YOUR_PATH_HERE\WIFI Project\SSID Database\WiFiNetworks.csv"
    
    # Ensure the directory exists
    os.makedirs(os.path.dirname(csv_file_path), exist_ok=True)
    
    # Save to CSV
    save_networks_to_csv(csv_file_path, df.to_dict(orient='records'))
    
    print(f"Scan complete. Results saved to {csv_file_path}")

if __name__ == "__main__":
    main()
