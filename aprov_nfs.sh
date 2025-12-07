#!/bin/bash
set -e

NOMBRE="FelipemanNFS"
echo "Configurando NFS Server"

# Cambiar hostname
hostnamectl set-hostname "NFS${NOMBRE}"
echo "Hostname cambiado a: $(hostname)"

# Actualizar sistema e instalar NFS
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y nfs-kernel-server

# Crear directorio de exportación
EXPORT_DIR="/var/nfs"
mkdir -p "$EXPORT_DIR"
chown -R nobody:nogroup "$EXPORT_DIR"
chmod 0 "$EXPORT_DIR"

# Configurar exportación solo para subred privada Web
echo "${EXPORT_DIR} 10.0.2.0/24(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports

# Reiniciar servicio NFS
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server

echo "NFS listo"
showmount -e
