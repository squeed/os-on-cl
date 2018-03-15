FROM openshift/origin:v3.7.0

RUN yum install -y openvswitch conntrack-tools
