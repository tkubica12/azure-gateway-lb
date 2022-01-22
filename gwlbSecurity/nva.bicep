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
        name: 'allowAll'
        properties: {
          description: 'Allow all'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
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
    name: 'Gateway'
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
        properties: {
          tunnelInterfaces: [
            {
              type: 'Internal'
              identifier: 900
              port: 10800
              protocol: 'VXLAN'
            }
            {
              type: 'External'
              identifier: 901
              port: 10801
              protocol: 'VXLAN'
            }
          ]
        }
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


// Configuration script
var script = '''
#!/bin/bash

# Install bridge support
sudo apt update
sudo apt install bridge-utils -y

# Create VXLAN interfaces
sudo ip link add vxlan0 type vxlan id 900 dev eth0 dstport 10800 remote 10.1.0.100
sudo ip link set vxlan0 up
sudo ip link add vxlan1 type vxlan id 901 dev eth0 dstport 10801 remote 10.1.0.100
sudo ip link set vxlan1 up

# Create bridge
sudo brctl addbr br0
sudo brctl addif br0 vxlan0
sudo brctl addif br0 vxlan1
sudo ip link set br0 up
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

output gwlbfrontid string = '${intlb.id}/frontendIPConfigurations/frontend'
