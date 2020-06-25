#!/bin/sh -e

# The `uvt-simplestreams-libvirt` command provides the
# release for the MAAS host itself.

cd
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y uvtool virtinst
sudo uvt-simplestreams-libvirt sync release=focal arch=amd64
sudo snap install juju --classic
sudo snap install charm --classic
#sudo snap install openstackclients --classic
#charm pull openstack-base
