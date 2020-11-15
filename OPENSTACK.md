# Using maas-one for an OpenStack cloud

There are notes to follow once OpenStack has been built using the four MAAS
nodes. Instructions for building an OpenStack cloud are here:

https://docs.openstack.org/project-deploy-guide/charm-deployment-guide/latest/install-openstack.html

Note that the four available nodes should be sufficiently resourced. Disk and
network interface requirements should already be fulfilled if the README was
followed.

All commands are invoked on the KVM host.

> **Note**: If the README was followed precisely then the commands can be
  invoked as-is.

## Base client requirements

    ssh-keygen -q -N '' -f ~/.ssh/admin-key
    sudo snap install openstackclients --classic
    curl http://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img --output ~/focal-amd64.img
    git clone https://github.com/openstack-charmers/openstack-bundles ~/openstack-bundles
    source ~/openstack-bundles/stable/openstack-base/openrc

## Set up OpenStack networking (and image)

    openstack image create --public --container-format bare --disk-format raw --property architecture=x86_64 --property hw_disk_bus=virtio --property hw_vif_model=virtio --file ~/focal-amd64.img focal-amd64
    openstack network create ext_net --external --share --default --provider-network-type flat --provider-physical-network physnet1
    openstack subnet create ext_subnet --allocation-pool start=10.0.0.10,end=10.0.0.99 --subnet-range 10.0.0.0/24 --no-dhcp --gateway 10.0.0.1 --network ext_net
    openstack network create int_net --internal
    openstack subnet create int_subnet --allocation-pool start=192.168.0.10,end=192.168.0.99 --subnet-range 192.168.0.0/24 --gateway 192.168.0.1 --dns-nameserver 10.0.0.2 --network int_net
    openstack router create router1
    openstack router add subnet router1 int_subnet
    openstack router set router1 --external-gateway ext_net

## OpenStack usage

### One-time setup

    openstack keypair create --public-key ~/.ssh/admin-key.pub admin-key

    for i in $(openstack security group list | awk '/default/{ print $2 }'); do
        openstack security group rule create $i --protocol icmp --remote-ip 0.0.0.0/0;
        openstack security group rule create $i --protocol tcp --remote-ip 0.0.0.0/0 --dst-port 22;
    done

    openstack flavor create --public --ram 256 --disk 3 --ephemeral 3 --vcpus 1 m1.micro

    NET_ID=$(openstack network show int_net -f value -c id)

### Instance creation

    openstack server create --image focal-amd64 --flavor m1.micro --key-name admin-key --nic net-id=$NET_ID focal-1
    FLOATING_IP=$(openstack floating ip create -f value -c floating_ip_address ext_net)
    openstack server add floating ip focal-1 $FLOATING_IP

### Instance connection

This is extremely useful to do prior to attempting an SSH connection:

    openstack console log show focal-1

Connect in the usual way:

    ssh -i ~/.ssh/admin-key ubuntu@$FLOATING_IP
