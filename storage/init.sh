#!/bin/bash

## Configure name resolution

sed -i "2i10.0.0.11       controller" /etc/hosts
##sed -i "2i10.0.0.31       compute" /etc/hosts

apt update

apt install -y lvm2
pvcreate /dev/sdb
vgcreate cinder-volumes /dev/sdb

##/etc/lvm/lvm.conf
sed -i "142i         filter = [ "a\/sdb\/", "r\/.*\/"]" /etc/lvm/lvm.conf

apt install -y cinder-volume

##/etc/cinder/cinder.conf
##[DEFAULT]
echo 'my_ip = 10.0.0.41' >> /etc/cinder/cinder.conf
echo 'glance_api_servers = http://controller:9292' >> /etc/cinder/cinder.conf
echo 'transport_url = rabbit://openstack:openstack_pass@controller' >> /etc/cinder/cinder.conf
##[database]
echo '[database]
connection = mysql+pymysql://cinder:cinder@controller/cinder' >> /etc/cinder/cinder.conf
echo '[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = cinder
password = cinder' >> /etc/cinder/cinder.conf
##[lvm]
echo '[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
iscsi_protocol = iscsi
iscsi_helper = tgtadm' >> /etc/cinder/cinder.conf
##[oslo_concurrency]
echo '[oslo_concurrency]
lock_path = /var/lib/cinder/tmp' >> /etc/cinder/cinder.conf

service tgt restart
service cinder-volume restart
