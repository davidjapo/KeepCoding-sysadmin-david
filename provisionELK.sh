#!/bin/bash
#Script para aprovisionamiento del servidor elasticsearch:

#Habilita la sincronización con los servidores de internet del servicio de hora NTP:
timedatectl set-ntp on


#Particionado del disco extra:
echo ""
echo "Realizando particionado del disco extra..." 
parted -s /dev/sdc mklabel gpt \
  mkpart partELK ext4 2048s 2097118s \
  set 1 lvm on

#Creación del volúmen lógico que almacenará la BBDD:
echo "Creando el volúmen lógico para almacenar la BBDD..."
pvcreate /dev/sdc1
vgcreate sysadmin_vg /dev/sdc1
lvcreate -l 100%FREE sysadmin_vg -n diskELK

#Formateo del volúmen lógico:
echo "Formateando el volúmen lógico..."
mkfs.ext4 /dev/sysadmin_vg/diskELK

#Obteniendo el UUID asociado al volúmen lógico y haciendo persistente el punto de montaje:
echo "Configurando el punto de montaje del volúmen lógico de forma persistente..."
VLM_UUID=$(blkid | grep "sysadmin_vg-diskELK" | cut -d\" -f2) && 
echo "UUID=$VLM_UUID /var/lib/elasticsearch ext4 defaults 0 0" >> /etc/fstab
mkdir /var/lib/elasticsearch
mount -a

#Actualizando el respositorio:
echo "Realizando actualización del indice del repositorio de software APT..."
apt-get update >/dev/null 2>&1

#Descargando e instalando nginx y dependencias de JRE:
echo "Instalando nginx y dependencias de Java JRE (sea paciente, puede tardar un par de minutos)..."
apt-get install -y nginx default-jre >/dev/null 2>&1

#Habilitando e iniciando el servicio de nginx:
echo "Habilitando y levantando el servicio de nginx..."
if ! systemctl enable nginx --now; then echo "***EL COMANDO SE HA EJECUTADO CON ERRORES***"; fi

#Descargando e instalando Logstash:
echo "Realizando descarga e instalación de Logstash..."
#Importando la Key del repositorio Elastic.co. A continuación se añade el repositorio:
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-7.x.list
apt-get update >/dev/null 2>&1
apt-get install -y logstash >/dev/null 2>&1

#Descargando e instalando Elasticsearch:
echo "Realizando descarga e instalación de Elasticsearch..."
apt-get install -y elasticsearch >/dev/null 2>&1

#Descargando e instalando Kibana:
echo "Realizando descarga e instalación de Kibana..."
apt-get install -y kibana >/dev/null 2>&1

#Aplicando configuración personalizada para Logstash:
echo "Aplicando configuración personalizada para Logstash..."
tee /etc/logstash/conf.d/02-beats-input.conf >/dev/null 2>&1 <<END
    input {
     beats {
      port => 5044
     }
    }
END
tee /etc/logstash/conf.d/30-elasticsearch-output.conf >/dev/null 2>&1 <<AAA
    output {
     elasticsearch {
      hosts => ["localhost:9200"]
      manage_template => false
      index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
     }
    }
AAA
cp /vagrant/logstash-syslog-filter.conf /etc/logstash/conf.d/10-syslog-filter.conf


#Habilitando e iniciando el servicio de Logstash:
echo "Habilitando y levantando el servicio de Logstash (sea paciente, puede tardar unos minutos))..."
if ! systemctl enable logstash --now; then echo "***EL COMANDO SE HA EJECUTADO CON ERRORES***"; fi

#Habilitando e iniciando el servicio de Elasticsearch:
echo "Habilitando y levantando el servicio de ElasticSearch (sea paciente, puede tardar unos minutos))..."
chown -R elasticsearch:elasticsearch /var/lib/elasticsearch
chmod -R 754 /var/lib/elasticsearch
if ! systemctl enable elasticsearch --now; then echo "***EL COMANDO SE HA EJECUTADO CON ERRORES***"; fi

#Habilitando e iniciando el servicio de Kibana:
echo "Habilitando y levantando el servicio de Kibana (sea paciente, puede tardar unos minutos))..."
if ! systemctl enable kibana --now; then echo "***EL COMANDO SE HA EJECUTADO CON ERRORES***"; fi

#Modificando la instancia default en nginx para redirijir el puerto 80 al puerto 80 de Kibana:
echo "Modificando la instancia default en nginx para redirijir el puerto 80 y además aplicar una autenticación básica..."
cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak
tee /etc/nginx/sites-available/default >/dev/null 2>&1 <<GOAL
# Managed by installation script - Do not change
 server {
   listen 80;
   server_name kibana.demo.com localhost;
   auth_basic "Restricted Access";
   auth_basic_user_file /etc/nginx/htpasswd.users;
   location / {
     proxy_pass http://localhost:5601;
     proxy_http_version 1.1;
     proxy_set_header Upgrade \$http_upgrade;
     proxy_set_header Connection 'upgrade';
     proxy_set_header Host \$host;
     proxy_cache_bypass \$http_upgrade;
   }
 }
GOAL

#Generando fichero 'htpasswd.users' donde se especifica el usuario y contraseña encriptada para Kibana:
#Será necesario tener un fichero con nombre '/vagrant/.kibana' en dicha ruta. 
#Este archivo almacena en texto plano la contraseña que será encriptada:
echo "Generando fichero de contraseñas para Kibana..."
echo "kibanaadmin:$(openssl passwd -apr1 -in /vagrant/.kibana)" | tee -a /etc/nginx/htpasswd.users >/dev/null 2>&1
if ! systemctl restart nginx; then echo "***EL COMANDO SE HA EJECUTADO CON ERRORES***"; fi
if ! systemctl restart kibana; then echo "***EL COMANDO SE HA EJECUTADO CON ERRORES***"; fi

echo ""
echo "****Configuración terminada. VM2 - ELK: En servicio****"


exit 0
