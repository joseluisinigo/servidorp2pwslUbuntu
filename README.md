# servidorp2pwslUbuntu
Servidor p2p montado en ubuntu 22.04 dentro de wsl 
Una vez ya está lanzado el servidor y estoy comenzando a descargar desde utorrent , para que descargue o si no te descarga, tienes que hacer lo siguiente

netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=51413 connectaddress=172.20.182.145 connectport=51413

la ip que aparece es la de wsl ubuntu 22.04 que conecta desde windows, por lo cual debes de poder hacerle ping y que funcione desde powershell o cmd
