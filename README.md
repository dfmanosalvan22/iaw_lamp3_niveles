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
| Pública | Apache (Balanceador) | `Balanceador<NombreAlumno>` | Balancea tráfico HTTP/HTTPS hacia los servidores web privados |
| Privada | Apache Web Server | `Web1<NombreAlumno>` | Servidor web backend, monta NFS |
| Privada | Apache Web Server | `Web2<NombreAlumno>` | Servidor web backend, monta NFS |
| Privada | NFS | `NFS<NombreAlumno>` | Comparte `/var/nfs` a los servidores web |
| Privada | MySQL/MariaDB | `DB<NombreAlumno>` | Base de datos de WordPress |

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

Ejemplo de script `provision.sh` para servidores web y NFS:

```bash
#!/bin/bash
set -e

# Variables
NOMBRE="FelipemanWeb"
NFS_SERVER="10.0.2.30"   # Servidor NFS
MOUNT_DIR="/var/www/html"

echo "Configurando Servidor Web"

# Cambiar hostname
sudo hostnamectl set-hostname "WEB${NOMBRE}"

# Actualizar sistema e instalar Apache y PHP
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y apache2 php libapache2-mod-php php-mysql nfs-common unzip curl

# Montar NFS
sudo mkdir -p "$MOUNT_DIR"
echo "${NFS_SERVER}:/var/nfs ${MOUNT_DIR} nfs defaults 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# Configurar permisos
sudo chown -R www-data:www-data "$MOUNT_DIR"
sudo chmod -R 755 "$MOUNT_DIR"

# Habilitar y reiniciar Apache
sudo systemctl enable apache2
sudo systemctl restart apache2

echo "Servidor Web listo y NFS montado"

