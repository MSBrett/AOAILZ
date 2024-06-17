param rg_virtualnetwork_name string
param forwardingRulesetName string
param virtualNetworkName string

resource fwruleSet 'Microsoft.Network/dnsForwardingRulesets@2022-07-01' existing = {
  name: forwardingRulesetName
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  scope: resourceGroup(rg_virtualnetwork_name)
  name: virtualNetworkName
}

resource resolverLink 'Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2022-07-01' = {
  parent: fwruleSet
  name: virtualNetworkName
  properties: {
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}
