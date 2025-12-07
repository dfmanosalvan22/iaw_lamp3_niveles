# iaw_lamp3_niveles
Desarrollo de la implantacion de una estrucuta LAMP (Linux, Apache, Mysql, PHP) a tres niveles
# Despliegue de WordPress en AWS en Alta Disponibilidad

Este repositorio contiene todo lo necesario para desplegar un CMS **WordPress** en **alta disponibilidad** y **escalable** sobre **AWS**. Incluye los scripts de aprovisionamiento, configuración de infraestructura y personalización de la aplicación.

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
- [Repositorio](#repositorio)

---

## Arquitectura de la Infraestructura

La infraestructura está organizada en **tres capas**:

1. **Capa Pública**
   - Servidor Apache actuando como **balanceador de carga**.
2. **Capa Privada**
   - Dos servidores Apache para backend.
   - Servidor NFS que almacena todos los recursos de WordPress y los exporta a los servidores web.
3. **Capa de Base de Datos (Privada)**
   - Servidor MySQL/MariaDB.

> **Restricciones de conectividad:**
> - Solo se permite acceso externo a la capa pública.
> - No hay conectividad directa entre la capa pública y la capa de base de datos.
> - Se utilizan **grupos de seguridad** y **ACLs** para proteger máquinas y redes.

---

## Infraestructura Detallada

| Capa | Servicio | Nombre de Máquina | Descripción |
|------|---------|-----------------|------------|
| Pública | Apache (Load Balancer) | `Balanceador<NombreAlumno>` | Balancea tráfico HTTP/HTTPS a los servidores de backend |
| Privada | Apache Web Server | `Web1<NombreAlumno>` | Servidor web backend |
| Privada | Apache Web Server | `Web2<NombreAlumno>` | Servidor web backend |
| Privada | NFS | `NFS<NombreAlumno>` | Almacena los recursos de WordPress y los exporta |
| Privada | MySQL/MariaDB | `DB<NombreAlumno>` | Base de datos de WordPress |

---

## Despliegue de Servicios

1. **Capa Pública**  
   - Configuración de Apache como **reverse proxy** y balanceador de carga.
2. **Capa Privada**  
   - Montaje de NFS desde los servidores web.
   - Instalación de Apache y PHP en los servidores backend.
3. **Capa de Base de Datos**  
   - Instalación de MySQL o MariaDB.
   - Configuración de usuarios y base de datos para WordPress.

---

## Aprovisionamiento de Máquinas

Se proporciona un **script de shell (`provision.sh`)** para aprovisionar todas las máquinas:

```bash
#!/bin/bash
# Ejemplo de aprovisionamiento
# Configuración inicial de las máquinas
sudo apt update && sudo apt upgrade -y

# Instalación de Apache
sudo apt install apache2 -y

# Configuración de NFS (solo en el servidor NFS)
sudo apt install nfs-kernel-server -y
# Exportar directorios
echo "/var/www/html *(rw,sync,no_root_squash)" | sudo tee -a /etc/exports
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
