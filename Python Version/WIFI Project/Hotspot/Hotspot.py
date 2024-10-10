import asyncio
import subprocess
import socket
import time
from datetime import datetime
import re
import sys
import winsound
from colorama import init, Fore, Style

# Initialize colorama for colored output
init(autoreset=True)

# Dictionary to store previously connected devices
previous_devices = {}

def resolve_device_name(ip_address):
    """
    Resolves the device name using DNS and NetBIOS.
    If resolution fails, returns the IP address.
    """
    if ip_address != "Unknown IP":
        try:
            # Attempt DNS resolution
            device_name = socket.gethostbyaddr(ip_address)[0]
            return device_name
        except socket.herror:
            try:
                # Attempt NetBIOS resolution using nbtstat
                result = subprocess.check_output(['nbtstat', '-A', ip_address], stderr=subprocess.STDOUT, text=True)
                match = re.search(r'(\S+)\s+<00>', result)
                if match:
                    return match.group(1)
                else:
                    return ip_address
            except subprocess.CalledProcessError:
                return ip_address
    else:
        return "Unknown Device"

def resolve_device_from_arp(mac_address):
    """
    Attempts to resolve the IP address from the ARP table using the MAC address.
    """
    try:
        arp_table = subprocess.check_output(['arp', '-a'], text=True)
        for line in arp_table.splitlines():
            if mac_address.lower() in line.lower():
                match = re.search(r'(\d+\.\d+\.\d+\.\d+)', line)
                if match:
                    return match.group(1)
        return "Unknown Device"
    except subprocess.CalledProcessError:
        return "Unknown Device"

def get_connection_duration(start_time):
    """
    Calculates the duration since the device connected.
    """
    duration = datetime.now() - start_time
    days = duration.days
    hours, remainder = divmod(duration.seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    duration_str = f"{days} days, {hours} hours, {minutes} minutes, {seconds} seconds"
    return duration_str

def get_connected_devices():
    """
    Retrieves the list of connected devices by parsing the ARP table.
    """
    try:
        arp_output = subprocess.check_output(['arp', '-a'], text=True)
        devices = []
        for line in arp_output.splitlines():
            if re.match(r'\s*\d+\.\d+\.\d+\.\d+', line):
                parts = line.split()
                if len(parts) >= 2:
                    ip = parts[0]
                    mac = parts[1]
                    devices.append({
                        'IpAddress': ip,
                        'MacAddress': mac,
                        'ConnectionTime': datetime.now(),
                        'StartTime': datetime.now()
                    })
        return devices
    except subprocess.CalledProcessError:
        return []

async def start_hotspot(ssid="YourSSID", password="YourPassword"):
    """
    Starts the Windows hotspot using netsh commands.
    """
    try:
        # Configure the hosted network
        subprocess.check_call([
            'netsh', 'wlan', 'set', 'hostednetwork',
            f'mode=allow', f'ssid={ssid}', f'key={password}'
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        # Start the hosted network
        subprocess.check_call(['netsh', 'wlan', 'start', 'hostednetwork'],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(Fore.GREEN + "Hotspot started successfully.")
    except subprocess.CalledProcessError as e:
        print(Fore.RED + f"Failed to start hotspot: {e}")

async def stop_hotspot():
    """
    Stops the Windows hotspot using netsh commands.
    """
    try:
        subprocess.check_call(['netsh', 'wlan', 'stop', 'hostednetwork'],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(Fore.GREEN + "Hotspot stopped successfully.")
    except subprocess.CalledProcessError as e:
        print(Fore.RED + f"Failed to stop hotspot: {e}")

async def get_hotspot_state():
    """
    Checks the current state of the hotspot.
    """
    try:
        output = subprocess.check_output(['netsh', 'wlan', 'show', 'hostednetwork'], text=True)
        if 'Status                   : Started' in output:
            return 'Started'
        else:
            return 'Stopped'
    except subprocess.CalledProcessError:
        return 'Unknown'

async def main():
    global previous_devices
    while True:
        hotspot_state = await get_hotspot_state()
        if hotspot_state == 'Started':
            print(Fore.GREEN + "Hotspot is already On!")
        else:
            print(Fore.YELLOW + "Hotspot is off! Turning it on.")
            await start_hotspot()

        current_devices = get_connected_devices()
        # Convert previous_devices keys to a set for faster lookup
        previous_macs = set(previous_devices.keys())
        new_devices = [dev for dev in current_devices if dev['MacAddress'] not in previous_macs]

        if new_devices:
            for device in new_devices:
                device_name = resolve_device_name(device['IpAddress'])
                if device_name == device['IpAddress']:
                    # If DNS and NetBIOS resolution fails, try ARP lookup
                    device_name = resolve_device_from_arp(device['MacAddress'])

                connection_duration = get_connection_duration(device['StartTime'])

                # Display device information with colors
                print(Fore.CYAN + "New device connected!")
                print(Fore.GREEN + f"   Device Name: {device_name}")
                print(Fore.YELLOW + f"   MAC Address: {device['MacAddress']}")
                print(Fore.MAGENTA + f"   Connection Time: {device['ConnectionTime'].strftime('%Y-%m-%d %H:%M:%S')}")
                print(Fore.BLUE + f"   Duration: {connection_duration}")

                # Play a beep sound for notification
                winsound.Beep(1000, 200)  # Frequency: 1000 Hz, Duration: 200 ms

        # Update the previous device list
        previous_devices = {dev['MacAddress']: dev for dev in current_devices}

        # Wait for 60 seconds before the next check
        await asyncio.sleep(60)

if __name__ == '__main__':
    # Check for administrator privileges
    try:
        # Attempting to get the ARP table as a simple check for admin rights
        subprocess.check_output(['arp', '-a'], stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError:
        print(Fore.RED + "This script requires administrative privileges. Please run as administrator.")
        sys.exit(1)
    except Exception:
        pass  # If arp command exists but fails for another reason

    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nExiting...")
        sys.exit(0)
