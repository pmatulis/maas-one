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
DHCP_RANGE_END=10.0.0.39
FIP_RANGE_START=10.0.0.40
FIP_RANGE_END=10.0.0.99
VIP_RANGE_START=10.0.0.100
VIP_RANGE_END=10.0.0.119
IMAGE_SERIES="bionic focal"
IMAGE_ARCH=amd64

maas login $PROFILE http://localhost:5240/MAAS - < $API_KEY_FILE >/dev/null

FABRIC_ID=$(maas $PROFILE subnet read $INTERNAL_SUBNET \
   | grep fabric- -m 1 | awk '{print $2}' | cut -d '"' -f 2)

RACK_SYSTEM_ID=$(maas $PROFILE rack-controllers read \
   | grep -i system_id -m 1 | cut -d '"' -f 4)

maas $PROFILE ipranges create type=reserved \
   start_ip=$INFRA_RANGE_START end_ip=$INFRA_RANGE_END comment="Infra" \
   >/dev/null && echo "Reserved IP range set (Infrastructure addresses)"

maas $PROFILE ipranges create type=dynamic \
   start_ip=$DHCP_RANGE_START end_ip=$DHCP_RANGE_END \
   >/dev/null && echo "Dynamic IP range set (DHCP for MAAS)"

maas $PROFILE ipranges create type=reserved \
   start_ip=$FIP_RANGE_START end_ip=$FIP_RANGE_END comment="FIP for OpenStack" \
   >/dev/null && echo "Reserved IP range set (FIP for OpenStack)"

maas $PROFILE ipranges create type=reserved \
   start_ip=$VIP_RANGE_START end_ip=$VIP_RANGE_END comment="VIP for OpenStack" \
   >/dev/null && echo "Reserved IP range set (VIP for OpenStack)"

maas $PROFILE vlan update $FABRIC_ID untagged \
   dhcp_on=True primary_rack=$RACK_SYSTEM_ID \
   >/dev/null && echo "DHCP enabled on untagged VLAN on $FABRIC_ID"

maas $PROFILE subnet update \
   $INTERNAL_SUBNET gateway_ip=$KVM_INTERNAL_IP \
   >/dev/null && echo "Default gateway set to $KVM_INTERNAL_IP for subnet $INTERNAL_SUBNET"

maas $PROFILE subnet update \
   $INTERNAL_SUBNET dns_servers=$KVM_INTERNAL_IP \
   >/dev/null && echo "DNS server set to $MAAS_INTERNAL_IP for subnet $INTERNAL_SUBNET"

maas $PROFILE maas set-config \
   name=upstream_dns value=$KVM_INTERNAL_IP \
   >/dev/null && echo "DNS forwarder set to $KVM_INTERNAL_IP"

maas $PROFILE maas set-config \
   name=dnssec_validation value=no \
   >/dev/null && echo "DNSSEC validation disabled"

# An image for the latest LTS release (first point release must be available)
#   is selected by default (with the MAAS host's architecture).
#   You may not need anything else.
# We're being explicit here.
for i in $IMAGE_SERIES; do

   maas $PROFILE boot-source-selections create 1 \
      os="ubuntu" release="$i" arches="$IMAGE_ARCH" subarches="*" labels="*" \
      >/dev/null

done

# Initiate the import of images selected above.
maas $PROFILE boot-resources import \
   >/dev/null && echo "Importing $IMAGE_SERIES amd64 images now..."
