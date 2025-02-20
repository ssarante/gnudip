# README para AutoInstallv1.sh

Este script (`AutoInstallv1.sh`) está diseñado para instalar y configurar GnuDIP en un servidor Linux. GnuDIP es un servicio de DNS dinámico que permite gestionar nombres de dominio asociados a direcciones IP cambiantes.

wget https://github.com/ssarante/gnudip/raw/refs/heads/main/AutoInstallv1.sh --no-check-certificate

chmod +x AutoInstallv1.sh

## Requisitos

- **Ejecutar como root:** Asegúrate de tener privilegios de root para realizar todas las configuraciones y cambios necesarios.
- **Sistema operativo:** Este script ha sido probado en sistemas basados en Debian/Ubuntu 22.

## Variables de configuración

El script contiene varias variables de configuración que definen el comportamiento de la instalación:

- `domain="ocsapro"`: Define el dominio principal que se utilizará.
- `ddns_subdomain="ddns.$domain"`: Establece el subdominio para el servicio DNS dinámico.
- `admin_user="admin"`: Nombre de usuario para el administrador de GnuDIP.
- `admin_password="admin"`: Contraseña para el administrador de GnuDIP.
- `mysql_password="root"`: Contraseña para el usuario root de MySQL.
- `file_mysql="/opt/gnudip/doc/gnudip.mysql"`: Ruta del archivo SQL que se usará para crear la base de datos de GnuDIP.
- `file_mysqlupgrade="/opt/gnudip/doc/upgrade.mysql"`: Ruta del archivo SQL de actualización (opcional).
- `config_file="/opt/gnudip/etc/gnudip.conf"`: Archivo de configuración de GnuDIP.
- `apache_conf="/etc/apache2/sites-enabled/default-ssl.conf"`: Archivo de configuración de Apache para el sitio SSL.
- `gdipadmin_script="/opt/gnudip/sbin/gdipadmin.pl"`: Script de administración de GnuDIP.
- `services_file="/etc/services"`: Archivo de servicios donde se registrará el puerto GnuDIP.
- `xinetd_config="/etc/xinetd.d/gnudip"`: Archivo de configuración para xinetd.
- `gnudip_server="/opt/gnudip/sbin/gdipinet.pl"`: Script del servidor GnuDIP.
- `gnudip_tar="gnudip-2.4.tar.gz"`: Nombre del archivo comprimido de GnuDIP.
- `url="https://github.com/ssarante/gnudip/raw/refs/heads/main/gnudip-2.4.tar.gz"`: URL para descargar el archivo de GnuDIP.
- `ip_address=$(hostname -I | awk '{print $1}')`: Obtiene la dirección IP del servidor.

## Instalación y Ejecución

1. **Descargar el script:**
   Asegúrate de tener el script `AutoInstallv1.sh` en tu servidor.

2. **Cambiar permisos de ejecución:**
   ```bash
   chmod +x autoInstall.sh
   
## Configuración de Apache2

Para que GnuDIP funcione correctamente, es necesario configurar Apache2 para manejar las solicitudes HTTPS. A continuación se detallan los pasos para configurar el archivo `default-ssl.conf`.

### Editar el archivo de configuración SSL

1. **Abrir el archivo de configuración:**
   Ejecuta el siguiente comando para editar el archivo `default-ssl.conf`:
   ```bash
   nano /etc/apache2/sites-enabled/default-ssl.conf

   agregar estas lineas
   
------------------
   <VirtualHost _default_:443>
		ServerAdmin webmaster@localhost

		DocumentRoot /var/www/html
		<Directory /opt/gnudip/html/>
   			Options Indexes FollowSymLinks
    			AllowOverride None
    			Require all granted
		</Directory>

	
		<Directory /opt/gnudip/cgi-bin/>
    			Options +ExecCGI
    			AddHandler cgi-script .cgi
    			Require all granted
		</Directory>


----------------

Alias /html /opt/gnudip/html/
Alias /login /opt/gnudip/cgi-bin/gnudip.cgi
<Location /gnudip/html/>
    Options Indexes
    ReadmeName .README
    HeaderName .HEADER
    RemoveHandler .pl
    RemoveType .pl
    AddType text/plain .pl
</Location>


nota importante: si piensan usarla local comentar esta linea {RedirectMatch ^/gnudip(\/*)$ https://ns1.ddns.ocsapro/gnudip/cgi-bin/gnudip.cgi}

## reiniar servicios y dar permisos
sudo chown -R www-data:www-data /opt/gnudip/
sudo chmod -R 755 /opt/gnudip/
sudo a2enmod cgi
sudo systemclt restart apache2
   
## Webpanel
abrir el navegador y acceder 
  https://ip/login - https://127.0.0.1/login
  https://ip/html - https://127.0.0.1/html
  username:admin passsword:admin

  ![imagen](https://github.com/user-attachments/assets/e666aaa4-8fa5-449a-8316-f79d7e7cada0)

   
