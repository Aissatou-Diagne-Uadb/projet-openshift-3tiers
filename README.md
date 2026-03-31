# 🚀 Architecture 3-Tiers Virtualisée sur OpenShift

Ce projet démontre la mise en œuvre d'une architecture réseau sécurisée en trois couches (3-Tiers)
utilisant **KubeVirt** et **OpenShift Virtualization**.

Réalisé dans le cadre du module **Virtualisation et Cloud Computing**
Université Alioune DIOP de Bambey — Mars 2026

---

## 🏗️ Structure de l'Architecture
```
Internet
    │
    ▼
[Route OpenShift]        ← Accès public HTTP
    │
    ▼
[VM1 - Firewall]         ← Tier 1 : Filtrage iptables (192.168.100.1)
    │
    ▼
[VM2 - Serveur Web]      ← Tier 2 : Nginx / DMZ (192.168.100.10)
    │
    ▼
[Pod DB - MySQL]         ← Tier 3 : Base de données (mysql-service:3306)
```

L'infrastructure est divisée en trois composants principaux :

### Tier 1 — Firewall (VM1)
- Basé sur **Ubuntu** via KubeVirt
- Configuré avec **iptables** (politique par défaut : DROP)
- Rôle : filtrage du trafic entrant/sortant, routage vers la DMZ
- Journalisation des accès dans Syslog (`FIREWALL_PING`)
- Interdit lui-même d'accéder à la DB (règle OUTPUT DROP)

### Tier 2 — Serveur Web (VM2)
- Basé sur **Ubuntu** via KubeVirt
- Serveur **Nginx** hébergé en zone démilitarisée (DMZ)
- Déploiement automatisé via **Cloud-Init** + script GitHub
- Exposé publiquement via une **Route OpenShift**
- URL publique : `http://web-public-aichared-dev.apps.rm3.7wse.p1.openshiftapps.com`

### Tier 3 — Base de Données (Pod MySQL)
- Instance **MySQL 8.0** déployée dans un Pod Kubernetes
- Stockage persistant via un **PersistentVolumeClaim (PVC)** de 1Gi
- Accessible uniquement via le service DNS interne `mysql-service:3306`
- Isolée par une **NetworkPolicy** stricte

---

## 📁 Structure du Dépôt
```
mon-projet/
├── vms/                          # Définitions des VirtualMachines KubeVirt
│   ├── vm1-firewall.yaml         # VM1 : Firewall / Routeur
│   └── vm2-web.yaml              # VM2 : Serveur Web Nginx
│
├── k8s/                          # Ressources Kubernetes
│   ├── pod-db.yaml               # Pod MySQL + PVC + Service
│   ├── vm2-service.yaml          # Service et Route pour VM2
│   └── network-policy.yaml       # Isolation du Pod MySQL
│
├── scripts/                      # Scripts d'automatisation
│   ├── install-nginx-node.sh     # Installation Nginx sur VM2
│   └── firewall-rules.sh         # Configuration iptables sur VM1
│
└── README.md
```

---

## 🔒 Sécurité et Isolation

### 1. Filtrage iptables — VM1 (Tier 1)

Le Firewall applique une politique **DROP par défaut** sur toute la chaîne FORWARD.
Seuls les flux strictement nécessaires sont autorisés :

| Règle | Direction | Action |
|---|---|---|
| Trafic retour (ESTABLISHED) | FORWARD | ACCEPT |
| HTTP port 80 vers VM2 | FORWARD | ACCEPT |
| VM2 → LAN (DB) | FORWARD | DROP |
| LAN (DB) → Internet | FORWARD | ACCEPT |
| VM1 → port 3306 | OUTPUT | DROP |
| Ping entrant (ICMP) | INPUT | LOG + `FIREWALL_PING` |

> La règle `OUTPUT DROP` sur le port 3306 garantit que même le Firewall
> lui-même ne peut pas accéder aux données sensibles.

### 2. NetworkPolicy — Pod MySQL (Tier 3)

Le fichier `network-policy.yaml` implémente une isolation **Zero Trust** :
- Tout accès entrant vers le Pod MySQL est **bloqué par défaut**
- Seule la **VM2** (label `kubevirt.io/domain: vm2-web`) est autorisée
- Restriction limitée au **port 3306** uniquement
```yaml
ingress:
  - from:
    - podSelector:
        matchLabels:
          kubevirt.io/domain: vm2-web
    ports:
    - protocol: TCP
      port: 3306
```

### 3. Automatisation (Infrastructure as Code)

Le déploiement est entièrement automatisé :
- `install-nginx-node.sh` : installe Nginx sur VM2 et déploie la page web au démarrage
- `firewall-rules.sh` : applique toutes les règles iptables sur VM1 au démarrage
- Les scripts sont appelés via **Cloud-Init** depuis ce dépôt GitHub

---

## 🛠️ Déploiement

### Prérequis
- Accès à un cluster OpenShift (Sandbox Red Hat)
- CLI `oc` installé et configuré
- KubeVirt / OpenShift Virtualization activé

### Étapes
```bash
# 1. Cloner le dépôt
git clone https://github.com/[ton-compte]/projet-openshift-3tiers
cd mon-projet

# 2. Déployer les VirtualMachines
oc apply -f vms/vm1-firewall.yaml
oc apply -f vms/vm2-web.yaml

# 3. Déployer la base de données
oc apply -f k8s/pod-db.yaml

# 4. Créer le service et la route pour VM2
oc apply -f k8s/vm2-service.yaml

# 5. Appliquer la politique de sécurité réseau
oc apply -f k8s/network-policy.yaml

# 6. Vérifier que tout tourne
oc get vms
oc get pods
oc get svc
oc get route
```

---

## ✅ Tests de Validation

### Test 1 — Accès Web depuis l'extérieur
Ouvrir dans un navigateur :
```
http://web-public-aichared-dev.apps.rm3.7wse.p1.openshiftapps.com
```
Résultat attendu : page web avec message de confirmation ✅

### Test 2 — Connexion BD depuis VM2 (autorisée)
```bash
# Depuis le terminal de VM2
curl -v telnet://mysql-service:3306
# Résultat attendu : Connected to mysql-service port 3306 ✅

# Lister les bases de données
mysql -h mysql-service -u root -p"Password2026!" -e "SHOW DATABASES;"
```

### Test 3 — Isolation depuis VM1 (bloquée)
```bash
# Depuis le terminal de VM1
nc -zv mysql-service 3306
# Résultat attendu : Connection timed out ✅ (bloqué par iptables OUTPUT DROP)
```

### Test 4 — Journalisation du Firewall
```bash
# Depuis VM1, surveiller les logs en temps réel
sudo journalctl -kf | grep "FIREWALL_PING"
# Résultat attendu : lignes de log avec SRC, DST, MAC ✅
```

### Tableau récapitulatif

| # | Test | Depuis | Résultat attendu | Statut |
|---|---|---|---|---|
| 1 | Accès web public | Navigateur | HTTP 200 OK | ✅ |
| 2 | Connexion BD | VM2 | Connected | ✅ |
| 3 | Isolation Firewall | VM1 | Timed out | ✅ |
| 4 | Journalisation | VM1 | FIREWALL_PING visible | ✅ |
| 5 | Accès SQL | VM2 | SHOW DATABASES réussi | ✅ |

---

## 🧠 Concepts Clés

| Concept | Définition |
|---|---|
| **iptables FORWARD** | Filtre le trafic qui *traverse* la VM1 |
| **iptables OUTPUT** | Filtre le trafic qui *sort de* la VM1 elle-même |
| **NetworkPolicy** | Pare-feu applicatif Kubernetes basé sur les labels |
| **PVC** | Stockage persistant indépendant du cycle de vie du Pod |
| **Service Kubernetes** | Nom DNS stable pour joindre un Pod même si son IP change |
| **Route OpenShift** | Point d'entrée public vers un Service interne |
| **Cloud-Init** | Automatisation de la configuration au premier démarrage d'une VM |

---

## 👩‍💻 Auteure

**Aïssatou** — Université Alioune DIOP de Bambey
Module : Virtualisation et Cloud Computing — Mars 2026
