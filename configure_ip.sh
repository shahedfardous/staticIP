#!/bin/bash

# ┌────────────────────────────────────────────────────────────────┐
# │                  Static IP Configuration Script                │
# │              Author: Samy <www.shahedfardous.com>              │
# │                    Last Updated: 28-01-2025                    │
# └────────────────────────────────────────────────────────────────┘

# Define color codes
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Display banner
show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
 ╔═══════════════════════════════════════════════╗
 ║         Universal Static IP Configurator      ║
 ║     Supports All Major Linux Distributions    ║
 ╚═══════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Check if all arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <ip_address/cidr> <gateway>"
    echo "Example: $0 192.168.1.100/24 192.168.1.1"
    exit 1
fi

# Assign arguments to variables
IP_CIDR=$1
GATEWAY=$2
DNS1="8.8.8.8"
DNS2="8.8.4.4"

# Extract IP without CIDR
IP_ADDRESS=$(echo $IP_CIDR | cut -d'/' -f1)
CIDR=$(echo $IP_CIDR | cut -d'/' -f2)

# Function to get default interface using different methods
get_default_interface() {
    local interface=""
    
    # Try ip command first
    if command -v ip >/dev/null 2>&1; then
        interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    fi
    
    # If ip command failed, try route command
    if [ -z "$interface" ] && command -v route >/dev/null 2>&1; then
        interface=$(route -n | grep '^0.0.0.0' | awk '{print $8}' | head -n1)
    fi
    
    # If route failed, try netstat command
    if [ -z "$interface" ] && command -v netstat >/dev/null 2>&1; then
        interface=$(netstat -rn | grep '^0.0.0.0' | awk '{print $8}' | head -n1)
    fi
    
    # Last resort: list interfaces and use first non-lo interface
    if [ -z "$interface" ]; then
        interface=$(ls /sys/class/net | grep -v lo | head -n1)
    fi
    
    echo "$interface"
}

# Convert CIDR to netmask
cidr_to_netmask() {
    local i mask=""
    local full_octets=$(($1/8))
    local partial_octet=$(($1%8))
    
    for ((i=0;i<4;i++)); do
        if [ $i -lt $full_octets ]; then
            mask="${mask}255"
        elif [ $i -eq $full_octets ]; then
            mask="${mask}$((256 - 2**(8-$partial_octet)))"
        else
            mask="${mask}0"
        fi
        [ $i -lt 3 ] && mask="${mask}."
    done
    
    echo $mask
}

NETMASK=$(cidr_to_netmask $CIDR)

# Get default interface
DEFAULT_INTERFACE=$(get_default_interface)

if [ -z "$DEFAULT_INTERFACE" ]; then
    echo "No network interface found"
    exit 1
fi

echo "Default interface is: $DEFAULT_INTERFACE"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    OS=$(uname -s)
fi

echo "Detected OS: $OS"

# Improved backup function with cleanup
backup_and_clean() {
    local file="$1"
    local backup_dir="/tmp/network_backup_$(date +%Y%m%d_%H%M%S)"
    
    # Create backup directory
    mkdir -p "$backup_dir"
    
    # Backup with timestamp if file exists
    if [ -f "$file" ]; then
        cp "$file" "$backup_dir/$(basename "$file")"
        echo "Backup created: $backup_dir/$(basename "$file")"
    fi
}

# Clean existing netplan configurations
clean_netplan_configs() {
    echo "Cleaning existing netplan configurations..."
    
    # Create backup directory for all existing configs
    local backup_dir="/tmp/netplan_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup and remove existing netplan configs
    if [ -d "/etc/netplan" ]; then
        cp -r /etc/netplan/* "$backup_dir/" 2>/dev/null
        rm -f /etc/netplan/*.yaml
    fi
}

# Configure Ubuntu/Debian with netplan
configure_netplan() {
    echo "Configuring with Netplan..."
    
    # Clean existing configurations
    clean_netplan_configs
    
    # Create a single netplan configuration
    cat > "/etc/netplan/01-netcfg.yaml" << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $DEFAULT_INTERFACE:
      dhcp4: no
      dhcp6: no
      addresses: [$IP_CIDR]
      routes:
        - to: default
          via: $GATEWAY
          metric: 100
      nameservers:
        addresses: [$DNS1, $DNS2]
EOF
    
    # Generate and apply configuration
    echo "Generating netplan configuration..."
    netplan generate
    
    echo "Applying netplan configuration..."
    netplan --debug apply
}

# Configure with NetworkManager
configure_networkmanager() {
    echo "Configuring with NetworkManager..."
    CONNECTION_NAME="static-$DEFAULT_INTERFACE"
    
    # Remove any existing connection with the same name
    nmcli connection delete "$CONNECTION_NAME" 2>/dev/null
    
    # Remove any existing connection for the interface
    existing_conn=$(nmcli -g NAME connection show | grep "$DEFAULT_INTERFACE")
    if [ ! -z "$existing_conn" ]; then
        nmcli connection delete "$existing_conn" 2>/dev/null
    fi
    
    # Create new connection
    nmcli connection add \
        con-name "$CONNECTION_NAME" \
        ifname "$DEFAULT_INTERFACE" \
        type ethernet \
        ip4 "$IP_CIDR" \
        gw4 "$GATEWAY"
    
    # Configure DNS
    nmcli connection modify "$CONNECTION_NAME" ipv4.dns "$DNS1 $DNS2"
    nmcli connection modify "$CONNECTION_NAME" ipv4.ignore-auto-routes yes
    nmcli connection modify "$CONNECTION_NAME" ipv4.never-default no
    
    # Activate the connection
    nmcli connection up "$CONNECTION_NAME"
}

# Configure with traditional network scripts
configure_traditional() {
    echo "Configuring with traditional network scripts..."
    IFCFG_FILE="/etc/sysconfig/network-scripts/ifcfg-$DEFAULT_INTERFACE"
    
    # Backup existing configuration
    backup_and_clean "$IFCFG_FILE"
    
    # Remove existing configuration
    rm -f "$IFCFG_FILE"
    
    # Create new configuration
    cat > "$IFCFG_FILE" << EOF
DEVICE=$DEFAULT_INTERFACE
BOOTPROTO=none
ONBOOT=yes
IPADDR=$IP_ADDRESS
NETMASK=$NETMASK
GATEWAY=$GATEWAY
DNS1=$DNS1
DNS2=$DNS2
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=no
EOF
    
    # Restart network service
    echo "Restarting network service..."
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart NetworkManager.service 2>/dev/null || systemctl restart network.service
    else
        service network restart
    fi
}

# Configure Debian/Ubuntu interfaces
configure_interfaces() {
    echo "Configuring with /etc/network/interfaces..."
    
    # Backup existing configuration
    backup_and_clean "/etc/network/interfaces"
    
    # Create new configuration
    cat > "/etc/network/interfaces" << EOF
auto lo
iface lo inet loopback

auto $DEFAULT_INTERFACE
iface $DEFAULT_INTERFACE inet static
    address $IP_ADDRESS
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameservers $DNS1 $DNS2
EOF
    
    # Restart networking
    echo "Restarting networking service..."
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart networking.service || true
        systemctl restart systemd-networkd.service || true
    else
        service networking restart || true
    fi
}

# Main configuration logic based on OS
case $OS in
    "ubuntu"|"pop"|"elementary")
        if command -v netplan >/dev/null 2>&1; then
            configure_netplan
        elif command -v nmcli >/dev/null 2>&1; then
            configure_networkmanager
        else
            configure_interfaces
        fi
        ;;
    "debian")
        if command -v nmcli >/dev/null 2>&1; then
            configure_networkmanager
        else
            configure_interfaces
        fi
        ;;
    "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
        if command -v nmcli >/dev/null 2>&1; then
            configure_networkmanager
        else
            configure_traditional
        fi
        ;;
    *)
        if command -v nmcli >/dev/null 2>&1; then
            configure_networkmanager
        elif command -v netplan >/dev/null 2>&1; then
            configure_netplan
        else
            echo "Unable to determine appropriate network configuration method."
            echo "Supported methods not found (NetworkManager, Netplan, or traditional networking)"
            exit 1
        fi
        ;;
esac

# Verify configuration using available commands
echo -e "\nNew network configuration:"
if command -v ip >/dev/null 2>&1; then
    ip addr show $DEFAULT_INTERFACE
elif command -v ifconfig >/dev/null 2>&1; then
    ifconfig $DEFAULT_INTERFACE
else
    echo "Network interface information:"
    cat /sys/class/net/$DEFAULT_INTERFACE/address
    cat /sys/class/net/$DEFAULT_INTERFACE/operstate
fi

echo -e "\nDefault route:"
if command -v ip >/dev/null 2>&1; then
    ip route | grep default
elif command -v route >/dev/null 2>&1; then
    route -n | grep '^0.0.0.0'
else
    netstat -rn | grep '^0.0.0.0'
fi