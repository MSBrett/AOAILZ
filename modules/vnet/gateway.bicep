param deployVpnGateway bool = true
param location string
param gatewayName string
param gatewaySubnetId string
param gatewaySku string
param gatewayType string = 'Vpn'
param vpnType string = 'RouteBased'
param enableBgp bool = false
param gatewayPublicIpId string

resource gateway 'Microsoft.Network/virtualNetworkGateways@2023-11-01' = if (deployVpnGateway) {
  name: gatewayName
  location: location
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubnetId
          }
          publicIPAddress: {
            id: gatewayPublicIpId
          }
        }
        name: 'vnetGatewayConfig'
      }
    ]
    sku: {
      name: gatewaySku
      tier: gatewaySku
    }
    gatewayType: gatewayType
    vpnType: vpnType
    enableBgp: enableBgp
  }
}
