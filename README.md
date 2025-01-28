# Universal Linux Static IP Configuration Script 🌟

A robust, distribution-independent bash script that configures static IP addresses across any Linux system. Works with Ubuntu, Debian, CentOS, RHEL, Fedora, and virtually any Linux distribution!

![Linux](https://img.shields.io/badge/Linux-Universal-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Bash Script](https://img.shields.io/badge/Bash-Script-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)

## 🚀 Features

- ✨ Universal compatibility across Linux distributions
- 🔍 Multiple methods for interface detection
- 🛠️ Support for various network configuration systems:
  - Netplan (Ubuntu 17.10+)
  - NetworkManager
  - Traditional network scripts
  - Debian/Ubuntu interfaces
- 🔄 Automatic fallback mechanisms
- 💾 Automatic configuration backup
- ✅ Comprehensive verification checks

## 📋 Prerequisites

- Root privileges
- Basic network connectivity
- One of the following:
  - `ip` command (iproute2 package)
  - `route` command (net-tools package)
  - `netstat` command (net-tools package)

## 🚀 Quick Start

Run directly from GitHub:

```bash
curl -sSL https://raw.githubusercontent.com/shahedfardous/staticIP/main/configure_ip.sh | sudo bash -s 192.168.1.100/24 192.168.1.1
```

## 📖 Usage

```bash
sudo ./configure_ip.sh <ip_address/cidr> <gateway>
```

### Example:
```bash
sudo ./configure_ip.sh 192.168.1.100/24 192.168.1.1
```

## 🔧 Supported Configuration Methods

1. **Modern Systems**
   - NetworkManager (GUI systems)
   - Netplan (Ubuntu 17.10+)

2. **Traditional Systems**
   - Network scripts (RHEL/CentOS)
   - interfaces file (Debian/Ubuntu)

3. **Fallback Methods**
   - Direct interface configuration
   - System-specific methods

## 🛡️ Failsafe Features

- Multiple methods for interface detection:
  - `ip route`
  - `route -n`
  - `netstat -rn`
  - Direct system interface enumeration
- Automatic backup of existing configurations
- Progressive fallback for network commands
- Comprehensive error checking

## 📝 Configuration Details

The script will automatically:
1. Detect your Linux distribution
2. Identify available networking tools
3. Choose the most appropriate configuration method
4. Apply the configuration using the best available method
5. Verify the changes using available tools

## ⚠️ Important Notes

- Always review scripts before running them directly from the internet
- Backup your network configuration before running
- Have physical access to the system in case of misconfiguration
- Some configurations may require a system restart

## 🔍 Troubleshooting

If the script fails:
1. Check if required networking tools are installed
2. Verify root privileges
3. Ensure interface name is correct
4. Check system logs for errors

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## 📄 License

MIT License - feel free to use in your projects!

## ⭐ Support

If you find this script helpful, please star the repository!

## 🔄 Updates

Last updated: January 2025
- Added multiple interface detection methods
- Improved distribution compatibility
- Enhanced error handling
- Added fallback mechanisms
