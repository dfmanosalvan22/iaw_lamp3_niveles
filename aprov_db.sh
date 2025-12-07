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
