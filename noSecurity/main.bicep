targetScope = 'subscription'

var location = 'westeurope'

resource myrg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'no-security-rg'
  location: location
}

module vnets 'vnets.bicep' = {
  scope: myrg
  name: 'vnets'
}

module appWithLb 'appWithLb.bicep' = {
  scope: myrg
  name: 'appWithLb'
  params: {
    subnet: vnets.outputs.appsubnet
  }
}


