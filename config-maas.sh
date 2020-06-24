#!/bin/bash                                                                                                                             
                                                                                                                                        
#set -e                                                                                                                                 
                                                                                                                                        
PROFILE=admin
API_KEY_FILE=/home/ubuntu/admin-api-key
KVM_INTERNAL_IP=10.0.0.1
MAAS_INTERNAL_IP=10.0.0.2
INTERNAL_SUBNET=10.0.0.0/24
INFRA_RANGE_START=10.0.0.1
INFRA_RANGE_END=10.0.0.9
DHCP_RANGE_START=10.0.0.10
DHCP_RANGE_END=10.0.0.99
VIP_RANGE_START=10.0.0.100
VIP_RANGE_END=10.0.0.119

maas login $PROFILE http://localhost:5240/MAAS - < $API_KEY_FILE >/dev/null

FABRIC_ID=$(maas $PROFILE subnet read $INTERNAL_SUBNET | grep fabric- -m 1 | awk '{print $2}' | cut -d '"' -f 2)

maas $PROFILE vlan update fabric-1 untagged dhcp_on=True primary_rack=$MAAS_INTERNAL_IP >/dev/null && echo "DHCP enabled on untagged VLAN on $FABRIC-ID"
maas $PROFILE ipranges create type=reserved start_ip=$INFRA_RANGE_START end_ip=$INFRA_RANGE_END comment="Infra" >/dev/null && echo "Reserved IP range set (Infra)"
maas $PROFILE ipranges create type=dynamic start_ip=$DHCP_RANGE_START end_ip=$DHCP_RANGE_END >/dev/null && echo "Dynamic IP range set (DHCP)"
maas $PROFILE ipranges create type=reserved start_ip=$VIP_RANGE_START end_ip=$VIP_RANGE_END comment="VIP" >/dev/null && echo "Reserved IP range set (VIP)"
maas $PROFILE subnet update $INTERNAL_SUBNET gateway_ip=$KVM_INTERNAL_IP >/dev/null && echo "Default gateway set for subnet $INTERNAL_SUBNET"
maas $PROFILE subnet update $INTERNAL_SUBNET dns_servers=$KVM_INTERNAL_IP >/dev/null && echo "DNS server set for subnet $INTERNAL_SUBNET"

declare -A nodeNamesMACs=( \
        [node1]=52:54:00:03:01:01 \
        [node2]=52:54:00:03:02:01 \
        [node3]=52:54:00:03:03:01 \
        [node4]=52:54:00:03:04:01 \
        [controller]=52:54:00:02:01:01 \
        )

maas $PROFILE tags create name=juju comment='Juju controller' >/dev/null && echo -ne "\nMAAS tag 'controller' created"

# For each KVM guest node:
for i in "${!nodeNamesMACs[@]}"; do
        echo -e "\nConfiguring node $i"
        MAC1=${nodeNamesMACs[$i]}
        SYSTEM_ID=$(maas $PROFILE machines read mac_address=$MAC1 | grep -i system_id -m 1 | cut -d '"' -f 4)
        maas $PROFILE machine update $SYSTEM_ID \
                hostname=$i \
                power_type=virsh \
                power_parameters_power_address=qemu+ssh://ubuntu@"$KVM_EXTERNAL_IP"/system \
                power_parameters_power_id=$i >/dev/null && echo "- Node name changed and power type configured"
        maas $PROFILE machine commission $SYSTEM_ID testing_scripts=none >/dev/null && echo "- Node commissioning (hardware tests skipped)"

        # Node 'controller' is the Juju controller, apply tag 'juju'
        if [ $i = "controller" ]; then
                 maas $PROFILE tag update-nodes controller add=$SYSTEM_ID >/dev/null && echo "- Tag 'juju' assigned to node $i"
        fi

done
