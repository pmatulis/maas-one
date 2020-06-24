#!/bin/sh -e                                                                    

VARIANT=ubuntu18.04
VCPUS=2
RAM_SIZE_MB=4000
DISK_SIZE_GB_1=30
NAME=controller
MAC1="52:54:00:02:01:01"
POOL=images

virt-install \
        --os-variant $VARIANT \
        --graphics vnc \
        --noautoconsole \
        --network network=internal,mac=$MAC1 \
        --name $NAME \
        --vcpus $VCPUS \
        --cpu host \
        --memory $RAM_SIZE_MB \
        --disk "$NAME"_1.img,size=$DISK_SIZE_GB_1,pool=$POOL \
        --boot network
