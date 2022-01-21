param subnet string

var location = resourceGroup().location

resource diagstorage 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: uniqueString(resourceGroup().id)
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource appnsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'appnsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allowWeb'
        properties: {
          description: 'Allow web traffic'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource appnic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: 'appnic'
  location: location
  properties: {
    networkSecurityGroup: {
      id: appnsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAddress: '10.0.0.10'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: subnet
          }
          loadBalancerBackendAddressPools: [
            {
              id: applb.properties.backendAddressPools[0].id
            }
          ]
        }
      }
    ]
  }
}

resource applb 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: 'applb'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.0.100'
          subnet: {
            id: subnet
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backend'
      }
    ]
    probes: [
      {
        name: 'probe'
        properties: {
          port: 80
          protocol: 'Http'
          requestPath: '/'
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'web'
        properties: {
          protocol: 'Tcp'
          frontendPort: 80
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'applb', 'frontend')
          }
          backendPort: 80
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'applb', 'backend')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'applb', 'probe')
          }
        }
      }
    ]
  }
}

resource appvm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: 'appvm1'
  location: location
  properties: {
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: diagstorage.properties.primaryEndpoints.blob
      }
    }
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      adminUsername: 'tomas'
      adminPassword: 'Azure12345678'
      computerName: 'appvm1'
      customData: base64('#!/bin/bash\nsudo apt update && sudo apt install nginx -y')
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: appnic.id
        }
      ]
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
  }
}
