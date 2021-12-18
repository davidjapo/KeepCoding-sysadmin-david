#!/bin/bash
#Script de configuración inicial y aprovisionamiento del servidor wordpress:

#Habilita la sincronización con los servidores de internet del servicio de hora NTP:
timedatectl set-ntp on

#Particionado del disco extra:
echo ""
echo "Realizando particionado del disco extra..."
parted -s /dev/sdc mklabel gpt \
  mkpart part_BBDD ext4 2048s 2097118s \
  set 1 lvm on

#Creación del volúmen lógico que almacenará la BBDD:
echo "Creando el volúmen lógico para almacenar la BBDD..."
pvcreate /dev/sdc1
vgcreate sysadmin_vg /dev/sdc1
lvcreate -l 100%FREE sysadmin_vg -n disk_BBDD

#Formateo del volúmen lógico:
echo "Formateando el volúmen lógico..."
mkfs.ext4 /dev/sysadmin_vg/disk_BBDD

#Obteniendo el UUID asociado al volúmen lógico y haciendo persistente el punto de montaje:
echo "Configurando el punto de montaje del volúmen lógico de forma persistente..."
VLM_UUID=$(blkid | grep "sysadmin_vg-disk_BBDD" | cut -d\" -f2) && 
echo "UUID=$VLM_UUID /var/lib/mysql ext4 defaults 0 0" >> /etc/fstab
mkdir /var/lib/mysql
mount -a

#Actualizando el respositorio:
echo "Realizando actualización del indice del repositorio de software APT..."
apt-get update >/dev/null 2>&1

#Descargando e instalando nginx:
echo "Instalando nginx..."
apt-get install -y nginx >/dev/null 2>&1

#Descargando e instalando mariadb:
echo "Instalando maridb..."
apt-get install -y mariadb-server mariadb-common >/dev/null 2>&1

#Descargando e instalando dependencias de php:
echo "Instalando dependencias de php..."
apt-get install -y php-fpm php-mysql expect php-curl php-gd \
php-intl php-mbstring php-soap php-xml php-xmlrpc php-zip >/dev/null 2>&1

#Configurando la instancia de wordpress en nginx:
echo "Configurando la instancia de wordpress en nginx..."
tee /etc/nginx/sites-available/wordpress >/dev/null 2>&1 <<EOF 
# Managed by installation script - Do not change
server {
listen 80;
root /var/www/wordpress;
index index.php index.html index.htm index.nginx-debian.html;
server_name localhost;
location / {
try_files \$uri \$uri/ =404;
}
location ~ \.php\$ {
include snippets/fastcgi-php.conf;
fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
}
}
EOF

#Habilitando la instancia de wordpress en nginx:
echo "Habilitando la instancia de wordpress en nginx..."
ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

#Habilitando e iniciando el servicio de nginx y php:
echo "Habilitando y levantando el servicio de nginx y php..."
systemctl enable nginx --now
systemctl enable php7.4-fpm --now

#Securizando mariadb:
echo "Securizando mariadb..."
mysql_secure_installation <<END

n
y
y
y
y
END

#Creación de la BBDD y del usuario de wordpress:
echo "Creando la base de datos y el usuario administador de wordpress..."
mysql <<HEREDOC
CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE
utf8_unicode_ci;
GRANT ALL ON wordpress.* TO 'wordpressuser'@'localhost' IDENTIFIED BY
'keepcoding';
FLUSH PRIVILEGES;
HEREDOC

#Descargando y descomprimiento el CMS Wordpress:
echo "Descargando e instalando el CMS Wordpress..."
cd /tmp && wget https://wordpress.org/latest.tar.gz
cd /var/www/ && tar -xzvf /tmp/latest.tar.gz

#Aplicando configuración de Wordpress:
echo "Aplicando configuración de Wordpress..."
cd /var/www/wordpress
cat wp-config-sample.php | sed -e 's/database_name_here/wordpress/g; s/username_here/wordpressuser/g; s/password_here/keepcoding/g' > wp-config.php
chown -R www-data:www-data /var/www/wordpress
systemctl restart nginx

#Descargando e instalando Filebeat:
echo "Realizando descarga e instalación de Filebeat..."
#Importando la Key de su repositorio y a continuación se añade el repositorio:
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-7.x.list
apt-get update >/dev/null 2>&1
apt-get install -y filebeat >/dev/null 2>&1
filebeat modules enable system
filebeat modules enable nginx

#Configurando Filebeat:
echo "Aplicando configuración personalizada a Filebeat..."
cd /etc/filebeat
cp filebeat.yml filebeat_backup.yml
echo -e "    - /var/log/nginx/*.log\n    - /var/log/mysql/*.log" > mypaths
tee mycommands.sed <<END
/type: filestream/s/filestream/log/
s/^..enabled: false/  enabled: true/
/^..paths:/r mypaths
/#output.logstash:/s/#//
s!^..#hosts: \["localhost:5044"\]!  hosts: \["192.168.10.254:5044"\]!
END

sed -f mycommands.sed filebeat_backup.yml > filebeat.yml

#Habilitando e iniciando el servicio de Filebeat:
echo "Habilitando y levantando el servicio de Filebeat..."
systemctl enable filebeat --now

echo ""
echo "****Configuración terminada. VM1 - Wordpress: En servicio****"

exit 0
