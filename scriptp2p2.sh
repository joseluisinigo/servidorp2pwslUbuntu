#!/bin/bash

###############################################################################
# Transmission Configuration Script for WSL2
#
# Author: José Luis Íñigo a.k.a. Riskoo
# GitHub: https://github.com/usuario/servidorp2p
# License: MIT
#
# Description:
# This script automates the setup of Transmission in WSL2 (Ubuntu),
# including creating a torrent file, configuring Transmission, and setting
# up a port proxy on Windows for local network access.
#
# Features:
# - Installs and configures Transmission (daemon and CLI)
# - Creates a .torrent file with public trackers
# - Sets up RPC authentication and permissions
# - Guides Windows users to configure portproxy for WSL2
# - Ensures DHT, PEX, and LSD are enabled for optimized peer discovery
#
# Usage:
# 1. Run the script with root privileges: sudo bash scriptp2p.sh
# 2. Follow the interactive prompts to configure Transmission and the torrent
# 3. Access Transmission's Web UI at: http://<WSL_IP>:9092
#
# Requirements:
# - WSL2 with Ubuntu 20.04+ installed
# - Internet access for package installation
# - Administrative privileges in WSL2 and Windows
###############################################################################

###############################################################################
# Script para configurar Transmission en WSL y guiar la creación
# de la regla netsh portproxy en Windows, de forma dinámica.
#
# Pide al usuario:
#   1) RPC_USER   -> Usuario de Transmission
#   2) RPC_PASSWORD -> Contraseña de Transmission
#   3) RUTA_ARCHIVO -> Ruta completa del archivo (se generará .torrent con su mismo base name)
#
# Comentarios en inglés y español dentro del código.
###############################################################################

# ------------- 1) Solicitar datos dinámicos -------------
read -p "Introduce el usuario para Transmission (RPC_USER): " RPC_USER
read -sp "Introduce la contraseña para Transmission (RPC_PASSWORD): " RPC_PASSWORD
echo
read -p "Introduce la ruta completa del archivo para crear el torrent (por ejemplo /home/usuario/UD3_FHW.pdf): " RUTA_ARCHIVO

# ------------- 2) Variables de configuración -------------
RPC_PORT=9092           # RPC/Web port
PEER_PORT=51413         # Peer port (BitTorrent data)
SCRIPT_DIR="$(pwd)"     # Directorio donde resides este script
DOWNLOAD_DIR="$SCRIPT_DIR/download"

# Nombre base del archivo que nos pasan
#   basename -> nombre del fichero con extensión
#   (ej. UD3_FHW.pdf)
NOMBRE_FICHERO="$(basename "$RUTA_ARCHIVO")"  
# Quitar la extensión con ${VAR%.ext} (por ejemplo .pdf, .mp4, etc.)
# Para simplificar, quitaremos la última extensión si existe
NOMBRE_BASE="${NOMBRE_FICHERO%.*}" 

# Torrent se creará en la misma carpeta del script con
# el mismo nombre base y extensión .torrent
TORRENT_OUTPUT="$SCRIPT_DIR/$NOMBRE_BASE.torrent"

# Usuario que usa el servicio de Transmission
TRANSMISSION_USER="debian-transmission"

# ------------- 3) Detectar IP interna de WSL (la primera) -------------
# We'll pick the first IP from `hostname -I` as our main WSL IP
MY_WSL_IP=$(hostname -I | awk '{print $1}')

# ------------- 4) Comprobar si somos root -------------
if [ "$(id -u)" != "0" ]; then
  echo "Por favor, ejecuta este script con sudo: sudo $0"
  exit 1
fi

# ------------- 5) Instalar Transmission (si no está) -------------
apt-get update -y
apt-get install -y transmission-daemon transmission-cli

# ------------- 6) Parar daemon y limpiar configuración -------------
systemctl stop transmission-daemon 2>/dev/null || true
rm -f /var/lib/transmission-daemon/.config/transmission-daemon/settings.json

# ------------- 7) Configurar settings.json -------------
CONFIG_FILE="/etc/transmission-daemon/settings.json"
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak" 2>/dev/null || true

# Establecer parámetros en settings.json
sed -i "s/\"rpc-whitelist\":.*/\"rpc-whitelist\": \"*\",/" "$CONFIG_FILE"
sed -i "s/\"rpc-authentication-required\":.*/\"rpc-authentication-required\": true,/" "$CONFIG_FILE"
sed -i "s/\"rpc-username\":.*/\"rpc-username\": \"$RPC_USER\",/" "$CONFIG_FILE"
sed -i "s/\"rpc-password\":.*/\"rpc-password\": \"$RPC_PASSWORD\",/" "$CONFIG_FILE"
sed -i "s|\"download-dir\":.*|\"download-dir\": \"$DOWNLOAD_DIR\",|" "$CONFIG_FILE"
sed -i "s/\"rpc-port\":.*/\"rpc-port\": $RPC_PORT,/" "$CONFIG_FILE"

# Asegurar DHT, PEX, LSD, port-forwarding
sed -i "s/\"dht-enabled\":.*/\"dht-enabled\": true,/" "$CONFIG_FILE"
sed -i "s/\"pex-enabled\":.*/\"pex-enabled\": true,/" "$CONFIG_FILE"
sed -i "s/\"lpd-enabled\":.*/\"lpd-enabled\": true,/" "$CONFIG_FILE"
sed -i "s/\"port-forwarding-enabled\":.*/\"port-forwarding-enabled\": true,/" "$CONFIG_FILE"

# Puerto de pares
sed -i "s/\"peer-port\":.*/\"peer-port\": $PEER_PORT,/" "$CONFIG_FILE"
sed -i "s/\"peer-port-random-on-start\":.*/\"peer-port-random-on-start\": false,/" "$CONFIG_FILE"

# ------------- 8) Preparar carpetas y permisos -------------
mkdir -p "$DOWNLOAD_DIR"

# Permitir 'traverse' de los directorios
chmod +x /home/$SUDO_USER 2>/dev/null || true
chmod +x "$SCRIPT_DIR" 2>/dev/null || true

# Asegurar propiedad para el usuario de Transmission
chown -R "$TRANSMISSION_USER:$TRANSMISSION_USER" "$SCRIPT_DIR" "$DOWNLOAD_DIR"

# ------------- 9) Copiar la config a /var/lib -------------
mkdir -p /var/lib/transmission-daemon/.config/transmission-daemon
cp "$CONFIG_FILE" /var/lib/transmission-daemon/.config/transmission-daemon/settings.json
chown -R "$TRANSMISSION_USER:$TRANSMISSION_USER" /var/lib/transmission-daemon/.config/transmission-daemon
chmod -R 755 /var/lib/transmission-daemon/.config/transmission-daemon

# ------------- 10) Crear el .torrent (con trackers públicos) -------------
if [ ! -f "$RUTA_ARCHIVO" ]; then
  echo "ERROR: El archivo $RUTA_ARCHIVO no existe. Cancelo."
  exit 1
fi

echo "Creando .torrent en: $TORRENT_OUTPUT"
transmission-create \
  -o "$TORRENT_OUTPUT" \
  -t "udp://tracker.opentrackr.org:1337/announce" \
  -t "udp://tracker.openbittorrent.com:6969/announce" \
  "$RUTA_ARCHIVO"

# ------------- 11) Iniciar Transmission Daemon -------------
systemctl enable transmission-daemon
systemctl start transmission-daemon
sleep 3

# Copiamos el archivo original a la carpeta de descargas
cp "$RUTA_ARCHIVO" "$DOWNLOAD_DIR"/
chown "$TRANSMISSION_USER:$TRANSMISSION_USER" "$DOWNLOAD_DIR/$NOMBRE_FICHERO"
chmod 644 "$DOWNLOAD_DIR/$NOMBRE_FICHERO"

# Añadimos el torrent y forzamos verificación
transmission-remote 127.0.0.1:$RPC_PORT -n $RPC_USER:$RPC_PASSWORD -a "$TORRENT_OUTPUT" 2>/dev/null || true
TORRENT_ID=$(transmission-remote 127.0.0.1:$RPC_PORT -n $RPC_USER:$RPC_PASSWORD -l | grep "$NOMBRE_FICHERO" | awk '{print $1}')
transmission-remote 127.0.0.1:$RPC_PORT -n $RPC_USER:$RPC_PASSWORD -t "$TORRENT_ID" --verify
sleep 3

# ------------- 12) Mostrar info del servidor -------------
echo ""
echo "==========================================================="
echo " Transmission configurado en WSL. IP interna WSL: $MY_WSL_IP"
echo " Puerto de pares (BitTorrent): $PEER_PORT"
echo " WebUI: http://$MY_WSL_IP:$RPC_PORT"
echo "==========================================================="
echo "Archivo Torrent creado: $TORRENT_OUTPUT"
echo "Archivo compartido:     $RUTA_ARCHIVO"
echo "Copia en downloads:     $DOWNLOAD_DIR/$NOMBRE_FICHERO"
echo "==========================================================="
echo "Si estás usando WSL2, para que otro equipo o Windows mismo"
echo "pueda conectar a este seed, debes añadir una regla de 'portproxy' "
echo "y abrir el puerto en el firewall de Windows."
echo ""
echo "1) Abre PowerShell como Administrador y ejecuta:"
echo ""
echo "   netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=$PEER_PORT connectaddress=$MY_WSL_IP connectport=$PEER_PORT"
echo ""
echo "2) Asegúrate de abrir el puerto $PEER_PORT (TCP/UDP) en el firewall"
echo "   de Windows. Por ejemplo, usando Windows Defender Firewall:"
echo "   - Panel de Control -> Sistema y seguridad -> Firewall de Windows"
echo "   - Reglas de entrada -> Nueva regla -> Puerto -> $PEER_PORT (TCP/UDP)."
echo ""
echo "3) Si necesitas confirmar la IP local de Windows, ejecuta ipconfig"
echo "   en PowerShell y busca la IP de tu interfaz que coincida con la"
echo "   subred o la forma en la que te conectas. Suele ser 172.20.x.x en WSL."
echo ""
echo "Una vez hecho eso, Transmission se estará 'Seeding'. Tus clientes"
echo "podrán descargar si usan el archivo .torrent con trackers."
echo "==========================================================="
