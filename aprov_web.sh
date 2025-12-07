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
sudo apt install -y apache2 php libapache2-mod-php nfs-common unzip curl

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







