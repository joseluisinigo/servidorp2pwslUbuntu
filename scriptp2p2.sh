riskoo@Riskoo:~/practica$ cat scriptp2p.sh 
#!/bin/bash

#######################################################################
# Script para configurar un servidor P2P local con Transmission
# en WSL Ubuntu 22.04. Crea y siembra (seed) un PDF de ejemplo.
#
# Comments in English are included throughout the code.
#######################################################################

# ------------------------- 1) USER VARIABLES -------------------------
RPC_USER="admin"
RPC_PASSWORD="Password1234"
RPC_PORT=9092         # Transmission WebUI port
PEER_PORT=51413       # Peer-to-peer port for seeding
TRACKER_1="udp://tracker.opentrackr.org:1337/announce"
TRACKER_2="udp://tracker.openbittorrent.com:6969/announce"

# Paths in the local WSL environment
SCRIPT_DIR="$(pwd)"
DOWNLOAD_DIR="$SCRIPT_DIR/download"
PDF_FILE_NAME="UD3_FHW.pdf"
PDF_SOURCE_PATH="$SCRIPT_DIR/$PDF_FILE_NAME"
TORRENT_OUTPUT="$SCRIPT_DIR/UD3_FHW.torrent"

# Transmission user
TRANSMISSION_USER="debian-transmission"

# -------------------------- 2) CHECK ROOT ----------------------------
# We want to ensure we're running as root to avoid permission issues.
if [ "$(id -u)" != "0" ]; then
  echo "Por favor, ejecuta este script como root:  sudo $0"
  exit 1
fi

# ---------------------- 3) INSTALL TRANSMISSION ----------------------
echo "Instalando Transmission si no está presente..."
apt-get update -y
apt-get install -y transmission-daemon transmission-cli

# ---------------------- 4) STOP AND CLEAN OLD CONFIG -----------------
echo "Deteniendo transmission-daemon si está en ejecución..."
systemctl stop transmission-daemon 2>/dev/null || true

echo "Borrando configuración anterior (settings.json) si existe..."
rm -f /var/lib/transmission-daemon/.config/transmission-daemon/settings.json

# ------------------------- 5) EDIT SETTINGS --------------------------
CONFIG_FILE="/etc/transmission-daemon/settings.json"
echo "Creando copia de seguridad de $CONFIG_FILE (si existe)..."
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak" 2>/dev/null || true

# Replace or insert needed settings in settings.json
#  - We allow RPC from anywhere
#  - We set RPC user and password
#  - We enable DHT, PEX, LSD, etc.
#  - We set the download directory to $DOWNLOAD_DIR
#  - We set the peer port to $PEER_PORT
#  - We ensure it does not randomize the peer port
echo "Configurando /etc/transmission-daemon/settings.json..."
sed -i "s/\"rpc-whitelist\":.*/\"rpc-whitelist\": \"*\",/" "$CONFIG_FILE"
sed -i "s/\"rpc-authentication-required\":.*/\"rpc-authentication-required\": true,/" "$CONFIG_FILE"
sed -i "s/\"rpc-username\":.*/\"rpc-username\": \"$RPC_USER\",/" "$CONFIG_FILE"
sed -i "s/\"rpc-password\":.*/\"rpc-password\": \"$RPC_PASSWORD\",/" "$CONFIG_FILE"
sed -i "s|\"download-dir\":.*|\"download-dir\": \"$DOWNLOAD_DIR\",|" "$CONFIG_FILE"
sed -i "s/\"rpc-port\":.*/\"rpc-port\": $RPC_PORT,/" "$CONFIG_FILE"

# Make sure DHT, PEX, LSD, port-forwarding are true
sed -i "s/\"dht-enabled\":.*/\"dht-enabled\": true,/" "$CONFIG_FILE"
sed -i "s/\"pex-enabled\":.*/\"pex-enabled\": true,/" "$CONFIG_FILE"
sed -i "s/\"lpd-enabled\":.*/\"lpd-enabled\": true,/" "$CONFIG_FILE"
sed -i "s/\"port-forwarding-enabled\":.*/\"port-forwarding-enabled\": true,/" "$CONFIG_FILE"

# Set peer port
sed -i "s/\"peer-port\":.*/\"peer-port\": $PEER_PORT,/" "$CONFIG_FILE"
sed -i "s/\"peer-port-random-on-start\":.*/\"peer-port-random-on-start\": false,/" "$CONFIG_FILE"

# ---------------------- 6) PREPARE DIRECTORIES -----------------------
echo "Creando el directorio de descargas: $DOWNLOAD_DIR"
mkdir -p "$DOWNLOAD_DIR"

echo "Estableciendo permisos y propiedad..."
# We make sure the Transmission daemon can traverse /home/riskoo and /home/riskoo/practica
chmod +x /home/riskoo || true
chmod +x "$SCRIPT_DIR" || true

# Ensure the "practica" folder is owned by debian-transmission so Transmission can read/write
chown -R "$TRANSMISSION_USER:$TRANSMISSION_USER" "$SCRIPT_DIR" "$DOWNLOAD_DIR"

# PDF must have read permission
chmod 644 "$PDF_SOURCE_PATH" 2>/dev/null || true

# ----------------------- 7) COPY CONFIG TO /var/lib ------------------
# The daemon actually reads from /var/lib/transmission-daemon
mkdir -p /var/lib/transmission-daemon/.config/transmission-daemon
cp "$CONFIG_FILE" /var/lib/transmission-daemon/.config/transmission-daemon/settings.json

# Fix ownership and perms so Transmission can read it
chown -R "$TRANSMISSION_USER:$TRANSMISSION_USER" /var/lib/transmission-daemon/.config/transmission-daemon
chmod -R 755 /var/lib/transmission-daemon/.config/transmission-daemon

# ------------------------ 8) CREATE .TORRENT -------------------------
echo "Creando archivo .torrent con trackers públicos..."
transmission-create \
  -o "$TORRENT_OUTPUT" \
  -t "$TRACKER_1" \
  -t "$TRACKER_2" \
  "$PDF_SOURCE_PATH"

echo "Archivo torrent creado: $TORRENT_OUTPUT"

# ------------------------- 9) START TRANSMISSION ---------------------
echo "Habilitando e iniciando el servicio transmission-daemon..."
systemctl enable transmission-daemon
systemctl start transmission-daemon

sleep 3  # Give the daemon a moment to start

# ------------------- 10) PLACE PDF INSIDE DOWNLOAD DIR ---------------
echo "Copiando el PDF a la carpeta de descargas y ajustando permisos..."
cp "$PDF_SOURCE_PATH" "$DOWNLOAD_DIR"/
chown "$TRANSMISSION_USER:$TRANSMISSION_USER" "$DOWNLOAD_DIR/$PDF_FILE_NAME"
chmod 644 "$DOWNLOAD_DIR/$PDF_FILE_NAME"

# ---------------------- 11) ADD/VERIFY TORRENT -----------------------
# We'll add the torrent to Transmission (if not auto-loaded) and force a verify so it sees 100%.
echo "Añadiendo torrent a Transmission y forzando verificación..."
transmission-remote 127.0.0.1:$RPC_PORT -n $RPC_USER:$RPC_PASSWORD -a "$TORRENT_OUTPUT" 2>/dev/null || true

# Force a verification of data
TORRENT_ID=$(transmission-remote 127.0.0.1:$RPC_PORT -n $RPC_USER:$RPC_PASSWORD -l | grep "$PDF_FILE_NAME" | awk '{print $1}')
transmission-remote 127.0.0.1:$RPC_PORT -n $RPC_USER:$RPC_PASSWORD -t "$TORRENT_ID" --verify

sleep 3  # Wait a bit for verification to finish

# ------------------------ 12) FINAL INFO -----------------------------
IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo ""
echo "======================================================="
echo "  Servidor P2P local configurado correctamente."
echo "======================================================="
echo "Web interface:    http://$IP_ADDRESS:$RPC_PORT"
echo "User / Password:  $RPC_USER / $RPC_PASSWORD"
echo ""
echo "Torrent:          $TORRENT_OUTPUT"
echo "Archivo compartido: $PDF_SOURCE_PATH"
echo "Carpeta descargas: $DOWNLOAD_DIR"
echo ""
echo "Si Transmission muestra 'Seeding', ya eres la semilla."
echo "Agrega el .torrent desde otro PC y comprueba la descarga."
echo "Nota: Abre el puerto $PEER_PORT en el Firewall de Windows."
echo "======================================================="
