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

output appsubnet string = '${myvnet.id}/subnets/appsubnet'
