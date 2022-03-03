#!/bin/bash

################################################
# Stops individual tunnel.
# Can be used to tern wown the tap device when
# the connecivity for the WAN interface is down.
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

echo "Killing OpenVPN Clinet PID:$openvpn_client_pid"
if sudo kill $openvpn_client_pid; then
  echo 'ok'
else
  echo "Failed to kill PID:$openvpn_client_pid"
fi

echo "Deleting default route from table vpn${interface_number}"
if sudo ip route del default table "vpn${interface_number}"; then
  echo 'ok'
else
  echo "Failed to delete default route from table vpn${interface_number}"
fi

echo "Deleting route table vpn${interface_number}"
if sudo ip rule del table "vpn${interface_number}"; then
  echo 'ok'
else
  echo "Failed to delete table vpn${interface_number}"
fi
# if sudo sed -i s/"^1${interface_number} vpn${interface_number}"/"#1${interface_number} vpn${interface_number}"/g /etc/iproute2/rt_tables; then echo 'ok'; else echo "Failed to delete table vpn${interface_number}"; fi

echo "Deleting tap device tap${interface_number}"
if openvpn --rmtun --dev tap${interface_number}; then
  echo 'ok'
else
  echo "Failed to delete tap device tap${interface_number}"
fi
