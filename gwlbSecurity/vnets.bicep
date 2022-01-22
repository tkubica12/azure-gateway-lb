param nvaLbIp string

var location = resourceGroup().location

resource myvnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'myvnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'appsubnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

resource secvnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'secvnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'nvasubnet'
        properties: {
          addressPrefix: '10.1.0.0/24'
          natGateway: {
            id: natgw.id
          }
        }
      }
    ]
  }
}

resource natip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'natip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource natgw 'Microsoft.Network/natGateways@2021-05-01' = {
  name: 'natgw'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: natip.id
      }
    ]
  }
}

output appsubnet string = '${myvnet.id}/subnets/appsubnet'
output nvasubnet string = '${secvnet.id}/subnets/nvasubnet'
