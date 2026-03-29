#!/bin/bash

# --- 1. Installation Minimaliste ---
# On limite les paquets au strict nécessaire pour économiser de l'espace sur le containerDisk
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    nginx \
    nodejs \
    npm \
    curl \
    ca-certificates

# --- 2. Configuration Réseau ---
# Détection dynamique de l'interface
IFACE=$(ip route | grep default | awk '{print $5}')
sudo ip addr add 192.168.100.10/24 dev $IFACE
sudo ip route add 192.168.10.0/24 via 192.168.100.1

# --- 3. Configuration Nginx (Reverse Proxy) ---
cat <<EOF | sudo tee /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

# Redémarrage pour appliquer la config
sudo systemctl restart nginx

# --- 4. Application Node.js ---
cat <<EOF > /home/ubuntu/server.js
const http = require('http');
const server = http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('Felicitation Aissatou ! Serveur Web VM2 operationnel via GitHub\n');
});
server.listen(3000, '127.0.0.1');
EOF

# Lancer l'application Node en arrière-plan proprement
nohup node /home/ubuntu/server.js > /home/ubuntu/app.log 2>&1 &

echo "Serveur Web VM2 (Nginx + Node) configuré avec succès via GitHub !"
