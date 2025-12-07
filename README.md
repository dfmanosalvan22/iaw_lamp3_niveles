# LAMP 3 Niveles WordPress

## Introducción

El objetivo de esta actividad es desplegar un **sitio WordPress funcional** en un entorno de **alta disponibilidad** utilizando servicios de **AWS** y tecnologías asociadas como **NFS, Apache, PHP y MariaDB**.  

Se busca que la infraestructura sea **escalable, segura y redundante**, permitiendo que múltiples servidores web compartan los mismos archivos de WordPress mediante NFS y que el tráfico sea balanceado correctamente mediante un servidor público.  

Esta práctica permite aprender y demostrar conceptos clave de infraestructura web moderna:

- **Separación de capas:** pública (balanceador), aplicación (servidores web) y base de datos (privada).  
- **Alta disponibilidad:** balanceo de carga y redundancia de servidores web.  
- **Almacenamiento compartido:** uso de NFS para centralizar recursos de WordPress (temas, plugins, uploads).  
- **Seguridad y aislamiento:** subredes privadas, control de accesos y limitación de conectividad a la base de datos.  
- **Automatización:** scripts de aprovisionamiento para desplegar y configurar rápidamente cada servidor.  

Al finalizar, se obtiene un **entorno de WordPress completamente funcional** que puede soportar múltiples servidores web, con la capacidad de escalar y mantener consistencia en los datos y archivos compartidos.

---

## Tabla de Contenidos

- [Arquitectura de la Infraestructura](#arquitectura-de-la-infraestructura)  
- [Infraestructura Detallada](#infraestructura-detallada)
- [Tipología de Red](#tipología-de-red)  
- [Despliegue de Servicios](#despliegue-de-servicios)  
- [Aprovisionamiento de Máquinas](#aprovisionamiento-de-máquinas)  
- [Configuración de WordPress](#configuración-de-wordpress)  
- [Seguridad y Redes](#seguridad-y-redes)  
- [Acceso a la Aplicación](#acceso-a-la-aplicación)  
- [Certificado SSL](#certificado-ssl)  
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
> - Seguridad reforzada con **grupos de seguridad** y **ACLs (Predeterminada)** de AWS.

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

## Tipología de Red

La infraestructura se organizó en **tres capas**, cada una con subredes y direcciones IP específicas para garantizar seguridad, aislamiento y comunicación controlada:

### Capa 1: Pública (Balanceador)
- **Subred:** Subred pública (ej: 10.0.1.0/24)  
- **Servidor:** BALFelipemanBal  
- **IP Pública:** IP elástica asignada  
- **Función:** Recibe tráfico desde Internet y lo distribuye a los servidores web privados.  
- **Acceso:** Permite solo HTTP/HTTPS desde Internet.

### Capa 2: Privada (Servidores Web y NFS)
- **Subred:** Subred privada (ej: 10.0.2.0/24)  
- **Servidores Web:** WEBFelipemanWeb (10.0.2.188) y WEBFelipemanWeb2 (10.0.2.228)  
- **Servidor NFS:** NFSFelipemanNFS (10.0.2.30)  
- **Función:**  
  - Servidores Web ejecutan WordPress y montan el NFS para acceder a los archivos.  
  - Servidor NFS centraliza los archivos de WordPress compartidos con los servidores web.  
- **Acceso:** Solo permitido desde los servidores web y el balanceador según necesidad.

### Capa 3: Base de Datos (Privada)
- **Subred:** Subred privada (ej: 10.0.3.0/24)  
- **Servidor:** DBFelipemanDB (10.0.3.148)  
- **Función:** Almacena toda la información de WordPress (usuarios, posts, configuraciones).  
- **Acceso:** Solo permitido desde los servidores web de la capa 2.

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

Cada script de aprovisionamiento (`aprov_db.sh`, `aprov_nfs.sh`, `aprov_web.sh`, `aprov_balanceador.sh`) está diseñado para:

1. Configurar el hostname y la identidad de cada servidor.
2. Instalar los paquetes necesarios (Apache, PHP, MariaDB, NFS).
3. Configurar servicios críticos como la base de datos, el NFS y Apache.
4. Aplicar permisos y montar recursos compartidos (por ejemplo NFS en los servidores web).
5. Habilitar los servicios para que se inicien automáticamente al reinicio.

> Esta separación modular permite reproducir la infraestructura en múltiples entornos sin depender de un único script monolítico.

### Servidor de Base de Datos

Servidor de base de datos de la capa privada. Aloja la base de datos de WordPress y gestiona toda la información de usuarios, contenidos y configuraciones. Está configurado para aceptar conexiones únicamente desde los servidores web privados, garantizando **seguridad y aislamiento** de los datos.


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
sudo sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf
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

### Servidor NFS

Servidor NFS de la capa privada. Este servidor centraliza todos los archivos de WordPress y los comparte con los servidores web mediante el directorio `/var/nfs`. Garantiza que ambos servidores web tengan acceso a los mismos temas, plugins y contenidos subidos por los usuarios, facilitando la **consistencia y el escalado horizontal**.


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

### Servidores WEB

Servidores web de la capa privada. Estos servidores alojan la aplicación WordPress y montan el directorio compartido del servidor NFS (`/var/nfs`) para acceder a los archivos de la aplicación. Ambos servidores permiten **alta disponibilidad y escalabilidad**, ya que si uno falla, el otro puede continuar atendiendo las solicitudes a través del balanceador de carga. Además, están configurados con Apache y PHP para ejecutar WordPress de manera óptima.

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

### Balanceador de Carga

El balanceador distribuye el tráfico entre los servidores web privados.  
Usamos Apache como reverse proxy, activando los módulos `proxy` y `proxy_http`.  
Esto garantiza:
- Alta disponibilidad: si un servidor web falla, el otro sigue atendiendo.
- Escalabilidad: se pueden agregar más servidores web fácilmente.
- Transparencia: el usuario final no nota que hay múltiples servidores detrás.

Para el servidor balanceador de la capa 1. Este servidor es el único con acceso a Internet, ya que cuenta con una **tabla de enrutamiento pública** y una **IP elástica**, lo que le permite recibir tráfico externo y distribuirlo hacia los servidores web privados. 

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

    ProxyPass / http://10.0.2.188/
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

## Configuración de WordPress

### Uso de NFS

En esta arquitectura, los archivos de WordPress se almacenan en `/var/nfs` del servidor NFS y se comparten con ambos servidores web. En el servidor NFS luego de haber aprovisionado correctamente los servidores Web, de igual forma el servidor de la Base de datos, Descargamos Wordpress.  

Esto permite:
- Que ambos servidores web tengan acceso a los mismos archivos, evitando duplicación.
- Centralizar subidas, temas y plugins.
- Facilitar el escalado horizontal de servidores web.

> Nota: Aunque el directorio `/var/www/html` es el estándar en servidores web, en esta implementación usamos `/var/nfs` por ser la carpeta compartida en NFS.

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

## Seguridad y Redes

La infraestructura se diseñó para ser segura y estar correctamente aislada:

- **Subredes privadas y públicas:**  
  - Los servidores web y NFS están en subredes privadas.  
  - El balanceador se encuentra en la subred pública, recibiendo tráfico externo y con una IP elastica.  

- **Grupos de seguridad (Security Groups):**  
  - Balanceador: permite tráfico HTTP/HTTPS desde Internet y SSH mediante una key, que permite conectarnos a la instancia.  
  - Servidores Web: solo permiten tráfico desde el balanceador, NFS y SSH mediante una key, que permite conectarnos a la instancia..  
  - NFS: permite tráfico NFS desde los servidores web y SSH mediante una key, que permite conectarnos a la instancia..  
  - Base de datos: permite tráfico MySQL únicamente desde los servidores web y SSH mediante una key, que permite conectarnos a la instancia..  

- **Firewall interno y reglas de acceso:**  
  - Restricción de puertos no necesarios.  
  - Control de acceso basado en IP y subred.  

Esta configuración garantiza aislamiento, minimiza exposición a Internet y protege los datos sensibles.

## Acceso a la Aplicación

Para acceder al sitio WordPress:

1. Usar el **dominio configurado** en el balanceador (ejemplo: `https://dfmanosalvan.es`).  
2. Desde la red privada, los servidores web pueden acceder al contenido compartido en NFS (`/var/nfs`).  
3. El panel de administración de WordPress se encuentra en `https://dfmanosalvan.es/wp-admin`.  
4. Validar que el balanceador distribuye correctamente el tráfico entre los servidores web con herramientas como `curl` o navegadores.

## Certificado SSL

Para habilitar HTTPS en el balanceador de carga se utilizó **Certbot**, que automatiza la obtención de certificados SSL de **Let's Encrypt** y su configuración en Apache.  

El procedimiento realizado fue el siguiente:

1. **Actualizar repositorios e instalar Certbot con el plugin de Apache:**
   ```bash
   sudo apt update
   sudo apt install -y certbot python3-certbot-apache

2. **Generar e instalar el certificado para el dominio y su alias:**
   ``` bash
   sudo certbot --apache -d dfmanosalvan.es -d www.dfmanosalvan.es
   ```

   - Durante la ejecución se ingresó un correo electrónico para           notificaciones de certificados.

   - Se aceptaron los términos de servicio de Let's Encrypt.

   - Certbot configuró automáticamente Apache para habilitar HTTPS y redireccionar HTTP a HTTPS.
  
3. **Verificar que funciona:**

   - https://dfmanosalvan.es
   - https://www.dfmanosalvan.es
  
## Conclusión

Esta práctica permitió desplegar un **entorno de WordPress altamente disponible y escalable** sobre AWS, aplicando conceptos fundamentales de arquitectura de aplicaciones:

- **Separación de capas:** Cada capa (pública, aplicación, base de datos) está aislada y tiene responsabilidades definidas.  
- **Alta disponibilidad:** Gracias al balanceador y a los servidores web redundantes, el sitio puede continuar funcionando si un servidor falla.  
- **Almacenamiento compartido con NFS:** Permite que varios servidores web accedan a los mismos archivos de WordPress, facilitando escalabilidad y consistencia.  
- **Seguridad y control de acceso:** Uso de subredes privadas, grupos de seguridad y control de puertos para minimizar la exposición a Internet.  
- **Automatización:** Los scripts de aprovisionamiento permiten reproducir la infraestructura de manera rápida y confiable.

Se logró un entorno funcional de WordPress que combina **rendimiento, disponibilidad y seguridad**, siguiendo buenas prácticas de despliegue en la nube.

## Repositorio

Este repositorio contiene:

- Scripts de aprovisionamiento para cada servidor (`aprov_db.sh`, `aprov_nfs.sh`, `aprov_web.sh`, `aprov_balanceador.sh`).  
- Archivos de configuración de Apache y WordPress (`wp-config.php`, VirtualHosts).  
- Documentación de la arquitectura y guías de despliegue (este README).  

> Todos los scripts están listos para ejecutarse en un entorno AWS y reproducir la infraestructura descrita.

## Comprobación

Para verificar que la infraestructura funciona correctamente, realizamos las siguientes pruebas:

1. Acceso al sitio WordPress a través del balanceador:
   - https://dfmanosalvan.es
   - https://www.dfmanosalvan.es

2. Ejemplo de resultado en el navegador. Validación del candado en el navegador indicando HTTPS activo:

![Pantallazo de WordPress funcionando](comprobacion_aws.png)

3. Video de comprobación

Puedes ver un video de la demostración del sitio WordPress funcionando:

https://youtu.be/3sG4zQg_tbI








