# OpenShift on Container Linux

Just an experiment in running OpenShift Node on Container Linux

## Setup:

First, you probably want to put NetworkManager in to "dnsmasq"  mode, which allows for dns overlays. 

1. Download the backing images:
    `./setup.sh download`
2. Set up config drives
    `./setup.sh init <PATH_TO_SSH_KEY>`
3. Create the cluster
    `sudo ./setup.sh createNodes`
4. Add DNS overlay:
    `echo server=/os.testing/192.168.124.1 | sudo tee /etc/NetworkManager/dnsmasq.d/os.conf`
5. Install Openshift via ansible using the supplied hosts file
6. Create the client identity for worker3, our container linux node:
```
    ssh centos@master1.os.testing
    mkdir worker3; cd worker3
    sudo openshift admin create-api-client-config --client-dir=. --groups=system:nodes --user=system:node:worker3.os.testing --certificate-authority=/etc/origin/master/ca.crt --signer-cert=/etc/origin/master/ca.crt --master "https://master1.os.testing:8443" --signer-key=/etc/origin/master/ca.key --signer-serial=/etc/origin/master/ca.serial.txt
    sudo openshift admin ca create-server-cert --cert=server.crt --key=server.key --expire-days=720 --hostnames=worker3.os.testing,192.168.124.52 --signer-cert=/etc/origin/master/ca.crt --signer-key=/etc/origin/master/ca.key --signer-serial=/etc/origin/master/ca.serial.txt
    sudo chown -R centos .
```
7. Copy the generated files locally. "Borrow" the CNI plugins while we're at it
```
    scp -r centos@master1.os.testing:worker3 ./
    scp -r centos@master1.os.testing:/opt/cni ./
    cp node-config.yaml worker3/
    echo "nameserver 192.168.124.1" > worker3/resolv.conf
```
8. Install the node configuration and unit files
```
    scp -r units worker3 cni core@worker3.os.testing:
    ssh core@worker3.os.testing
    sudo chown -R root:root worker3
    sudo mkdir -p /etc/origin
    sudo mv worker3 /etc/origin/node
    sudo cp units/* /etc/systemd/system
    sudo cp -r cni /opt
    sudo systemctl daemon-reload
```
9. Start everything! This will take some time as the image is fetched
```
    sudo rkt fetch --trust-keys-from-https quay.io/casey_callendrello/openshift-hyperkube-testing:v3.7.0-casey1 
    sudo systemctl start ovsdb-server ovs-vswitchd origin-node
```


## TODO:
1. Run openvswitch as a daemonset
2. Clean up DNS
