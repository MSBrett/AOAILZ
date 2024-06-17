param onpremGatewayName string
param location string = resourceGroup().location
param onpremAddressPrefixes array
param onpremGatewayIpAddress string

resource onpremGateway 'Microsoft.Network/localNetworkGateways@2023-11-01' = {
  name: onpremGatewayName
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: onpremAddressPrefixes
    }
    gatewayIpAddress: onpremGatewayIpAddress
  }
}

output onpremGatewayName string = onpremGateway.name
output onpremGatewayId string = onpremGateway.id
output onpremGatewayIpAddress string = onpremGateway.properties.gatewayIpAddress
output onpremGatewayAddressPrefixes array = onpremGateway.properties.localNetworkAddressSpace.addressPrefixes
