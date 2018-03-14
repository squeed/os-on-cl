# OpenShift on Container Linux

Just an experiment in running OpenShift Node on Container Linux

## Setup:

First, you probably want to put NetworkManager in to "dnsmasq"  mode, which allows for dns overlays. 

1. Download the backing images:
    `./setup.sh download`
2. Set up config drives
    `./setup.sh init <PATH_TO_SSH_KEY>`
3. Create the cluster
    `setup.sh createNodes`
4. Add DNS overlay:
    `echo server=/os.testing/192.168.124.1 | sudo tee /etc/NetworkManager/dnsmasq.d/os.conf`
5. Install Openshift via ansible using the supplied hosts file
6. Create the client identity for worker3, our container linux node:
```
    ssh centos@master1.os.testing
    sudo bash
    mkdir worker3
    openshift admin create-api-client-config --client-dir=worker3 --groups=system:nodes --user=system:node:worker3.os.testing --certificate-authority=/etc/origin/master/ca.crt --signer-cert=/etc/origin/master/ca.crt --master "https://master1.os.testing:8443" --signer-key=/etc/origin/master/ca.key --signer-serial=/etc/origin/master/ca.serial.txt
    openshift admin ca create-server-cert --cert=server.crt --key=server.key --expire-days=720 --hostnames=worker3.os.testing,192.168.124.52 --signer-cert=/etc/origin/master/ca.crt --signer-key=/etc/origin/master/ca.key --signer-serial=/etc/origin/master/ca.serial.txt
    chown -R centos worker3
```
7. Copy the generated files locally
```
    scp -r centos@master1.os.testing:worker3 ./
    cp node-config.yaml worker3/
```
8. Install the node configuration and unit files
```
    scp -r units worker3 core@worker3.os.testing:
    ssh core@worker3.os.testing
    sudo chown -r root:root worker3
    sudo mkdir -p /etc/origin
    sudo mv worker3 /etc/origin/node
    sudp cp units/* /etc/systemd/system
```
9. Start everything! This will take some time as the image is fetched
```
    rkt fetch --trust-keys-from-https quay.io/casey_callendrello/openshift-hyperkube-testing:v3.7.0-casey1 
    systemctl start ovsdb-server
    systemctl start ovs-vswitchd
    systemctl start origin-node
```
