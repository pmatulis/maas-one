#!/bin/sh

for i in maas controller node1 node2 node3 node4; do
        virsh destroy $i
        virsh undefine $i --remove-all-storage
done
