# Installation Complète de Wazuh 4.11

Ce guide détaille l'installation complète de Wazuh 4.11 sur une seule machine.

## 📋 Prérequis
- Système Ubuntu/Debian
- Accès root ou sudo
- Minimum 4GB RAM, 2 cœurs CPU
- 30GB d'espace disque minimum




sudo apt update
sudo apt install -y curl gnupg apt-transport-https debhelper tar libcap2-bin



sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf


## 🔧 1. Génération des Certificats

```bash
# Téléchargement des outils de certificats

curl -sO https://packages.wazuh.com/4.11/wazuh-certs-tool.sh
curl -sO https://packages.wazuh.com/4.11/config.yml


# Configuration des certificats
nano ./config.yml

# Génération des certificats
bash ./wazuh-certs-tool.sh -A

# 📦 2. Préparation du Système

sudo apt-get update
sudo apt-get install gnupg apt-transport-https -y

# Ajout du dépôt avec correction des droits GPG
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor | sudo tee /usr/share/keyrings/wazuh.gpg > /dev/null
sudo chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list

sudo apt-get update









# 🗄️ 3. Installation de Wazuh Indexer
sudo apt-get -y install wazuh-indexer=4.11.2-1

# --- OPTIONAL: RÉGLAGE RAM (Si ta VM a 4GB ou moins) ---
sudo sed -i 's/-Xms4g/-Xms1g/' /etc/wazuh-indexer/jvm.options
sudo sed -i 's/-Xmx4g/-Xmx1g/' /etc/wazuh-indexer/jvm.options

# Déploiement des certificats
sudo mkdir -p /etc/wazuh-indexer/certs
sudo cp ./wazuh-certificates/node-1.pem /etc/wazuh-indexer/certs/indexer.pem
sudo cp ./wazuh-certificates/node-1-key.pem /etc/wazuh-indexer/certs/indexer-key.pem
sudo cp ./wazuh-certificates/admin* /etc/wazuh-indexer/certs/
sudo cp ./wazuh-certificates/root-ca.pem /etc/wazuh-indexer/certs/

# --- CORRECTION PERMISSIONS (ORDRE CRITIQUE) ---
sudo chown -R wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/certs
sudo chmod 400 /etc/wazuh-indexer/certs/*
sudo chmod 500 /etc/wazuh-indexer/certs

# Démarrage
sudo systemctl daemon-reload
sudo systemctl enable wazuh-indexer
sudo systemctl start wazuh-indexer

# Initialisation (Attendre 30s que le service soit UP)
sudo /usr/share/wazuh-indexer/bin/indexer-security-init.sh























# Test de connexion (remplacer <WAZUH_INDEXER_IP_ADDRESS> par l'adresse IP réelle)
curl -k -u admin:admin https://<WAZUH_INDEXER_IP_ADDRESS>:9200





















# 📤 4. Installation de Filebeat
sudo apt-get install filebeat=7.10.2

# Configuration
sudo curl -so /etc/filebeat/filebeat.yml https://packages.wazuh.com/4.11/tpl/wazuh/filebeat/filebeat.yml
nano /etc/filebeat/filebeat.yml

# Keystore
sudo filebeat keystore create
echo admin | sudo filebeat keystore add username --stdin --force
echo admin | sudo filebeat keystore add password --stdin --force

# Module et Certificats
sudo curl -s https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.4.tar.gz | sudo tar -xvz -C /usr/share/filebeat/module
sudo mkdir -p /etc/filebeat/certs
sudo cp ./wazuh-certificates/node-1.pem /etc/filebeat/certs/filebeat.pem
sudo cp ./wazuh-certificates/node-1-key.pem /etc/filebeat/certs/filebeat-key.pem
sudo cp ./wazuh-certificates/root-ca.pem /etc/filebeat/certs/

sudo chmod 400 /etc/filebeat/certs/*
sudo chmod 500 /etc/filebeat/certs
sudo chown -R root:root /etc/filebeat/certs





# 🛡️ 5. Installation de Wazuh Manager

apt-get -y install wazuh-manager=4.11.2-1
# Configuration du keystore Wazuh
echo 'admin' | /var/ossec/bin/wazuh-keystore -f indexer -k username
echo 'admin' | /var/ossec/bin/wazuh-keystore -f indexer -k password

# Configuration du manager
nano /var/ossec/etc/ossec.conf

# Démarrage de Wazuh Manager
systemctl daemon-reload
systemctl enable wazuh-manager
systemctl start wazuh-manager

# Vérification du statut
systemctl status wazuh-manager

# Démarrage de Filebeat
systemctl daemon-reload
systemctl enable filebeat
systemctl start filebeat

# Test de la sortie Filebeat
filebeat test output

# 📊 6. Installation de Wazuh Dashboard

# Installation des dépendances
apt-get install debhelper tar curl libcap2-bin

# Installation du Dashboard
apt-get -y install wazuh-dashboard=4.11.2-1

# Configuration du Dashboard
nano /etc/wazuh-dashboard/opensearch_dashboards.yml

# Certificats
sudo mkdir -p /etc/wazuh-dashboard/certs
sudo cp ./wazuh-certificates/node-1.pem /etc/wazuh-dashboard/certs/dashboard.pem
sudo cp ./wazuh-certificates/node-1-key.pem /etc/wazuh-dashboard/certs/dashboard-key.pem
sudo cp ./wazuh-certificates/root-ca.pem /etc/wazuh-dashboard/certs/

# Permissions
sudo chown -R wazuh-dashboard:wazuh-dashboard /etc/wazuh-dashboard/certs
sudo chmod 400 /etc/wazuh-dashboard/certs/*
sudo chmod 500 /etc/wazuh-dashboard/certs

# Démarrage
sudo systemctl daemon-reload
sudo systemctl enable wazuh-dashboard
sudo systemctl start wazuh-dashboard

# Configuration Wazuh dans Dashboard
nano /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml

# 🌐 7. Accès au Dashboard
URL: https://<WAZUH_DASHBOARD_IP_ADDRESS>
Utilisateur: admin
Mot de passe: admin

⚠️ Remplacez <WAZUH_DASHBOARD_IP_ADDRESS> par l'adresse IP réelle de votre serveur

" ✅ Vérifications Finales

# Vérifier l'état des services
systemctl status wazuh-indexer
systemctl status wazuh-manager
systemctl status filebeat
systemctl status wazuh-dashboard

# Vérifier les logs
journalctl -u wazuh-indexer -f
journalctl -u wazuh-manager -f