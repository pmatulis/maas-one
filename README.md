# Overview

This project installs a MAAS cluster on a single machine. 

Environment summary:

* 1 powerful host (the "KVM host") running Ubuntu 18.04 LTS or Ubuntu 20.04 LTS

* 6 KVM guests residing on the KVM host:
     * 1 for the MAAS host itself
     * 1 for the Juju controller
     * 4 for the MAAS nodes (available for deployments)

* 2 libvirt networks:
     * 'external' for the external side of the MAAS host
     * 'internal' for the internal side of the MAAS host

* The KVM host, beyond hosting the guests, will act as the Juju client

The four guests destined for MAAS nodes are currently configured with a lot of
CPU power, a lot of memory, two network interfaces, and three disks. This is
because the original intent was the deployment of [Charmed OpenStack][cdg].
Adjust per your needs and desires by modifying `create-nodes.sh`.

Before you begin, look over all the files. They're pretty simple.

## General topology

                          |
               eth0 +-----+
                          |
    +-------------------------------------------+
    | MAAS host           |       MAAS host     |
    | 192.168.122.2       |       10.0.0.2      |
    |                     |                     |
    |                     +-----+ virbr1        |
    |                     |       10.0.0.1      |
    |        virbr0 +-----+                     |
    | 192.168.122.1       |                     |
    +-------------------------------------------+
      192.168.122.0/24    | 10.0.0.0/24
      external            | internal
                          |
      libvirt DHCP on     | libvirt DHCP off
                          | MAAS DHCP on

## MAAS node network

Subnet DNS: `10.0.0.2`

Subnet gateway: `10.0.0.1`

Reserved IP ranges:

    10.0.0.1   - 10.0.0.9     Infra
    10.0.0.10  - 10.0.0.99    Dynamic   <-- DHCP (enlistment, commissioning)
    10.0.0.100 - 10.0.0.119   VIP       <-- HA workloads (if needed)

So deployed nodes will use:
   
    10.0.0.120 - 10.0.0.254

## Download this repo

SSH to the KVM host with agent forwarding enabled. Forwarding can help with
connectivity as `uvtool` can auto-install the agent's keys on its created
instances. 

    ssh -A <kvm-host>
    git clone https://github.com/pmatulis/maas-one

## Install the software

Install the software on the KVM host:

    cd ~/maas-one
    ./install-software.sh

## Set up the environment

Log out and back in again and ensure the 'default' libvirt network exists:

    virsh net-list --all

Create the libvirt networks:

    cd ~/maas-one
    ./create-networks.sh

Create a test instance to discover the names of the two MAAS host network
interfaces (created via `template-maas.xml`). Reference these in
`user-data-maas.yaml`, the cloud-init file for the MAAS host.

    uvt-kvm create --template ./template-maas.xml test release=focal
    uvt-kvm ssh test ip a  # e.g. enp1s0 and enp2s0
    uvt-kvm destroy test

Edit `user-data-maas.yaml`:

Your personal SSH key(s) are imported three times (INSERT YOURS instead
of 'petermatulis'):

1. to the MAAS host 'ubuntu' user
   - to allow basic connections to the MAAS host

1. to the MAAS host 'root' user
   - to allow transferring the 'root' user public SSH key to the KVM host
     (for MAAS to be able to manage power of KVM guests)

1. to the MAAS server 'admin' user
   - key will be installed on every MAAS-deployed node

This key should be forwarded when initially connecting to the KVM host.

## Create the MAAS host and server

Create the MAAS host and server from the KVM host:

    cd ~/maas-one
    uvt-kvm create \
       --template ./template-maas.xml \
       --user-data ./user-data-maas.yaml \
       --cpu 4 --memory 4096 --disk 30 maas \
       release=focal

The MAAS host should be ready in about five minutes:

    ssh ubuntu@10.0.0.2 uname

## Post install MAAS tasks

Get the API key for the MAAS server 'admin' user:

    scp ubuntu@10.0.0.2:admin-api-key ~

Install the public SSH key for the MAAS host 'root' user into the 'ubuntu' user
account on the KVM host:

    ssh root@10.0.0.2 cat /var/snap/maas/current/root/.ssh/id_rsa.pub >> /home/ubuntu/.ssh/authorized_keys

Confirm that the 'root' user can query libvirtd of the KVM host:

    ssh ubuntu@10.0.0.2
    sudo snap run --shell maas
    virsh -c qemu+ssh://ubuntu@10.0.0.1/system list --all
    exit
    exit

Transfer some scripts to the MAAS host:

    cd ~/maas-one
    scp config-maas.sh config-nodes.sh maas-login.sh ubuntu@10.0.0.2:

> **Note**: Script `maas-login.sh` is a handy script for logging in to MAAS.

## Configure MAAS

Connect to the MAAS host and run a script:

    ssh ubuntu@10.0.0.2
    ./config-maas.sh
    exit

## Verify the web UI

Set up local port forwarding from your workstation:

    ssh -N -L 8002:10.0.0.2:5240 ubuntu@<kvm-host>

Access the web UI:

    http://localhost:8002/MAAS
    credentials: admin/ubuntu

Confirm networking and images.

Verify controller status ('regiond' to 'dhcpd' should be green)
If not green:

    ssh ubuntu@10.0.0.2 sudo systemctl restart maas-rackd.service
    ssh ubuntu@10.0.0.2 sudo systemctl restart maas-regiond.service

## Create the nodes

> **Optional**: Use ZFS pools with extra disks (or some other way to optimise
  the disk sub-system). If choosing ZFS like this, perform the steps in
  `zfs-pools.txt` now.

Run a script on the KVM host:

    cd ~/maas-one
    ./create-nodes.sh

If you are not using a custom libvirt pool then you will need to edit the
script.

You can ignore the warning that you may get about 'libvirt-qemu' user
permissions.

In the web UI confirm the appearance of the nodes. Continue when all five nodes
are in the 'New' state. 

## Configure the nodes

Connect to the MAAS host and run a script:

    ssh ubuntu@10.0.0.2
    ./config-nodes.sh
    exit

In the web UI confirm the new node names and node power settings. The nodes
should also be commissioning. Continue when all five nodes are in the 'Ready'
state.

## Configure Juju

Define a MAAS cloud, add it to Juju, and add a cloud credential.

Run a script on the KVM host:

    cd ~/maas-one
    ./cloud-and-creds.sh

## Create the Juju controller

From the KVM host, create a controller called 'maas-one' for cloud 'mymaas'.
The node with the assigned tag 'juju' will be used:

    juju bootstrap --bootstrap-constraints tags=juju mymaas maas-one

<!-- LINKS -->

[cdg]: https://docs.openstack.org/project-deploy-guide/charm-deployment-guide/latest/
