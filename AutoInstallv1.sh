#!/bin/bash

# Variables de configuración
domain="ocsapro"
ddns_subdomain="ddns.$domain"
admin_user="admin"
admin_password="admin"
mysql_password="root"
file_mysql="/opt/gnudip/doc/gnudip.mysql"
file_mysqlupgrade="/opt/gnudip/doc/upgrade.mysql"
config_file="/opt/gnudip/etc/gnudip.conf"
apache_conf="/etc/apache2/sites-enabled/default-ssl.conf"
gdipadmin_script="/opt/gnudip/sbin/gdipadmin.pl"
services_file="/etc/services"
xinetd_config="/etc/xinetd.d/gnudip"
gnudip_server="/opt/gnudip/sbin/gdipinet.pl"
gnudip_tar="gnudip-2.4.tar.gz"
url="https://github.com/ssarante/gnudip/raw/refs/heads/main/gnudip-2.4.tar.gz"
ip_address=$(hostname -I | awk '{print $1}')

# Actualizar e instalar paquetes necesarios
apt update && apt install -y bind9 apache2 libapache2-mod-perl2 mysql-server dnsutils xinetd wget libdbd-mysql-perl

# Configurar la zona DNS
cat <<EOF >> /etc/bind/named.conf.local
zone "$ddns_subdomain" IN {
      type master;
      file "/etc/bind/db.$ddns_subdomain";
      allow-query { any; };
      update-policy { grant gnudip-key subdomain $ddns_subdomain; };
};
EOF

# Crear el archivo de zona DNS
cat <<EOF > /etc/bind/db.$ddns_subdomain
\$TTL 86400
@   IN SOA  ns1.$ddns_subdomain. root.$domain. (
              0       ; serial
              3600    ; refresh
              1800    ; retry
              604800  ; expire
              0       ; TTL for NACKs
            )
    IN NS    ns1.$ddns_subdomain.
ns1 IN A     $ip_address
EOF

# Descargar y configurar GnuDIP
#mkdir -p /opt/gnudip
#cd /opt/gnudip || exit
wget $url --no-check-certificate
#wget http://gnudip2.sourceforge.net/gnudip-www/src/gnudip-2.3.5.tar.gz --no-check-certificate


# Extraer archivos
sudo tar xvzf gnudip-2.4.tar.gz -C /opt

#Creando DOC donde se aloja de db
#mkdir /opt/gnudip/doc
#tar xzf /opt/gnudip/gnudip-2.3.5.tar.gz -C /opt/gnudip/doc --strip 1
#rm -r /opt/gnudip/doc/gnudip

# Verificar si el archivo existe
if [[ ! -f "$file_mysql" ]]; then
    echo "Error: El archivo $file_mysql no existe."
    exit 1
fi

# Reemplazar 'gnudippass' por la nueva contraseña
sed -i "s/'gnudippass'/'$mysql_password'/g" "$file_mysql"

# Confirmar que el cambio se realizó
if grep -q "'$mysql_password'" "$file_mysql"; then
    echo "Contraseña configurada correctamente en $file_mysql."
else
    echo "Error: No se pudo actualizar la contraseña en $file_mysql."
    exit 1
fi

## Modificar el archivo para hacerlo compatible con MySQL 5.*
#sed -i "s/\(.*\)default '0'\(.*\)auto_increment,/\1\2auto_increment,/" "$file_mysql"
#
## Confirmar que el cambio se realizó
#if grep -q "auto_increment," "$file_mysql"; then
#    echo "Archivo $file_mysql modificado correctamente para compatibilidad con MySQL 5.*."
#else
#    echo "Error: No se pudo aplicar la modificación."
#    exit 1
#fi

# Verificar si los archivos se extrajeron correctamente
if [ ! -d "/opt/gnudip/etc" ]; then
    echo "Error: No se extrajo correctamente GnuDIP."
    exit 1
fi


# Verificar si el archivo existe
if [[ ! -f "$config_file" ]]; then
    echo "Error: El archivo $config_file no existe."
    exit 1
fi

# Reemplazar solo 'gnudippass' por la nueva contraseña
sed -i 's/\(gnudippassword = \)gnudippass/\1'"$mysql_password"'/' "$config_file"

# Confirmar que el cambio se realizó
if grep -q "gnudippassword = $mysql_password" "$config_file"; then
    echo "Contraseña configurada correctamente en $config_file."
else
    echo "Error: No se pudo actualizar la contraseña en $config_file."
    exit 1
fi

# Generar clave para actualizaciones DNS
cd /opt/gnudip/etc || exit
dnssec-keygen -a RSASHA256 -b 2048 -n ZONE gnudip-key
key_file=$(ls Kgnudip-key.+*.private 2>/dev/null | head -n 1)

# Verificar que la clave se generó correctamente
if [ -z "$key_file" ]; then
    echo "Error: No se generó la clave DNSSEC correctamente."
    exit 1
fi

key_string=$(grep "Key:" "$key_file" | awk '{print $2}')

# Ajustar configuración de GnuDIP

if [ -f "$config_file" ]; then
    sed -i "s|^nsupdate =.*|nsupdate = -k $key_file|g" "$config_file"
    sed -i "s|^gnudippassword =.*|gnudippassword = $mysql_password|g" "$config_file"
else
    echo "Error: Archivo gnudip.conf no encontrado."
    exit 1
fi

# Configurar clave en BIND
echo "key gnudip-key {
      algorithm RSASHA256;
      secret \"$key_string\";
};" > /etc/bind/gnudip-key

# Configurar MySQL
#mysql -u root -p <<EOF
#CREATE USER IF NOT EXISTS 'gnudip'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mysql_password';
#GRANT ALL PRIVILEGES ON gnudip2.* TO 'gnudip'@'localhost';
#FLUSH PRIVILEGES;
#EOF

# PREPARANDO DB
echo "Subiendo base de datos a MySQL..."

# Verificar si los archivos existen antes de ejecutar MySQL
if [[ ! -f "$file_mysql" ]]; then
    echo "Error: No se encontró el archivo $file_mysql"
    exit 1
fi

#if [[ ! -f "$file_mysqlupgrade" ]]; then
#    echo "Error: No se encontró el archivo $file_mysqlupgrade"
#    exit 1
#fi

# Subir la base de datos
echo "Importando $file_mysql..."
mysql -u root -p < "$file_mysql"
if [[ $? -ne 0 ]]; then
    echo "Error al importar $file_mysql"
    exit 1
fi

#echo "Importando $file_mysqlupgrade..."
#mysql -u root -p"$mysql_password" gnudip2 < "$file_mysqlupgrade"
#if [[ $? -ne 0 ]]; then
#    echo "Error al importar $file_mysqlupgrade"
#    exit 1
#fi

echo "Base de datos importada correctamente."


# Configurar Apache
a2enmod ssl
a2ensite default-ssl
service apache2 restart

#reset servicios de dns
chown bind /etc/bind
service bind9 restart

# Líneas a agregar
config_lines="
RedirectMatch ^/gnudip(\/*)$ https://ns1.ddns.$domain/gnudip/cgi-bin/gnudip.cgi
Alias /gnudip/html/ /opt/gnudip/html/
<Location /gnudip/html/>
    Options Indexes
    ReadmeName .README
    HeaderName .HEADER
    RemoveHandler .pl
    RemoveType .pl
    AddType text/plain .pl
</Location>
ScriptAlias /gnudip/cgi-bin/ /opt/gnudip/cgi-bin/
"

# Verificar si las líneas ya están en el archivo
if grep -q "RedirectMatch \^/gnudip(\\/*)$ https://ns1.ddns.$domain/gnudip/cgi-bin/gnudip.cgi" "$apache_conf"; then
    echo "La configuración ya está en $apache_conf, no es necesario agregarla."
else
    echo "Agregando configuración a $apache_conf..."
    echo "$config_lines" >> "$apache_conf"
fi

echo "Configuración de Apache completada."

# Configurar permisos de GnuDIP
chown -R www-data:www-data /opt/gnudip

# Verificar si el script existe
if [ ! -f "$gdipadmin_script" ]; then
    echo "Error: No se encontró $gdipadmin_script. Verifica la instalación de GnuDIP."
    exit 1
fi

# Crear usuario administrador
echo "Creando usuario administrador..."
"$gdipadmin_script" -u "$admin_user" "$admin_password"

if [ $? -eq 0 ]; then
    echo "Usuario administrador '$admin_user' creado correctamente."
else
    echo "Error al crear el usuario administrador."
    exit 1
fi

# Reiniciar Apache para aplicar cambios
echo "Reiniciando Apache..."
systemctl restart apache2

# Agregar puerto 3495/tcp a /etc/services si no está presente
if ! grep -q "^gnudip[[:space:]]*3495/tcp" "$services_file"; then
    echo "Añadiendo puerto GnuDIP (3495/tcp) a /etc/services..."
    echo "gnudip          3495/tcp" >> "$services_file"
else
    echo "El puerto GnuDIP (3495/tcp) ya está configurado en /etc/services."
fi

# Crear el archivo de configuración para xinetd
echo "Configurando xinetd para GnuDIP..."
cat <<EOF > "$xinetd_config"
service gnudip
{
    flags       = REUSE
    socket_type = stream
    protocol    = tcp
    wait        = no
    user        = www-data
    server      = $gnudip_server
    bind        = 0.0.0.0
}
EOF

# Verificar si el archivo del servidor GnuDIP existe
if [ ! -f "$gnudip_server" ]; then
    echo "Error: No se encontró $gnudip_server. Verifica la instalación de GnuDIP."
    exit 1
fi

# Reiniciar xinetd para aplicar los cambios
echo "Reiniciando xinetd..."
service xinetd restart

if [ $? -eq 0 ]; then
    echo "Configuración de xinetd completada correctamente."
else
    echo "Error al reiniciar xinetd."
    exit 1
fi

if [ $? -eq 0 ]; then
    echo "Configuración de xinetd completada correctamente."

    # Si todo fue exitoso, eliminar el archivo tar.gz
    if [ -f "$gnudip_tar" ]; then
        echo "Eliminando archivo $gnudip_tar..."
        rm -f "$gnudip_tar"

        if [ ! -f "$gnudip_tar" ]; then
            echo "Archivo $gnudip_tar eliminado correctamente."
        else
            echo "Error: No se pudo eliminar $gnudip_tar."
        fi
    else
        echo "El archivo $gnudip_tar no existe, no es necesario eliminarlo."
    fi
else
    echo "Error al reiniciar xinetd."
    exit 1
fi


# Crear usuario admin
echo "$admin_user $admin_password" > /opt/gnudip/etc/admin_credentials
echo "Configuración completa. Acceda a https://ns1.$ddns_subdomain/gnudip"
