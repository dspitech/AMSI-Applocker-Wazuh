# AMSI-WazuhProject

Lab **Wazuh + Windows (Sysmon / AppLocker / PowerShell)** orienté détection, incluant des **règles personnalisées** pour repérer des activités de pentest et des **tentatives de contournement AMSI**.

> Ce projet est un **lab** / POC. Il n’a pas vocation à remplacer un durcissement de production ; adaptez toujours les configurations (réseau, identités, certificats, rétention, volumétrie) à votre contexte.

Ce dépôt contient :

- **Infrastructure Azure** (réseau + VMs + Bastion) via `main.bicep`
- **Installation Wazuh** (Indexer/Manager/Dashboard) via script Linux (`wazuh.sh`) / one-liner (`code`)
- **Onboarding Windows** (agent Wazuh, Sysmon, AppLocker, ScriptBlockLogging) via `agent-wazuh.ps1`
- **Configuration agent Windows** (EventChannels + FIM) via `file-agent.conf`
- **Règles Wazuh custom** (AppLocker, Sysmon, Defender, AMSI) via `rules-local.xml`

---

## Architecture (vue rapide)

![AMSI-WAZUH-APPLOCKER](/architecture.png)

- **VM Ubuntu** (serveur Wazuh “all-in-one”): IP privée statique `10.0.1.10`
- **VM Windows 10** (client) : agent Wazuh + Sysmon + logs PowerShell/AppLocker
- **Azure Bastion** : accès d’administration sans exposer RDP/SSH

Ports déclarés dans le NSG (`main.bicep`) :

- `443` : Wazuh Dashboard (HTTPS)
- `80` : HTTP (si utilisé)
- `1514-1515` : communication agents Wazuh (depuis le Virtual Network)
- `55000` : API Wazuh
- `9200` : Wazuh Indexer (OpenSearch/Elastic API)

---

## Prérequis

### Côté Azure (déploiement infra)

- Un abonnement Azure et **Azure PowerShell** (`Az`) installé
- Droits pour créer : Resource Group, VNet/NSG, Public IP, VMs, Bastion

### Côté VM Ubuntu (serveur Wazuh)

- Ubuntu/Debian
- `sudo` / accès root
- Recommandé: **≥ 4 Go RAM**, **≥ 2 vCPU**, **≥ 30 Go disque**

### Côté VM Windows (agent)

- Windows 10/11
- PowerShell (idéalement PS 5.1+ / PS7)
- Accès admin local (pour Sysmon / services / registre)

---

## Quickstart (chemin le plus court)

- **Déployer l’infra Azure** : exécuter le déploiement Bicep (`main.bicep`) pour obtenir une VM Ubuntu (serveur Wazuh) + une VM Windows (agent) sur le même VNet.
- **Installer Wazuh sur Ubuntu** : utiliser l’installation automatisée (Option A) ou la procédure détaillée (Option B).
- **Onboarder Windows** : exécuter `agent-wazuh.ps1` puis appliquer `file-agent.conf` (EventChannels + FIM).
- **Activer les règles custom** : intégrer `rules-local.xml` côté Manager Wazuh et redémarrer/recharger les règles.
- **Valider** : provoquer un événement Sysmon/AppLocker/PowerShell et vérifier l’alerte dans le Dashboard.

---

## Déploiement Azure (Bicep)

Le fichier `main.bicep` déploie :

- un **NSG** avec règles entrantes,
- un **VNet** avec sous-réseau VMs + `AzureBastionSubnet`,
- une **VM Ubuntu** (`srv-wazuh`) avec IP privée statique `10.0.1.10` + IP publique,
- une **VM Windows** (`win-client`),
- un **Bastion**.

Exemple PowerShell (inspiré de `code`) :

```powershell
# 1) Créer le RG
New-AzResourceGroup -Name "rg-Wazuh-PEN-300" -Location "norwayeast"

# 2) Déployer le template (le mot de passe est demandé en paramètre sécurisé dans main.bicep)
$securePassword = ("ChangeMe-StrongPassword!2026" | ConvertTo-SecureString -AsPlainText -Force) # placeholder
New-AzResourceGroupDeployment -ResourceGroupName "rg-Wazuh-PEN-300" `
  -TemplateFile "./main.bicep" `
  -adminPassword $securePassword
```

### Paramètres à adapter

- **`adminUsername`** dans `main.bicep` (par défaut : `kaliadmin`)
- **`adminPassword`** (paramètre sécurisé)
- La région Azure (`location`)

---

## Installation de Wazuh (serveur Ubuntu)

Deux approches existent dans ce dépôt :

### Option A — Installation automatisée (simple)

La one-liner présente dans `code` télécharge puis exécute l’installateur Wazuh :

```bash
sudo apt update && sudo apt upgrade -y \
  && sudo apt install -y curl apt-transport-https unzip wget libcap2-bin software-properties-common lsb-release gnupg2 \
  && curl -sO https://packages.wazuh.com/4.8/wazuh-install.sh \
  && chmod +x wazuh-install.sh \
  && sudo bash ./wazuh-install.sh -a
```

> Remarque : la version (ici `4.8`) dépend de l’URL utilisée. Ajustez selon vos besoins.

### Option B — Installation “pas à pas” (maîtrisée)

Le guide `wazuh.sh` documente une installation complète (certificats, indexer, filebeat, manager, dashboard) et des validations.

> Note : malgré son extension `.sh`, `wazuh.sh` est principalement un **mémo de commandes**. Lisez-le, adaptez les placeholders (`<WAZUH_INDEXER_IP_ADDRESS>`, etc.) et exécutez-les étape par étape.

---

## Installation et configuration de l’agent Windows

Le script `agent-wazuh.ps1` automatise :

- installation de l’**agent Wazuh**,
- démarrage du service `WazuhSvc`,
- installation de **Sysmon** avec une conf “SwiftOnSecurity”,
- activation/démarrage du service **AppLocker** (`AppIDSvc`),
- activation du **PowerShell Script Block Logging** (utile pour détection AMSI).

### 1) Adapter les paramètres Wazuh Manager

Dans `agent-wazuh.ps1`, vérifiez :

- `WAZUH_MANAGER='10.0.1.10'` (IP du serveur Wazuh)
- `WAZUH_AGENT_GROUP='VMs-Windows'`
- `WAZUH_AGENT_NAME='Windows-10'`

### 2) Exécuter le script

Sur la VM Windows (en admin) :

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\agent-wazuh.ps1
```

### 3) Appliquer la configuration agent (`file-agent.conf`)

Le fichier `file-agent.conf` fournit un bloc `agent_config` pour Windows qui :

- collecte les EventChannels :
  - `Microsoft-Windows-AppLocker/EXE and DLL`
  - `Microsoft-Windows-Sysmon/Operational`
  - `Microsoft-Windows-PowerShell/Operational`
- active **Syscheck/FIM** sur :
  - `C:\Users\*\Downloads`
  - `C:\Windows\Temp`
  - `C:\Windows\System32\drivers\etc`

Selon votre stratégie, vous pouvez :

- l’intégrer à la configuration centrale Wazuh (agent groups),
- ou l’appliquer côté agent (selon votre mode d’administration).

---

## Règles de détection personnalisées (`rules-local.xml`)

Le fichier `rules-local.xml` ajoute un groupe `windows,pentest,custom` avec notamment :

- **AppLocker** : événements et alertes critiques pour exécutions bloquées
- **Sysmon (event1)** : détection d’outils/commandes de pentest (ex : mimikatz, sekurlsa, lsadump, etc.)
- **Microsoft Defender** : détections (ex : EventID 1116/1117)
- **AMSI bypass** : patterns PowerShell (EventID 4104) pour `AmsiScanBuffer`, `amsiInitFailed`, `AmsiUtils` (MITRE `T1562.001`)

### Déploiement côté Wazuh

En pratique, ce fichier est destiné au serveur Wazuh (Manager) dans le mécanisme de règles locales (ex: `rules/local_rules.xml` ou inclusion équivalente selon votre installation). Adaptez le chemin exact selon votre méthode d’installation (Option A vs Option B) puis rechargez/redémarrez le Manager.

---

## Validation (checklist)

- **Services Wazuh** (sur Ubuntu) :
  - `wazuh-indexer`, `wazuh-manager`, `filebeat`, `wazuh-dashboard`
- **Agent Windows** :
  - service `WazuhSvc` démarré
  - `Sysmon64` installé + service OK
  - logs AppLocker et PowerShell opérationnels
- **Connectivité** :
  - la VM Windows rejoint `10.0.1.10` sur `1514/1515`
- **Dashboard** :
  - accès HTTPS au Dashboard (`443`)

---

## Sécurité & bonnes pratiques

- **Ne versionnez pas de secrets** : mots de passe Azure, clés/certificats, tokens.
- **Restreignez les ports** : idéalement, limitez `443/55000/9200` à des IP d’administration (ou via Bastion/VPN).
- **Durcissez les identifiants par défaut** (admin/admin) dès l’installation.
- **Journalisation** : Sysmon + ScriptBlockLogging augmentent la visibilité mais peuvent accroître le volume d’événements.

---

## Dépannage

- **L’agent Windows n’apparaît pas**
  - vérifier `WAZUH_MANAGER` (IP/nom)
  - vérifier NSG + routage VNet (ports `1514/1515`)
  - vérifier que `WazuhSvc` tourne et que l’agent est enregistré

- **Pas d’événements PowerShell/AppLocker**
  - vérifier que `AppIDSvc` est démarré
  - vérifier la stratégie ScriptBlockLogging (registre) et les journaux Windows

- **Dashboard inaccessible**
  - vérifier `wazuh-dashboard` (service) et `443` ouvert
  - vérifier certificats / configuration selon `wazuh.sh`

---

## Contenu du dépôt

- `main.bicep` : déploiement Azure (VNet/NSG/VMs/Bastion)
- `code` : aide-mémoire PowerShell (déploiement + install Wazuh one-liner)
- `wazuh.sh` : procédure d’installation Wazuh détaillée (4.11)
- `agent-wazuh.ps1` : installation agent + Sysmon + prérequis logs Windows
- `file-agent.conf` : configuration agent Windows (EventChannels + FIM)
- `rules-local.xml` : règles Wazuh custom (pentest/AMSI/AppLocker/Defender)

---

## Licence

Non spécifiée pour le moment. Ajoutez un fichier `LICENSE` si vous souhaitez clarifier les conditions d’utilisation.
