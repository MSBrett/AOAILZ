param onpremGatewayName string
param vpnGatewayName string

@secure()
param connectionProperties object

resource vpnGateway 'Microsoft.Network/vpnGateways@2023-11-01' existing = {
  name: vpnGatewayName
}

resource onpremGatewayVpnConnection 'Microsoft.Network/vpnGateways/vpnConnections@2023-11-01' = {
  name: '${onpremGatewayName}-to-${vpnGatewayName}'
  parent: vpnGateway
  properties: connectionProperties
}
