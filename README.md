FREE NET

Free-Net is a project that enables users to scan public or private networks to find and connect to available internet access points. Once connected, it saves the SSID information and continues scanning for additional networks without interrupting the current connection. Additionally, Free-Net can share the connection through a hotspot, acting as a relay to provide free internet access for you or your network.

How Did This Idea Come About?

The idea for Free-Net emerged during a month of isolation in a property without internet access, which started to drive me crazy. I noticed there were public networks available, but I ran into issues while trying to use Windows 10's hotspot feature—it kept turning itself off. This led to the creation of the first script, which continuously checked if the hotspot was on and, if not, turned it back on in a loop.

Next, I encountered another problem: the Wi-Fi connection kept dropping and reconnecting. This inspired the second script, which scanned for more networks, maintained the current connection, and automatically reconnected if it dropped.

What began as simple troubleshooting is now an automated system that reliably provides free internet access by acting as a relay.

What Can Be Done with Free-Net?

The script has several capabilities:

    It can scan Wi-Fi networks and export saved profiles to a file.
    It maintains and relays active network connections.
    It displays connection information and runs tests, such as checking network speed and tracking how long you've maintained the connection.
    It can export data on hotspot connections.
    You can display challenge or splash pages to users who connect or clone the splash page of the current network.

What I Aim to Achieve with the Project

In the future, I envision developing two pieces of hardware:

    The Scanner: A portable device you can carry in public spaces that collects Wi-Fi network data, integrates with Google Maps, and uploads the information online.

    The Modem: A device that scans your local area, finds available connections, and relays them. It also downloads networks gathered by the scanners, ensuring a connection is always available.

Although a mobile app that acts as both a scanner and relay seems like a logical choice, I prefer dedicated hardware for better signal strength.

Ultimately, my goal is to create a community of "Free-Neters"—a network of users contributing to and benefiting from freely accessible internet connections.

What is the current versions.

Windows









