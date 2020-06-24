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
MAAS_IMAGES="bionic focal"

maas login $PROFILE http://localhost:5240/MAAS - < $API_KEY_FILE >/dev/null

FABRIC_ID=$(maas $PROFILE subnet read $INTERNAL_SUBNET | grep fabric- -m 1 | awk '{print $2}' | cut -d '"' -f 2)

maas $PROFILE vlan update fabric-1 untagged dhcp_on=True primary_rack=$MAAS_INTERNAL_IP >/dev/null && echo "DHCP enabled on untagged VLAN on $FABRIC-ID"
maas $PROFILE ipranges create type=reserved start_ip=$INFRA_RANGE_START end_ip=$INFRA_RANGE_END comment="Infra" >/dev/null && echo "Reserved IP range set (Infra)"
maas $PROFILE ipranges create type=dynamic start_ip=$DHCP_RANGE_START end_ip=$DHCP_RANGE_END >/dev/null && echo "Dynamic IP range set (DHCP)"
maas $PROFILE ipranges create type=reserved start_ip=$VIP_RANGE_START end_ip=$VIP_RANGE_END comment="VIP" >/dev/null && echo "Reserved IP range set (VIP)"
maas $PROFILE subnet update $INTERNAL_SUBNET gateway_ip=$KVM_INTERNAL_IP >/dev/null && echo "Default gateway set for subnet $INTERNAL_SUBNET"
maas $PROFILE subnet update $INTERNAL_SUBNET dns_servers=$KVM_INTERNAL_IP >/dev/null && echo "DNS server set for subnet $INTERNAL_SUBNET"

for i in $MAAS_IMAGES; do

	maas $PROFILE boot-source-selections create 1 \
	   os="ubuntu" release="$i" arches="amd64" subarches="hwe-x" labels="*" \
	   >/dev/null && echo "\n$i amd64 images selected for download"

done

maas $PROFILE boot-resources import >/dev/null && echo "Importing images now..."

#echo "> > > > > > > > > > > > > > > > > > > > > > > > > > > > > > > > > ETA"
#IMAGES_DIR=/var/lib/maas/boot-resources/current/ubuntu/amd64/generic
#until ls -l \$IMAGES_DIR | grep trusty >/dev/null ; do sleep 10; echo -n "> "; done   # more hardcoded stuff
#echo "\nDone!"
