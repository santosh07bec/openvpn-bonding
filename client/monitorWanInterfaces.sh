#!/bin/bash

# This script is still WIP

##################################
# Monitor Wan interfaces and
# remove corresponding tap
# device if google isn't reachable
# via the WAN interface
##################################

# include the common settings
. /etc/openvpn/commonConfig

number_of_tunnel_up=$(ps -ef | grep openvpn | grep client | wc -l)

for i in `seq 1 $numberOfTunnels`; do
  tunnelInterface="tunnelInterface$i"
  echo "Checking Internet reachability via interface ${!tunnelInterface}."

  if ping -c 10 -W 10 -I ${!tunnelInterface} google.com | grep -oE '100% packet loss' > /dev/null 2>&1; then
    echo "Couldn't reach Internet from ${!tunnelInterface}."

    if [[ $number_of_tunnel_up -eq 2 ]]; then
      echo "Taking the Tunnel Down."
      echo bash /etc/openvpn/stoptunnel.sh ${!tunnelInterface}
    fi

  else
    echo "Internet reachable via interface ${!tunnelInterface}."

    if ! ps -ef | grep openvpn | grep client${i} > /dev/null; then
      echo "Internet reachable from ${!tunnelInterface}. Bringing tunnel UP."
      echo bash /etc/openvpn/starttunnel.sh ${!tunnelInterface}
    fi

  fi
done
