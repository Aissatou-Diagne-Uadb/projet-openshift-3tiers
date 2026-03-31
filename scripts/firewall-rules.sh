#!/bin/bash

# --- 1. Configuration Réseau ---
IFACE=$(ip route | grep default | awk '{print $5}')

# Ajout des IPs virtuelles pour simuler les segments DMZ et LAN
sudo ip addr add 192.168.100.1/24 dev $IFACE 2>/dev/null
sudo ip addr add 192.168.10.1/24 dev $IFACE 2>/dev/null

# Activation du forwarding IP (indispensable pour que le trafic traverse la VM1)
sudo sysctl -w net.ipv4.ip_forward=1

# --- 2. Règles Iptables (Sécurité) ---
# Nettoyage complet
sudo iptables -F
sudo iptables -X
sudo iptables -Z

# Politique par défaut : On bloque tout ce qui traverse (FORWARD)
sudo iptables -P FORWARD DROP

# --- A. PROTECTION DE LA VM1 ELLE-MÊME (Chaîne OUTPUT) ---
# Empêcher la VM1 d'accéder directement à la DB (Port 3306)
# C'est ce qui fera échouer ton test "nc -zv" sur la VM1
sudo iptables -A OUTPUT -p tcp --dport 3306 -j DROP

# Journalisation du ping pour la démo (Optionnel mais recommandé)
sudo iptables -A INPUT -p icmp -j LOG --log-prefix "FIREWALL_PING: "

# --- B. FLUX TRAVERSANTS (Chaîne FORWARD) ---
# 1. Autoriser le trafic de retour (Stateful)
sudo iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 2. Autoriser le Web (Port 80) vers la VM2 (DMZ)
sudo iptables -A FORWARD -p tcp --dport 80 -d 192.168.100.10 -j ACCEPT

# 3. Bloquer strictement tout accès direct de la VM2 (Web) vers le LAN (DB) via la VM1
# (La sécurité entre VM2 et DB est aussi assurée par la NetworkPolicy OpenShift)
sudo iptables -A FORWARD -s 192.168.100.10 -d 192.168.10.0/24 -j DROP

# 4. Autoriser le LAN (DB) à sortir si besoin (Mises à jour, etc.)
sudo iptables -A FORWARD -s 192.168.10.0/24 -j ACCEPT

# --- 3. Sauvegarde ---
sudo netfilter-persistent save
echo "L'architecture 3-tiers est sécurisée sur VM1 !"
