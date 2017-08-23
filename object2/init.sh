#!/bin/bash

echo '
export PS1="\[\e[01;34m\]object2\[\e[0m\]\[\e[01;37m\]:\w\[\e[0m\]\[\e[00;37m\]\n\\$ \[\e[0m\]"
' >> /home/vagrant/.bashrc

## Configure name resolution

sed -i "2i10.0.0.11       controller" /etc/hosts
sed -i "2i10.0.0.31       compute" /etc/hosts
sed -i "2i10.0.0.41       storage" /etc/hosts
sed -i "2i10.0.0.51       object1" /etc/hosts
sed -i "2i10.0.0.52       object2" /etc/hosts

apt-get install -y xfsprogs rsync

# Se formatean los discos duros
mkfs.xfs /dev/sdb
mkfs.xfs /dev/sdc

# Se crean los directorios
mkdir -p /srv/node/sdb
mkdir -p /srv/node/sdc

# Se montan los discos
mount /dev/sdb /srv/node/sdb
mount /dev/sdc /srv/node/sdc

# Archivo de configuración
touch /etc/rsyncd.conf

echo 'uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = 10.0.0.52

[account]
max connection = 2
path = /srv/node/
read only = false
lock file = /var/lock/account.lock

[container]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/container.lock

[object]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/object.lock' >> /etc/rsync.conf

# Editar archivo rsync
echo 'RSYNC_ENABLE = true' >> /etc/default/rsync

# Reiniciar servicio
service rsync start

# Instalar los componentes
apt-get install -y swift swift-account swift-container swift-object

# Descargar las configuraciones desde el repositorio de swift
curl -o /etc/swift/account-server.conf https://git.openstack.org/cgit/openstack/swift/plain/etc/account-server.conf-sample?h=stable/ocata
curl -o /etc/swift/container-server.conf https://git.openstack.org/cgit/openstack/swift/plain/etc/container-server.conf-sample?h=stable/ocata
curl -o /etc/swift/object-server.conf https://git.openstack.org/cgit/openstack/swift/plain/etc/object-server.conf-sample?h=stable/ocata

# Editar account-server.conf
echo '[DEFAULT]
bind_ip = 10.0.0.52
bind_port = 6002
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = true

[pipeline:main]
pipeline = healthcheck recon account-server

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift' >> /etc/swift/account-server.conf

# Editar container-server.conf
echo '[DEFAULT]
bind_ip = 10.0.0.52
bind_port = 6001
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = true

[pipeline:main]
pipeline = healthcheck recon container-server

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift' >> /etc/swift/container-server.conf

# Editar object-server.conf
echo '[DEFAULT]
bind_ip = 10.0.0.52
bind_port = 6000
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = true

[pipeline:main]
pipeline = healthcheck recon object-server

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift
recon_lock_path = /var/lock' >> /etc/swift/object-server.conf

chown -R swift:swift /srv/node

mkdir -p /var/cache/swift
chown -R root:swift /var/cache/swift
chmod -R 755 /var/cache/swift

#TODO: Línea 121 del archivo de apuntes
