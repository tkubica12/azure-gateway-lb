targetScope = 'subscription'

var location = 'westeurope'

resource myrg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'gwlb-security-rg'
  location: location
}

module vnets 'vnets.bicep' = {
  scope: myrg
  name: 'vnets'
  params: {
    nvaLbIp: '10.1.0.100'
  }
}

module appWithLb 'appWithLb.bicep' = {
  scope: myrg
  name: 'appWithLb'
  dependsOn: [
    nva
  ]
  params: {
    subnet: vnets.outputs.appsubnet
    gwlbfrontid: nva.outputs.gwlbfrontid
  }
}

module nva 'nva.bicep' = {
  scope: myrg
  name: 'nva'
  params: {
    nvaLbIp: '10.1.0.100'
    subnet: vnets.outputs.nvasubnet
  }
}


