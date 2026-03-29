#!/bin/bash

# --- 1. Configuration Réseau ---
# Détection de l'interface principale
IFACE=$(ip route | grep default | awk '{print $5}')

# Ajout des IPs pour la DMZ et le LAN
sudo ip addr add 192.168.100.1/24 dev $IFACE
sudo ip addr add 192.168.10.1/24 dev $IFACE

# Activation du forwarding IP (coeur du routage)
sudo sysctl -w net.ipv4.ip_forward=1

# --- 2. Règles Iptables (Sécurité) ---
# Nettoyage des anciennes règles
sudo iptables -F
sudo iptables -X
sudo iptables -P FORWARD DROP

# RÈGLE CRUCIALE : Autoriser le retour du trafic (Stateful)
# C'est ce qui permet au curl de ne plus être "Refused" au retour
sudo iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Autoriser le HTTP (80) vers la VM2 (Web)
sudo iptables -A FORWARD -p tcp --dport 80 -d 192.168.100.10 -j ACCEPT

# Autoriser le LAN (DB) à sortir vers Internet
sudo iptables -A FORWARD -s 192.168.10.0/24 -j ACCEPT

# Bloquer tout accès direct du Web vers le LAN (DB)
sudo iptables -A FORWARD -s 192.168.100.10 -d 192.168.10.0/24 -j DROP

# --- 3. Sauvegarde ---
sudo netfilter-persistent save
echo "Firewall VM1 configuré avec succès !"
