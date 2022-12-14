#!/bin/bash

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
  --hcloud-token)
    TOKEN="$2"
    shift
    shift
  ;;
  --whitelisted-ips)
    WHITELIST_S="$2"
    shift
    shift
  ;;
  --floating-ips)
    FLOATING_IPS="1"
    shift
  ;;
  *)
    shift
  ;;
esac
done

NEW_NODE_IPS=( $(curl -H 'Accept: application/json' -H "Authorization: Bearer ${TOKEN}" 'https://api.hetzner.cloud/v1/servers' | jq -r '.servers[].public_net.ipv4.ip') )

touch /etc/current_node_ips
cp /etc/current_node_ips /etc/old_node_ips
echo "" > /etc/current_node_ips

for IP in "${NEW_NODE_IPS[@]}"; do
#  ufw allow from "$IP"
  ufw allow proto tcp from "$IP"
  ufw allow proto udp from "$IP"
  echo "$IP" >> /etc/current_node_ips
  echo "$IP"
done

##jb## Add Load Balancers IPS
#NEW_LB_IPS=( $(curl -H 'Accept: application/json' -H "Authorization: Bearer ${TOKEN}" 'https://api.hetzner.cloud/v1/load_balancers' | jq -r '.load_balancers[].public_net.ipv4.ip') )

NEW_LB_IPS=( $(curl --location --request charset=en_US.UTF-8 GET 'https://api.hetzner.cloud/v1/load_balancers' --header 'Authorization: Bearer ${TOKEN}' | jq -r '.load_balancers[].public_net.ipv4.ip') )

for IP in "${NEW_LP_IPS[@]}"; do
#  ufw allow from "$IP"
  ufw allow proto tcp from "$IP"
  ufw allow proto udp from "$IP"
  echo "$IP" >> /etc/current_node_ips
done
##jb## Add Load Balancers IPS

IFS=$'\r\n' GLOBIGNORE='*' command eval 'OLD_NODE_IPS=($(cat /etc/old_node_ips))'

REMOVED=()
for i in "${OLD_NODE_IPS[@]}"; do
  skip=
  for j in "${NEW_NODE_IPS[@]}"; do
    [[ $i == $j ]] && { skip=1; break; }
  done
  [[ -n $skip ]] || REMOVED+=("$i")
done
declare -p REMOVED

for IP in "${REMOVED[@]}"; do
  ufw deny from "$IP"
done

FLOATING_IPS=${FLOATING_IPS:-"0"}

if [ "$FLOATING_IPS" == "1" ]; then
  FLOATING_IPS=( $(curl -H 'Accept: application/json' -H "Authorization: Bearer ${TOKEN}" 'https://api.hetzner.cloud/v1/floating_ips' | jq -r '.floating_ips[].ip') )    

  for IP in "${FLOATING_IPS[@]}"; do
    ip addr add $IP/32 dev eth0
  done  
fi
