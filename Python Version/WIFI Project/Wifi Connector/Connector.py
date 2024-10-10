import subprocess
import time
import sys
from pywifi import PyWiFi, const, Profile

# Wi-Fi network and adapter details
SSID = "Your_SSID"
Password = "Your_Password"
Interface = "WiFi"  # This might not be needed with pywifi
CheckInterval = 60  # Interval in seconds

def test_internet_connection():
    # (Same as above)
    pass

def connect_wifi(ssid, password):
    wifi = PyWiFi()
    ifaces = wifi.interfaces()
    if not ifaces:
        print("No WiFi interfaces found.")
        return False
    iface = ifaces[0]  # Select the first wireless interface

    iface.disconnect()
    time.sleep(1)  # Wait for disconnection

    profile = Profile()
    profile.ssid = ssid
    profile.auth = const.AUTH_ALG_OPEN
    profile.akm.append(const.AKM_TYPE_WPA2PSK)
    profile.cipher = const.CIPHER_TYPE_CCMP
    profile.key = password

    iface.remove_all_network_profiles()
    tmp_profile = iface.add_network_profile(profile)

    iface.connect(tmp_profile)
    time.sleep(5)  # Wait for connection

    if iface.status() == const.IFACE_CONNECTED:
        print(f"Connected to {ssid}")
        return True
    else:
        print(f"Failed to connect to {ssid}")
        return False

def main():
    # Attempt to connect to Wi-Fi
    if SSID and Password:
        connected = connect_wifi(SSID, Password)
        if not connected:
            print("Exiting due to failed Wi-Fi connection.")
            return

    while True:
        if test_internet_connection():
            print("Internet connection is active.")
        else:
            print("No internet connection.")
        time.sleep(CheckInterval)

if __name__ == "__main__":
    main()
