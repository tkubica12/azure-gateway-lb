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
          routeTable: {
            id: routeTable.id
          }
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
        }
      }
    ]
  }
}

resource peeringAppNva 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  parent: myvnet
  name: 'peeringAppNva'
  properties: {
    remoteVirtualNetwork: {
      id: secvnet.id
    }
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
  }
}

resource peeringNvaAppa 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  parent: secvnet
  name: 'peeringNvaAppa'
  properties: {
    remoteVirtualNetwork: {
      id: myvnet.id
    }
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
  }
}

resource routeTable 'Microsoft.Network/routeTables@2021-05-01' = {
  name: 'routes'
  location: location
  properties: {
    routes: [
      {
        name: 'viaNva'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: nvaLbIp
        }
      }
    ]
  }
}

output appsubnet string = '${myvnet.id}/subnets/appsubnet'
output nvasubnet string = '${secvnet.id}/subnets/nvasubnet'
