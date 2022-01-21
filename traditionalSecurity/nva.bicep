param nvaLbIp string
param subnet string
var location = 'westeurope'

resource diagstorage 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: 'nva${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nvansg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allowRange'
        properties: {
          description: 'Allow web traffic'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1000-2000'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: 'nvanic'
  location: location
  properties: {
    networkSecurityGroup: {
      id: nsg.id
    }
    enableIPForwarding: true
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAddress: '10.1.0.10'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: subnet
          }
          loadBalancerBackendAddressPools: [
            {
              id: extlb.properties.backendAddressPools[0].id
            }
            {
              id: intlb.properties.backendAddressPools[0].id
            }
          ]
        }
      }
    ]
  }
}

// Internal LB
resource intlb 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: 'intlb'
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
          privateIPAddress: nvaLbIp
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
          port: 22
          protocol: 'Tcp'
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'all'
        properties: {
          protocol: 'All'
          frontendPort: 0
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'intlb', 'frontend')
          }
          backendPort: 0
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'intlb', 'backend')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'intlb', 'probe')
          }
        }
      }
    ]
  }
}

// External LB
resource extip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'extip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: 'tomas${uniqueString(resourceGroup().id)}'
    }
  }
}

resource extlb 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: 'extlb'
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
          publicIPAddress: {
            id: extip.id
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
          port: 22
          protocol: 'Tcp'
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
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'extlb', 'frontend')
          }
          backendPort: 1001
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'extlb', 'backend')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'extlb', 'probe')
          }
        }
      }
    ]
  }
}

// Configuration script
var script = '''
#!/bin/bash

# Enable routing
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -p

# Enable outbound SNAT (Internet access for VMs)
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/8 -o eth0 -j MASQUERADE

# Enable service - rewrite destination to app LB IP and rewrite source to self
sudo iptables -t nat -A PREROUTING -p tcp -m tcp --dport 1001 -j DNAT --to-destination 10.0.0.100:80
sudo iptables -t nat -A POSTROUTING -p tcp -d 10.0.0.100 --dport 80 -j MASQUERADE
'''

// NVA VM
resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: 'nva1'
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
      computerName: 'nva'
      customData: base64(script)
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
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
