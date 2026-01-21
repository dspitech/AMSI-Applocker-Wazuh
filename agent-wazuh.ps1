# # Installation de l'agent Wazuh
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.8.2-1.msi -OutFile ${env.tmp}\wazuh-agent; msiexec.exe /i ${env.tmp}\wazuh-agent /q WAZUH_MANAGER='10.0.1.10' WAZUH_AGENT_GROUP='VMs-Windows' WAZUH_AGENT_NAME='Windows-10' 

# Démarrage du service Wazuh
NET START WazuhSvc


# Voici le script PowerShell pour automatiser l'installation de Sysmon sur votre VM Windows via Azure. Sysmon est indispensable pour alimenter la configuration Wazuh que nous venons de mettre en place
# Création du dossier de travail
New-Item -Path "C:\Tools" -ItemType Directory -Force
Set-Location "C:\Tools"

# Téléchargement de Sysmon
Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "Sysmon.zip"
Expand-Archive -Path "Sysmon.zip" -DestinationPath "C:\Tools\Sysmon" -Force

# Téléchargement d'une configuration optimisée (SwiftOnSecurity)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile "sysmonconfig.xml"

# Installation de Sysmon
Start-Process -FilePath "C:\Tools\Sysmon\Sysmon64.exe" -ArgumentList "-i sysmonconfig.xml -accepteula" -Wait

# Vérification du service
Get-Service "Sysmon64"


# Démarre le service requis pour AppLocker
Set-Service -Name "AppIDSvc" -StartupType Automatic
Start-Service "AppIDSvc"











# Active le log des blocs de scripts PowerShell (requis pour AMSI detection)
$registryPath = "HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
if (!(Test-Path $registryPath)) { New-Item -Path $registryPath -Force }
Set-ItemProperty -Path $registryPath -Name "EnableScriptBlockLogging" -Value 1