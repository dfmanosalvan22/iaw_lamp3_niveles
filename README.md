# Despliegue de WordPress en AWS en Alta Disponibilidad

Este repositorio contiene todo lo necesario para desplegar un CMS **WordPress** en **alta disponibilidad** y **escalable** sobre **AWS**. Incluye scripts de aprovisionamiento, configuración de infraestructura, personalización de la aplicación y habilitación de HTTPS.

---

## Tabla de Contenidos

- [Arquitectura de la Infraestructura](#arquitectura-de-la-infraestructura)  
- [Infraestructura Detallada](#infraestructura-detallada)  
- [Despliegue de Servicios](#despliegue-de-servicios)  
- [Aprovisionamiento de Máquinas](#aprovisionamiento-de-máquinas)  
- [Configuración de WordPress](#configuración-de-wordpress)  
- [Seguridad y Redes](#seguridad-y-redes)  
- [Acceso a la Aplicación](#acceso-a-la-aplicación)  
- [Parte Opcional: Certificado SSL](#parte-opcional-certificado-ssl)  
- [Notas y Tips](#notas-y-tips)  
- [Repositorio](#repositorio)

---

## Arquitectura de la Infraestructura

La infraestructura está organizada en **tres capas**:

1. **Capa Pública**
   - Servidor Apache actuando como **balanceador de carga** (HTTP/HTTPS).  
   - Dirección accesible desde Internet mediante **IP elástica** y dominio propio.

2. **Capa Privada**
   - Dos servidores Apache que funcionan como backend.  
   - Servidor NFS que almacena todos los recursos de WordPress y los exporta a los servidores web.

3. **Capa de Base de Datos (Privada)**
   - Servidor MySQL/MariaDB para almacenar la información de WordPress.

> **Restricciones de conectividad:**
> - Solo la capa pública tiene acceso a Internet.  
> - Los servidores web privados dependen del NFS para los recursos de WordPress.  
> - Seguridad reforzada con **grupos de seguridad** y **ACLs** de AWS.

---

## Infraestructura Detallada

| Capa | Servicio | Nombre de Máquina | Descripción |
|------|---------|-----------------|------------|
| Pública | Apache (Balanceador) | `BALFelipemanBal` | Balancea tráfico HTTP/HTTPS hacia los servidores web privados |
| Privada | Apache Web Server | `WEBFelipemanWeb` | Servidor web backend, monta NFS |
| Privada | Apache Web Server | `WEBFelipemanWeb2` | Servidor web backend, monta NFS |
| Privada | NFS | `NFSFelipemanNFS` | Comparte `/var/nfs` a los servidores web |
| Privada | MySQL/MariaDB | `DBFelipemanDB` | Base de datos de WordPress |

---

## Despliegue de Servicios

### 1. Servidor NFS
- Instalación de NFS y creación de directorio compartido `/var/nfs`.
- Configuración de exportaciones con permisos de lectura/escritura para la subred privada.
- Inicio del servicio y habilitación para arranque automático.

### 2. Servidores Web (Web1 y Web2)
- Instalación de **Apache, PHP y extensiones necesarias** (`php-mysql`, `libapache2-mod-php`).
- Montaje del directorio NFS en `/var/www/html` con permisos apropiados (`www-data:www-data`).
- Configuración de hostname para cada servidor.
- Habilitación y reinicio de Apache.
- Comprobación de PHP y extensiones (`mysqli` y `PDO`) mediante archivo temporal `info.php`.

### 3. Balanceador
- Configuración de Apache como **reverse proxy** con `ProxyPass` y `ProxyPassReverse`.
- VirtualHost con `ServerName` y `ServerAlias` del dominio.
- Activación de módulos `proxy` y `proxy_http`.
- Comprobación de conectividad con los servidores web (`nc -vz IP 80`).

### 4. Base de Datos
- Instalación de MySQL/MariaDB en servidor privado.
- Creación de usuario y base de datos para WordPress.
- Asegurarse que solo los servidores web puedan conectarse al puerto MySQL.

---

## Aprovisionamiento de Máquinas

### Aprovisionamiento Instancia DBFelipemanDB `aprov_db.sh` para el servidor de Base de datos MariaDB de la capa 3:

```bash
#!/bin/bash
set -e

# Cambiar hostname
sudo hostnamectl set-hostname DBFelipemanDB
echo "Hostname cambiado a: DBFelipemanDB"

# Variables de la base de datos
DB_NAME="felipeman"
DB_USER="felipemanu"
DB_PASS="felipemanp"

# Actualizar repositorios e instalar MariaDB
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y mariadb-server

# Asegurarse que MariaDB arranque automáticamente
sudo systemctl enable mariadb
sudo systemctl start mariadb

# Permitir conexiones desde la subred privada
sudo sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.>
sudo systemctl restart mariadb

# Crear la base de datos y usuario
sudo mariadb <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8 COLLATE utf8_ge>
CREATE USER IF NOT EXISTS '${DB_USER}'@'10.0.2.%' IDENTIFIED BY '${DB_PASS}>
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'10.0.2.%';
FLUSH PRIVILEGES;
EOF

echo "Base de datos: ${DB_NAME}, usuario: ${DB_USER} listos"
```


### Aprovisionamiento Instancia NFSFelipemanNFS `aprov_nfs.sh` para el servidor NFS de la capa 2:


```bash
#!/bin/bash
set -e

NOMBRE="FelipemanNFS"
echo "Configurando NFS Server"

# Cambiar hostname
sudo hostnamectl set-hostname "NFS${NOMBRE}"
echo "Hostname cambiado a: $(hostname)"

# Actualizar sistema e instalar NFS
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y nfs-kernel-server

# Crear directorio de exportación
EXPORT_DIR="/var/nfs"
mkdir -p "$EXPORT_DIR"
chown -R nobody:nogroup "$EXPORT_DIR"
chmod 755 "$EXPORT_DIR"

# Configurar exportación solo para subred privada Web
echo "${EXPORT_DIR} 10.0.2.0/24(rw,sync,no_subtree_check,no_root_squash)" > /etc/exports

# Reiniciar servicio NFS
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server

echo "NFS listo"
showmount -e
```

En el servidor NFS luego de haber aprovisionado correctamente los servidores Web, de igual forma el servidor de la Base de datos, Descargamos Wordpress en el NFS con el siguiente script:


``` bash
#!/bin/bash

# Eliminar todo el contenido previo (si existe) en /var/nfs
sudo rm -rf /var/nfs/*

# Descargar la última versión de WordPress
curl -O https://wordpress.org/latest.tar.gz

# Extraer el archivo descargado
sudo tar -xvf latest.tar.gz

# Cambiar al directorio /var/nfs carpeta compartida con los servidores Web
cd /var/nfs

# Copiar los archivos extraídos a la carpeta compartida
sudo cp -r wordpress/* /var/nfs/

# Dar permisos al servidor web (www-data)
sudo chown -R www-data:www-data /var/nfs/

# Entrar al directorio donde está WordPress (NFS)
cd /var/nfs

# Crear archivo wp-config.php desde la plantilla
sudo cp wp-config-sample.php wp-config.php

echo "WordPress ha sido instalado en /var/nfs y configurado correctamente."
echo "Los servidores web pueden acceder al contenido a través del NFS."
```

Luego de ejecutar este script que permite usar Wordpress, entramos al archivo .php que se ha creado y cambiamos las opciones de la BD


``` bash
# Editar el archivo de configuración
sudo nano wp-config.php

# Modificar opciones para acceder a la base de datos
define( 'DB_NAME', 'felipeman' );
define( 'DB_USER', 'felipemanu' );
define( 'DB_PASSWORD', 'felipemanp' );
define( 'DB_HOST', '10.0.3.148' );
```

### Aprovisionamiento Instancias WEBFelipemanWeb `aprov_web.sh` para los servidores WEB de la capa 2. 

Los dos servidores estan aprovisionados por el mismo script cambiando solo una pequeña cosa, la cual es el hostname, que en el caso del segundo servidor es `WEBFelipemanWeb2`:

```bash
#!/bin/bash
set -e

NOMBRE="FelipemanWeb"
NFS_SERVER="10.0.2.30"  # IP servidor NFS
MOUNT_DIR="/var/www/html"

echo "Configurando Servidor Web"

# Cambiar hostname
sudo hostnamectl set-hostname "WEB${NOMBRE}"
echo "Hostname cambiado a: $(hostname)"

# Actualizar sistema e instalar Apache, PHP y utilidades
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y apache2 php libapache2-mod-php nfs-common unzip curl \
    php-mysql php-mysqli php-gd php-xml php-curl php-zip php-mbstring php-soap

# Crear punto de montaje del NFS
sudo mkdir -p "$MOUNT_DIR"

# Montar NFS automáticamente al inicio
echo "${NFS_SERVER}:/var/nfs ${MOUNT_DIR} nfs defaults 0 0" | sudo tee -a /etc/fstab

# Montar NFS ahora mismo
sudo mount -a

# Configurar permisos correctos
sudo chown -R www-data:www-data "$MOUNT_DIR"
sudo chmod -R 755 "$MOUNT_DIR"

# Reiniciar y habilitar Apache
sudo systemctl enable apache2
sudo systemctl restart apache2

echo "Servidor Web listo y NFS montado"
```
### Aprovisionamiento Instancia BALFelipemanBal `aprov_web.sh` para el servidor Balanceador de la capa 1. 

Los dos servidores estan aprovisionados por el mismo script cambiando solo una pequeña cosa, la cual es el hostname, que en el caso del segundo servidor es `WEBFelipemanWeb2`:

```bash
#!/bin/bash
set -e

NOMBRE="FelipemanBal"
DOMINIO="dfmanosalvan.es"

echo "Configurando Balanceador de carga"

# Cambiar hostname
sudo hostnamectl set-hostname "BAL${NOMBRE}"
echo "Hostname cambiado a: $(hostname)"

# Actualizar sistema e instalar Apache y utilidades
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y apache2

# Crear configuración del virtual host
VHOST_CONF="/etc/apache2/sites-available/000-default.conf"

sudo bash -c "cat > $VHOST_CONF" <<EOF
<VirtualHost *:80>
    ServerName ${DOMINIO}
    ServerAlias www.${DOMINIO}

    ProxyPreserveHost On
    ProxyPass / http://10.0.2.228/
    ProxyPassReverse / http://10.0.2.188/

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Habilitar módulos necesarios
sudo a2enmod proxy
sudo a2enmod proxy_http

# Reiniciar y habilitar Apache
sudo systemctl enable apache2
sudo systemctl restart apache2

echo "Balanceador listo y configurado con dominio ${DOMINIO}"
```
