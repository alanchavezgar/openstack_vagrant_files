## NODOS DE ALMACENAMIENTO
### Se hace la instalación en todos

_En los nodos de almacenamiento:_

Prerequisitos:
1. Se instalan los paquetes y utilerias de soporte

```
$ apt-get install xfsprogs rsync
```

2. Se le da formato a los discos que no son de sistema
```
$ mkfs.xfs /dev/sdb
$ mkfs.xfs /dev/sdc
```

3. Se crean  los puntos de montaje para los discos
```
$ mkdir -p /srv/node/sdb
$ mkdir -p /srv/node/sdc
```

4. Se montan los discos
```
$ mount /srv/node/sdb
$ mount /srv/node/sdc
```

5. Crear o editar el archivo `/etc/rsyncd.conf` con el siguiente contenido

``` conf
uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = MANAGEMENT_INTERFACE_IP_ADDRESS

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
lock file = /var/lock/object.lock
```

En los nodos de almacenamiento

6. Editar el archivo `/etc/default/rsync`
```
RSYNC_ENABLE = true
```

7. Iniciar el servicio rsync
``` bash
$ service rsync start
```

**En los nodos de almacenamiento**

1. Instalar los componentes
``` bash
$ apt-get install swift swift-account swift-container swift-object
```

2.Descargar las configuraciones desde el repositorio de swift
``` bash
$ curl -o /etc/swift/account-server.conf https://git.openstack.org/cgit/openstack/swift/plain/etc/account-server.conf-sample?h=stable/ocata
$ curl -o /etc/swift/container-server.conf https://git.openstack.org/cgit/openstack/swift/plain/etc/container-server.conf-sample?h=stable/ocata
$ curl -o /etc/swift/object-server.conf https://git.openstack.org/cgit/openstack/swift/plain/etc/object-server.conf-sample?h=stable/ocata
```

3. Editar el archivo `/etc/swift/account-server.conf`
```
[DEFAULT]
bind_ip = MANAGEMENT_INTERFACE_IP_ADDRESS
bind_port = 6002
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = true

[pipeline:main]
pipeline = healthcheck recon account-server

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

4. Editar el archivo /etc/swift/container-server.conf
[DEFAULT]
bind_ip = MANAGEMENT_INTERFACE_IP_ADDRESS
bind_port = 6001
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = true

[pipeline:main]
pipeline = healthcheck recon container-server

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift
```

5. Editar el archivo `/etc/swift/object-server.conf`
```
[DEFAULT]
bind_ip = MANAGEMENT_INTERFACE_IP_ADDRESS
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
recon_lock_path = /var/lock
```

6. Cambiar los permisos al directorio `/srv/node`
``` bash
$ chown -R swift:swift /srv/node
```

7. Crear el directorio recon y asegurar que tiene los permisos correctos.
``` bash
$ mkdir -p /var/cache/swift
$ chown -R root:swift /var/cache/swift
$ chmod -R 755 /var/cache/swift
```


**CONTROLADOR**

* Crear y distribuir los anillos iniciales

1. Cambiar el directorio de trabajo a /etc/swift

2. Crear el archivo base account.builder:
``` bash
$ swift-ring-builder account.builder create 10 3 1
```

numero | significado
---|---
10 | cantidad de particiones |
3  | numero de replicas      |
1  | tiempo entre replicas   |

3. Agregar los nodos al anillo
``` bash
$ swift-ring-builder account.builder add --region 1 --zone 1 --ip 10.0.0.51 --port 6002 --device sdb --weight 100
$ swift-ring-builder account.builder add --region 1 --zone 1 --ip 10.0.0.51 --port 6002 --device sdc --weight 100
$ swift-ring-builder account.builder add --region 1 --zone 2 --ip 10.0.0.52 --port 6002 --device sdb --weight 100
$ swift-ring-builder account.builder add --region 1 --zone 2 --ip 10.0.0.52 --port 6002 --device sdc --weight 100
```

**Crear y distribuir los anillos iniciales**
4. Verificar el contenido del anillo
``` bash
$ swift-ring-builder account.builder
```

5. Se rebalancea el anillo
``` bash
swift-ring-builder account.builder rebalance
```

**Repetir desde el punto 2 para container y object decrementando los puertos hasta el :6000 en los anillos container.builder y account.builder**

Anillo    | Puerto
----------|-------
account   |6002
container |6001
object    |6000

14. Distribuir los archivos account.ring.gz, container.ring.gz y object.ring.gz
en el directorio `/etc/swift` de los nodos de almacenamiento de objetos.

### 5. Instalación y administración del almacenamiento de objetos.

Componentes del servicio|
------------------------|
Proxy servers           |
Anillos                 |
Zonas                   |
Cuentas y contenedores  |
Objetos                 |
Particiones             |

**NODO CONTROLADOR**

Finalizar la instalación
15. Obtener el archivo de configuración de swift
```
$ curl -o /etc/swift/swift.conf https://git.openstack.org/cgit/openstack/swift/plain/etc/swift.conf-sample?h=stable/ocata
```

16. Editar el archivo swift.conf
```
[swift-hash]
swift_hash_path_suffix = HASH_PATH_SUFFIX
swift_hash_path_prefix = HASH_PATH_PREFIX

[storage-policy:0]
name = Policy-0
default = yes
```

17. Copiar el archivo de configuración swift.conf a todos los nodos en la misma ubicación
`/etc/swift/swift.conf`

18. En todos los nodos asegurarse de que /etc/swift tiene los permisos correctos
``` bash
$ chown -R root:swift /etc/swift
```

19. En el controlador reinicar los servicios memcached y swift proxy
``` bash
$ service memcached restart
$ service swift-proxy restart
```

20. En los nodos de almacenamiento iniciar el servicio de swift
``` bash
$ swift-init all start
```

**NODO CONTROLADOR**

21. Cargar las variables de ambiente para adminsitrador

22. Mostrar el estado del servicio
``` bash
$ swift stat
```

23. Crear un contenedor
``` bash
$ openstack container create container1
```

24. Almacenar un archivo de prueba en el contenedor
``` bash
$ openstack object create container1 FILE
```

25. Listar los objetos almacenados en container 1
``` bash
$ openstack object list container 1
```

26. Descargar el archivo desde el contenedor
``` bash
$ openstack object save container1 FILE
```

### Administración de anillos

Listar el contenido de un archivo de definición de anillo
```
$ swift-ring-builder <nombre del archivo de anillo>
```

Agregar un nodo a un anillo
```
$ swift-ring-builder <nombre del archivo de anillo> add --region <región> --zone <zona> --ip <dirección ip> --port <puerto> --device <dispositivo> --weight <peso>
```

Crear anillo
```
$ swift-ring-builder create <nombre del archivo de anillo> <capacidad de particiones> <replicas> <horas>
```

Crear contenedores
```
$ openstack container create <nombre del contenedor>
```

Eliminar contenedor
```
$ openstack container delete [--recursive] <container> [<container> ...]
```

Listar contenedores
```
$ openstack  container list [--long] [--all]
```

Hacer una copia local del contenedor
```
$ openstack container save <nombre del contenedor>
```


### Administración de objetos
Crear objetos
```
$ openstack object create [--name <nombre>] <contenedor> <archivo>
```

Eliminar objetos
```
$ openstack object delete <contenedor> <objeto>
```

Listar objetos
```
$ openstack object list [--long] [-all] <contenedor>
```

Hacer una copia local del objeto
```
$ openstack object save [--file <archivo>] <contenedor> <objeto>
```

##### CEILOMETER

## 2.8 Servicio de telemetría
##### _En el nodo controlador_ #####

1. Se crean las credenciales del usuario ceilometer
```
$ openstack user create --domain default --password-prompt ceilometer
```

Se agrega el rol admin al usuario ceilometer
```
$ openstack role add --project service --user ceilometer admin
```

Crear el servicio ceilometer
```
$ openstack service create --name ceilometer --description "Telemetría" meterin
```
Crear usuario gnocchi
```
$ openstack user create --domain default --password-prompt gnocchi
```

Crear el servicio gnocchi

```
$ openstack service create --name gnocchi --decription "Servicio de  métrica" metric
```

Se crean los endpints parael servicio ceilometer
```
$ openstack endpoint create --region RegionOne metric public http://controller:8041
$ openstack endpoint create --region RegionOne metric internal http://controller:8041
$ openstack endpoint create --region RegionOne metric admin http://controller:8041
```

Este paso, puede no ser necesario, algunas veces por la versión de openstack ya instala por defecrto gnocchi, en caso de no ser así, se debe instalar.
```
$ apt-get install gnocchi-api gnocchi-metricd gnocchi-common python-gnocchi.
```


#### Crear el servicio ceilometer
Instalación y configuración de los componentes ceilometer
```
$ apt-get install ceilometer-collector ceilometer-agent-central ceilometer-agent-notification python-ceilometerclient
```

2. Editar el archivo /etc/ceilometer/ceilometer.conf
```
[default]
meter_dispatchers = gnocchi
event_dispatchers = gnocchi
transport_url = rabbit://openstack:root@controller

[dispatcher_gnocchi]
filter_service_activity = false
archive_policy = low

[service_credentials]
auth_type = password
auth_url = http://controller:5000/v3
user_domain_name = default
project_name = service
username = ceilometer
password = CEILOMETER_PASS
interface = internalURL
region_name = RegionOne

[api]
auth_mode = keystone

[keystone_authtoken]
auth_type = password
auth_url = http://controller:5000/v3
project_domain_name = default
user_domain_name = default
project_name = service
username = gnocchi
password = GNOCCHI_PASS
interface = internalURL
region_name = RegionOne
```

3. Se crean los recursos de ceilometer en gnocchi
```
$ ceilometer-upgrade --skip-metering-database
```

4. Se reinicia el servicio detelemetría
```
$ service ceilometer-agent-central restart
$ service ceilometer-agent-notification restart
$ service ceilometer-collector restart
```

#### INSTALACIÓN MANUAL DE GNOCCHI
1. Crear las bases de datos en mysql
``` sql
CREATE  DATABASE gnocchi;
```

2. Crear el usuario para la base de de datos
``` sql
GRANT ALL PRIVILEGES ON gnocchi.* TO 'gnocchiuser'@'localhost' IDENTIFIED BY 'CONTRASEÑA'
GRANT ALL PRIVILEGES ON gnocchi.* TO 'gnocchiuser'@'%' IDENTIFIED BY 'CONTRASEÑA'
```

3. Si no se han instalado se instalan los paquetes
``` bash
apt install gnocchi-api
apt install gnocchi-metricd
apt install gnocchi-statsd
apt install gnocchi-common 'Sin configurar la base de datos'
apt install python-gnocchi
```

3. Crear el usuario _gnocchi_
``` bash
$ openstack user create --domain default --password-prompt gnocchi
```

4. Asignar el rol _admin_ al usuario _gnocchi_
``` bash
$ openstack role add--project servoce --user gnocchi admin
```

5. Crear el servicio para gnocchi
``` bash
$ openstack service create --name gnocchi-description "Métrica" metric
```

6. Se crean los endpoints para gnocchi
``` bash
$ openstack endpoint create --region RegionOne metric public http://controller8041
$ openstack endpoint create --region RegionOne metric admin http://controller8041
$ openstack endpoint create --region RegionOne metric internal http://controller8041
```

7. Editar el archivo /etc/gnocchi/gnocchi.conf
```
[database]
backend = sqlalchemy

[indexer]
url = mysql+pymysql://gnocchiuser:Contraseña@controller/gnocchiuser

[keystone_authtoken]
auth_uri = http://controller:5000/v3
identity_url = http://controller:35357/
admin_user = gnocchi
admin_password = CONTRASEÑA
admin_tenant_name = service
signing_dir = /var/cache/gnocchi

[statsd]
resource_id =
user_id =
project_id =
archive_policy_name = low

[storage]
coordination_url = file:///var/lib/gnocchi/locks
driver = file
file_basepath = /var/lib/gnocchi
```

8. Editar el archivo /etc/gnocchi/api-paste.ini
```
[pipeline:main]
pipeline = gnocchi+auth
```

9. Crear los directorios correspondientes en cache y lib
``` bash
$ mkdir /var/cache/gnocchi
$ chown gnocchi:gnocchi -R /var/cache/gnocchi
$ mkdir /var/lib/gnocchi
$ chown gnocchi:gnocchi -R /var/lib/gnocchi
```

10. Se inician los servicios
``` bash
$ service gnocchi-api start
$ service gnocchi-metricd start
$ service gnocchi-statsd start
```

12. Se agregan políticas para la adquisición de datos
``` bash
$ gnocchi archive-policy create -d granularity:5m,points:12 -d granularity:1h,points:24 -d granularity:1d,points:30 low
$ gnocchi archive-policy create -d granularity:60s,points:60 -d granularity:1h,points:168 -d granularity:1d,points:365 medium
$ gnocchi archive-policy create -d granularity:1s,points:86400 -d granularity:1m,points:43200 -d granularity:1h,points:8760 high
$ gnocchi archive-policy-rule create -a low -m "*" default
```

### Servicio de colector de datos (ceilometer)
* Instalación en cada nodo compute
1. Se instalan los paquetes
``` bash
$ apt-get install ceilometer-agent-compute
```

2. Se edita el archivo /etc/ceilometer/ceilometer.conf
```
[DEFAULT]
transport_url = rabbit://openstack:RABBIT_PASS@controller
...
auth_strategy = keystone

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = ceilometer
password = CEILOMETER_PASS

[service_credentials]
auth_url = http://controller:5000
project_domain_id = default
user_domain_id = default
auth_type = password
username  = ceilometer
project_name = ceilometer
password = CEILOMETER_PASS
interface = internalURL
region_name = RegionOne
```

* Instalación en cada nodo compute
3. Se edita /etc/nova/nova.conf
```
[DEFAULT]
instance_usage_audit = True
instance_usage_audit_period = hour
notify_on_state_change = vm_and_task_state

[oslo_messaging_notifications]
driver = messagingv2
```

4. Se inicia el agente de ceilometer
``` bash
$ service ceilometer-agent-compute restart
```

5. Se reinicia el servicio compute
``` bash
$ service nova-compute restart
```

* Configurar cinder para usar telemetría
1. Editar /etc/cinder/cinder.conf en el controlador y los nodos de almacenamiento de bloques
```
[oslo_messaging_notifications]
driver = messagingv2
```

2. Habilitar el uso  periódico de estadisticas relacionadas con cinder
###### Solamente en el nodo de almacenamiento de bloques
```
$ cinder-volume-usage-audit --start time='YYYY-MM-DD HH:MM:SS' --end-time='YYYY-MM-DD HH:MM:SS' --send_actions
```
Para obtener estos valores en forma periodica se debe colocar en el cron cada 5 minutos

```
*/5**** /path/to/cinder=volume-usage-audit --send_actions
```

3. Reiniciar el servicio  de almacenamiento de bloques
```
$ service cinder-api restart
$ service cinder-scheduler restart
```

4. Se reinicia el servicio de almacenamiento de bloques en los nodos de almacenamiento
```
$ service cinder-volume restart
```

#### De regreso al controlador
* Configurar glance para usar telemetría

1. Editar el archivo `/etc/glance/glance.api.conf` y `/etc/glance/glance-registry.conf``
```
[DEFAULT]
transport_url = rabbit://openstack:RABBIT_PASS@controller

[oslo_messaging_notifications]
driver = messagingv2
```

2. Se reinicia el servicio de imagen
``` bash
$ service glance-registry restart
$ service glance-api restart
```

* Configurar neutron para usar telemetría
1. Editar el archivo `/etc/neutron/neutron.conf`
``` bash
[oslo_messaging_notifications]
driver = messagingv2
```

2. Se reinicia el servicio de red
``` bash
$ service netron-server restart
```

* Configurar swift para usar telemetría
En el nodo controlador
1. Crear el rol ResellerAdmin
``` bash
$ openstack role create ResellerAdmin
```

2. Asignar el rol que se creó al usuario ceilometer
``` bash
$ openstack role add --project service --user ceilometer ResellerAdmin
```

3. Se instalan los paquetes
``` bash
$ apt-get install python-ceilometermiddleware
```

* En el nodo controladory encualquier nodo  de almacén de objetos
1. Editar el archivo `/etc/swift/proxyserver.conf`
```
[filter:keystoneauth]
Operator_roles = admin, useer, ResellerAdmin

[pipeline:main]
pipeline = catch_errors gat...
```

1. Editar el archivo `/etc/swift/proxyserver.conf`

[filter:ceilometer]
paste.filter_factory = ceilometermiddleware.swift:filter_factory
control_exchange = swift
url = rabbit://openstack:RABBIT_PASS@controller:5672/
driver = messagingv2
topic = notifications
log_level = WARN

2. Reiniciar el servicio swift-proxy
``` bash
$ service swift-proxy restart
```

#### Descargar el archivo de configuración de gnocchi.conf
``` bash
https://github.com/TSDBBench/Overlord/blob/master/vagrant_files/gnocchi_cl1/files/gnocchi.conf
```

* ### Servicio de alarma (aodh)
* Configurar el servicio de aodh

1. Se crea la base de datos para el servicio.
``` sql
CREATE DATABASE aodh;
```

2. Se crea un usuario y se asignan los permisos a la base de datos recién creada
``` sql
GRANT ALL PRIVILEGES ON aodh.* TO 'aodh'@'localhost' IDENTIFIED BY 'AODH_DBPASS';
GRANT ALL PRIVILEGES ON aodh.* TO 'aodh'@'%' IDENTIFIED BY 'AODH_DBPASS';
```

3. Se crea el usuario de openstack para controlar el servicio
``` bash
$ openstack user create --domain default --password-prompt aodh
```

4. Agregar el rol de admin al usuario
``` bash
$ openstack role add --project service --user aodh admin
```

5. Se crea el servicio para aodh
``` bash
$ openstack service create --name aodh --description "Telemetria" alarming
```

* Instalar y configurar los componentes
1. Instalar los paquetes del servicio
``` bash
$ apt-get install aodh-api aodh-evaluator aodh-notifier aodh-listener aodh-expirer python-aodhclient
```

2. Editar el archivo `/etc/aodh/aodh.conf`
```
[database]
connection = mysql+pymysql://aodh:AODH_DBPASS@controller/aodh

[DEFAULT]
transport_url = rabbit://openstack:RABBIT_PASS@controller
auth_strategy = keystone

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = aodh
password = AODH_PASS

[service_credentials]
auth_type = password
auth_url = http://controller:5000/v3
project_domain_name = default
user_domain_name = default
project_name = service
username = aodh
password = AODH_PASS
interface = internalURL
region_name = RegionOne
```

3. Inicializar la base de datos
``` bash
aodh-dbsync
```

3.  Reiniciar los servicios de alarma
``` bash
$ service aodh-api restart
$ service aodh-evaluator restart
$ service aodh-notifier restart
$ service aodh-listener restart
```

* Buenas practicas
``` html
https://demo.marpi.pl/codeology/
```

``` bash
ceilometer sample-list --meter cpu --q 'resource_id=INSTANCE_ID_1;timestamp > 2017-08-01T00:00:00;timestamp > 2017-08-01T00:00:00'
```

* Crear alarmas
``` bash
$ aodh alarm create
```

* Mostrar historial de alarmas
``` bash
aodh alarm-history show ALARM_ID
```

* Eliminar una alarma
``` bash
aodh alarm update --enabled False ALARM_ID
aodh alarm deleted ALARM_ID
```

**Niveles de seguridad**

* Seguridad fisica
  * Control de acceso
  * Energia electrica
  * Instalaciones y mobiliario
  * Inmueble


* Seguridad logica
  * Seguridad del sistema operativo
  * Seguridad del usuario
  * Seguridad de comunicaciones (redes)
  * Seguridad de aplicaciones
