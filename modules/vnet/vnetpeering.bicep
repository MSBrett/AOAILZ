param virtualNetworkName1 string
param virtualNetworkName2 string
param virtualNetworkRgName2 string

resource virtualNetwork1 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: virtualNetworkName1
}

resource virtualNetworkRg2 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: virtualNetworkRgName2
  scope: subscription()
}

resource virtualNetwork2 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: virtualNetworkName2
  scope: virtualNetworkRg2
}

resource peering1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  name: '${virtualNetwork1.name}-to-${virtualNetwork2.name}'
  parent: virtualNetwork1
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: virtualNetwork2.id
    }
  }
}
