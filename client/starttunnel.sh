#!/bin/bash

################################################
# Starts tunnel for specified WAN interface.
# Can be to tirn down the tap interface when
# the connecivity on the WAN interface is down.
################################################

interface=$1

# Check input Parameter
if [[ -z $interface ]]; then
  echo -e "usages:\n\t$0 <interface_name>"
  exit 0
fi

# Read commonConfig file for common variables
. /etc/openvpn/commonConfig

# Check if bond0 interface exists
if ! ip -br addr | grep "$bondInterface" > /dev/null 2>&1; then
  echo "$bondInterface is not created. Run \"startbond.sh\" script first."
  exit 0
fi

# Parse interface id using the interface name
interface_name=$(grep "$interface" /etc/openvpn/commonConfig | grep 'tunnelInterface' | cut -d '=' -f 1)
interface_number=${interface_name: -1}
openvpn_client_pid=$(ps -ef | grep openvpn | grep client${interface_number}.conf | grep -v grep | awk '{print $2}')

# Check if the OpenVPN process already running for interface
if [[ "x$openvpn_client_pid" -ne "x" ]]; then
  echo -e "Tunnel for interface $interface appears to be up already.\nPID:$openvpn_client_pid\nStop the tunnel first and try again."
  exit 0
fi

tunnelInterface="tunnelInterface$interface_number"
configFileName="/etc/openvpn/client/client${interface_number}.conf"

# Check if the OpenVPN config file exists
if [[ ! -s $configFileName ]]; then
  echo "Config file $configFileName doesn't exists. Run \"startbond.sh\" script first."
fi

echo "Creating tap interface tap${interface_number}"
sudo openvpn --mktun --dev tap${interface_number}
sudo ip link set tap${interface_number} master $bondInterface

echo "Adding routing table vpn${interface_number}"
sudo sed -i s/"^#1${interface_number} vpn${interface_number}"/"1${interface_number} vpn${interface_number}"/g /etc/iproute2/rt_tables

# Get CIDR of the interface
readarray -td " " templine <<< $(ip -br addr | grep ${!tunnelInterface} | sed  's/ \+/ /g' )
tunnelInterfaceIP=${templine[2]}
echo "with IP address ${tunnelInterfaceIP}"

# Get GW of the interface
readarray -td " " templine <<< $(ip -br route | grep ${!tunnelInterface} | grep default)
tunnelInterfaceGW=${templine[2]}

if [[ $tunnelInterfaceGW == ppp* ]]; then
  readarray -td " " templine <<< $(ip -br route | grep ${!tunnelInterface} | grep src)
  tunnelInterfaceGW=${templine[0]}
fi

# Add routes
sudo ip rule add pref 10 from $tunnelInterfaceIP table "vpn$interface_number"
sudo ip route add default via $tunnelInterfaceGW dev ${!tunnelInterface} table "vpn$interface_number"

# Start OpenVPN client process
if sudo openvpn --daemon --config $configFileName; then
  echo "Started OpenVPN Client for interface $interface"
else
  echo "Failed to start OpenVPN Client for interface $interface"
fi

ps -ef | grep -i openvpn
