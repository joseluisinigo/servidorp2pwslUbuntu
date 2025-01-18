# Configuración de Transmission en WSL2 con Script Automatizado

## Descripción

Este script automatiza la configuración de **Transmission** en **WSL2 (Ubuntu)** para compartir archivos mediante el protocolo BitTorrent. Además, permite configurar una regla dinámica de `portproxy` en Windows, asegurando que otros dispositivos en la red puedan acceder al servidor.

El script realiza las siguientes tareas:
1. Solicita datos del usuario (credenciales de Transmission y archivo a compartir).
2. Configura y asegura los permisos para Transmission.
3. Genera el archivo `.torrent` con trackers públicos.
4. Crea reglas necesarias para el funcionamiento en WSL2 y en la red local.
5. Inicia el servicio Transmission y verifica su estado.

---

## Requisitos

- **WSL2 instalado en Windows** (Ubuntu 20.04 o superior recomendado).
- **Permisos de administrador** en WSL2 para ejecutar el script.
- Acceso a Internet para instalar dependencias y actualizar el sistema.
- PowerShell como administrador para configurar la regla de `portproxy` en Windows.

---

## Instalación

1. **Clona el repositorio o descarga el script**:
   ```bash
   git clone https://github.com/usuario/servidorp2p.git
   cd servidorp2p
   ```

2. **Ejecuta el script con permisos de administrador**:
   ```bash
   sudo bash scriptp2p.sh
   ```

3. **Sigue las instrucciones interactivas**:
   - Ingresa las credenciales para Transmission (usuario y contraseña).
   - Proporciona la ruta completa del archivo que deseas compartir.

---

## Configuración Automática

El script realiza los siguientes pasos automáticamente:

1. **Instalación de Transmission**:
   - Descarga y configura `transmission-daemon` y `transmission-cli`.
   
2. **Configuración del archivo `settings.json`**:
   - Define credenciales RPC.
   - Establece el directorio de descargas.
   - Habilita soporte para DHT, PEX y LSD.
   - Configura los puertos necesarios para BitTorrent.

3. **Generación del archivo `.torrent`**:
   - Usa trackers públicos para facilitar la conexión con peers.
   - Guarda el archivo `.torrent` en el directorio del script.

4. **Configuración de permisos**:
   - Ajusta permisos para el servicio `transmission-daemon`.
   - Crea un directorio de descargas y asegura la propiedad.

5. **Reglas de red en Windows**:
   - Sugiere comandos para configurar `netsh portproxy` y abrir el puerto en el firewall.

---

## Ejemplo de Uso

1. **Ejecuta el script**:
   ```bash
   sudo bash scriptp2p.sh
   ```
2. **Accede a la interfaz web de Transmission**:
   - URL: `http://<IP_WSL>:9092`
   - Usuario: El que ingresaste al ejecutar el script.
   - Contraseña: La que ingresaste al ejecutar el script.

3. **Agrega la regla `portproxy` en Windows** (si usas WSL2):
   Ejecuta en PowerShell como administrador:
   ```powershell
   netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=51413 connectaddress=<IP_WSL> connectport=51413
   ```

---

## Resultados

- **Archivo `.torrent` generado**:
  - Ubicación: En el mismo directorio que el script.
  - Trackers configurados: 
    - `udp://tracker.opentrackr.org:1337/announce`
    - `udp://tracker.openbittorrent.com:6969/announce`

- **Interfaz de Transmission**:
  - IP local: Mostrada en la salida del script.
  - Estado: `Seeding` activo.

---

## Solución de Problemas

- **No se puede acceder al servidor desde otros dispositivos**:
  1. Asegúrate de haber configurado la regla `portproxy` en PowerShell.
  2. Verifica que el puerto 51413 esté abierto en el firewall de Windows.

- **Transmission no inicia**:
  - Revisa los permisos del archivo `settings.json`:
    ```bash
    sudo chmod 755 /etc/transmission-daemon/settings.json
    ```

- **No se generan conexiones con peers**:
  - Verifica los trackers configurados en el archivo `.torrent`.
  - Asegúrate de que DHT y PEX están habilitados en `settings.json`.

---

## Créditos

Desarrollado por: **José Luis Íñigo** a.k.a. **Riskoo**  
Basado en la configuración de Transmission para redes locales en entornos WSL2.

---

## Licencia

Este script se distribuye bajo la licencia MIT. Puedes usarlo y modificarlo libremente.
```
