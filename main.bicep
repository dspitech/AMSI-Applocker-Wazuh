// --- PARAMÈTRES ---
param location string = resourceGroup().location
param adminUsername string = 'kaliadmin'

@secure()
param adminPassword string

// --- RÉSEAU ET SÉCURITÉ ---
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-wazuh-pentest'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          description: 'Interface Web Wazuh Dashboard'
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          description: 'Acces HTTP standard'
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'AllowWazuhAgents'
        properties: {
          description: 'Communication Agents (1514-1515)'
          priority: 120
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '1514'
            '1515'
          ]
        }
      }
      {
        name: 'AllowWazuhAPI'
        properties: {
          description: 'Acces API Wazuh'
          priority: 130
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '55000'
        }
      }
      {
        name: 'AllowWazuhIndexer'
        properties: {
          description: 'Acces Wazuh Indexer (Elasticsearch)'
          priority: 140
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '9200'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-wazuh-lab'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-vms'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

// --- IP PUBLIQUE ---
resource publicIpWazuh 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-srv-wazuh'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// --- INTERFACES RÉSEAU ---
resource nicUbuntu 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-srv-wazuh'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.10'
          publicIPAddress: {
            id: publicIpWazuh.id
          }
        }
      }
    ]
  }
}

resource nicWindows 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-win-client'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// --- MACHINES VIRTUELLES ---

resource vmUbuntu 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'srv-wazuh'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: 'srv-wazuh'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicUbuntu.id
        }
      ]
    }
  }
}

resource vmWindows 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'win-client'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    osProfile: {
      computerName: 'win-client'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-10'
        sku: 'win10-22h2-pro-g2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicWindows.id
        }
      ]
    }
  }
}

// --- BASTION ---
resource publicIpBastion 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-bastion'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: 'bastion-wazuh-lab'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: { id: vnet.properties.subnets[1].id }
          publicIPAddress: { id: publicIpBastion.id }
        }
      }
    ]
  }
}
