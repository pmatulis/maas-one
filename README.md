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

> **Note**: File ``OPENSTACK.md`` contains instructions for applying this
  solution to an OpenStack cloud. It shows how to configure and use OpenStack.
  It does not show how to **build** the cloud.

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

    10.0.0.1   - 10.0.0.9     Infra     <-- infrastructure
    10.0.0.10  - 10.0.0.39    Dynamic   <-- MAAS DHCP (enlistment, commissioning)
    10.0.0.40  - 10.0.0.99    FIP       <-- OpenStack floating IPs (if needed)
    10.0.0.100 - 10.0.0.119   VIP       <-- HA workloads (if needed)

So deployed nodes will use:

    10.0.0.120 - 10.0.0.254

## Download this repo

SSH to the KVM host with agent forwarding enabled. Forward your usual personal
keys.

    ssh -A <kvm-host>
    git clone https://github.com/pmatulis/maas-one

## Install the software

> **Important**: The Ubuntu release & architecture that you want to use for the
  MAAS host must correspond to this line in `install-software.sh`:
  `sudo uvt-simplestreams-libvirt sync release=<XXX> arch=<XXX>`.
  The release will be stated in step 'Create the MAAS host and server'.

Install the software on the KVM host:

    cd ~/maas-one
    ./install-software.sh

## Set up the environment

Log out and back in again and ensure that the 'default' libvirt network exists:

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

1. Your personal SSH key(s) are imported three times (INSERT YOURS instead of
   'petermatulis'):

    1. to the MAAS host 'ubuntu' user
       - to allow basic connections to the MAAS host

    1. to the MAAS host 'root' user
       - to allow transferring the 'root' user public SSH key to the KVM host
         (for MAAS to be able to manage power of KVM guests)

    1. to the MAAS server 'admin' user
       - key will be installed on every MAAS-deployed node

    This key(s) should be forwarded when initially connecting to the KVM host.

1. The MAAS version is chosen by way of a snap channel. Change it to your
   liking.

## Create the MAAS host and server

Create the MAAS host and server from the KVM host:

    cd ~/maas-one
    uvt-kvm create \
       --template ./template-maas.xml \
       --user-data ./user-data-maas.yaml \
       --cpu 4 --memory 4096 --disk 20 maas \
       release=focal

The MAAS host should be ready in a few minutes:

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

> **Note**: From the MAAS host, `maas-login.sh` can be used, if ever needed, to
  log in to MAAS.

Check that the MAAS server is up:

    nc -vz 10.0.0.2 5240
    Connection to 10.0.0.2 5240 port [tcp/*] succeeded!

Do not proceed until the MAAS server is responding (as shown above).

## Configure MAAS

Configure MAAS by running a script that was transferred earlier:

    ssh ubuntu@10.0.0.2 ./config-maas.sh

## Verify the web UI

Set up local port forwarding from your desktop:

    ssh -N -L 8002:10.0.0.2:5240 ubuntu@<kvm-host>

Access the web UI:

    http://localhost:8002/MAAS
    credentials: admin/ubuntu

In the web UI confirm the availability of boot images. Continue when all the
images (chosen in `config-maas.sh`) are in the 'Synced' state.

## Create the nodes

Creating the nodes will have them boot and be enlisted by MAAS.

> **Optional**: Use ZFS pools with extra disks (or some other way to optimise
  the disk sub-system). If choosing ZFS like this, perform the steps in
  `zfs-pools.txt` now.

To create the nodes run a script on the KVM host (if you are not using a custom
libvirt pool then you will first need to edit the script):

    cd ~/maas-one
    ./create-nodes.sh

You can ignore the warning that you may get about 'libvirt-qemu' user
permissions.

In the web UI confirm the appearance of the nodes. Continue when all five nodes
are in the 'New' state.

## Configure the nodes

Configure the nodes by running a script that was transferred earlier:

    ssh ubuntu@10.0.0.2 ./config-nodes.sh

In the web UI confirm the new node names and node power settings. The nodes
should also be commissioning. Continue when all five nodes are in the 'Ready'
state.

## Configure Juju

Define a MAAS cloud, add it to Juju, and add a cloud credential by running a
script on the KVM host:

    cd ~/maas-one
    ./cloud-and-creds.sh

## Create the Juju controller

From the KVM host, create a controller called 'maas-one' for cloud 'mymaas'.
The node with the assigned tag 'juju' will be used:

    juju bootstrap --bootstrap-series=focal --bootstrap-constraints tags=juju maas-one maas-one

<!-- LINKS -->

[cdg]: https://docs.openstack.org/project-deploy-guide/charm-deployment-guide/latest/
