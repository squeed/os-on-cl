#!/bin/bash

#
# Some helper functions for bringing up a Centos and CL cluster
#

CENTOS_IMAGE_URL="http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2.xz"
COREOS_IMAGE_URL="https://alpha.release.core-os.net/amd64-usr/current/coreos_production_qemu_image.img.bz2"
CENTOS_BACKING_IMAGE=assets/centos-7.qcow2
COREOS_BACKING_IMAGE=assets/coreos.img
CLOUD_CONFIG_IMAGE=assets/config.iso
IGNITION_CONFIG=assets/ignition.json
COMMON_VIRT_OPTS="--memory=2048 --vcpus=1 --os-type=linux --os-variant=generic --noautoconsole"
NET_NAME=os

function main {
    case "$1" in
        "download") getAssets;;
        "init") init $2;;
        "createNodes") createNodes;; 
    esac
}

## Download asset directory
function getAssets {
    mkdir -p assets
    curl $CENTOS_IMAGE_URL -o ${CENTOS_BACKING_IMAGE}.xz
    xz -d ${CENTOS_BACKING_IMAGE}.xz

    curl $COREOS_IMAGE_URL -o ${COREOS_BACKING_IMAGE}.bz2
    bunzip2 ${COREOS_BACKING_IMAGE}.bz2
}


function init {
    #createNetwork
    createConfigImages $1
}


## Create the network xml
function createNetwork {
    virsh net-create --file net.xml
    virsh net-start $NET_NAME
}

## create the files we'll use for configuration
function createConfigImages {
    ssh_key_file="$1";
    if [ ! -f $ssh_key_file ] ; then
        echo "usage: init <path_to_ssh_key>"
        exit 1
    fi

    echo "using ssh key at $ssh_key_file"

    ./bin/create-config-drive --ssh-key $ssh_key_file $CLOUD_CONFIG_IMAGE

    ssh_key=$(cat $ssh_key_file)

    echo "generating $IGNITION_CONFIG"
    jq -c ".passwd.users[0].sshAuthorizedKeys[0]=\"$ssh_key\"" < ignition.json.tmpl > $IGNITION_CONFIG
}

function createNode {
    name="$1";
    mac="$2";
    ip="$3";

    sudo virsh net-update $NET_NAME add ip-dhcp-host \
          "<host mac='$mac' name='$name.os.testing' ip='$ip' />" --live --config
    echo "create $name.qcow2"

    disk_path="/var/lib/libvirt/images/$name.qcow2"
    config_path="/var/lib/libvirt/images/$name-cfg.iso"

    sudo qemu-img create \
        -f qcow2 \
        -o backing_file=$CENTOS_BACKING_IMAGE \
        $disk_path;

    sudo cp $CLOUD_CONFIG_IMAGE $config_path;
    
    sudo virt-install \
        --name $name \
        --disk path=$disk_path,format=qcow2,bus=virtio \
        --disk path=$config_path,device=cdrom \
        --network=network=$NET_NAME,mac=$mac \
        --boot=hd \
        $COMMON_VIRT_OPTS;
}

function createCoreosNode {
    name="$1";
    mac="$2";
    ip="$3";

    sudo virsh net-update $NET_NAME add ip-dhcp-host \
          "<host mac='$mac' name='$name.os.testing' ip='$ip' />" --live --config

    sudo qemu-img create \
        -f qcow2 \
        -o backing_file=$COREOS_BACKING_IMAGE \
        /var/lib/libvirt/images/$name.qcow2;

    sudo cp $IGNITION_CONFIG /var/lib/libvirt/manifests/${name}.ignition

    echo "virt-install";
    sudo virt-install \
        --name $name \
        --network=network=$NET_NAME,mac=$mac \
        --disk path=/var/lib/libvirt/images/$name.qcow2,format=qcow2,bus=virtio \
        --boot=hd \
        --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=/var/lib/libvirt/manifests/${name}.ignition" \
        $COMMON_VIRT_OPTS 

}

function deleteNode {
    name="$1";

    sudo virsh destroy $name;
    sudo virsh undefine $name --remove-all-storage;
}

function deleteNodes {
  deleteNode master1
  deleteNode worker1
  deleteNode worker2
  deleteNode worker3
}


function createNodes {
  createNode master1 52:54:00:00:00:10 192.168.124.10
  createNode worker1 52:54:00:00:00:50 192.168.124.50
  createNode worker2 52:54:00:00:00:51 192.168.124.51
  
  createCoreosNode worker3 52:54:00:00:00:52 192.168.124.52
}

main $@
