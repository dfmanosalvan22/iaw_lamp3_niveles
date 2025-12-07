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
    ProxyPassReverse / http://10.0.2.228/

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