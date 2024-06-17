param publicIPAddressName string
param domainNameLabel string
param location string

@allowed([
  'IPv4'
  'IPv6'
])
param publicIPAddressVersion string = 'IPv4'

@allowed([
  'Dynamic'
  'Static'
])
param publicIPAllocationMethod string = 'Static'

@allowed([
  'Basic'
  'Standard'
])
param skuName string = 'Standard'

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: publicIPAddressName
  location: location
  sku: {
    name: skuName
  }
  properties: {
    publicIPAddressVersion: publicIPAddressVersion
    publicIPAllocationMethod: publicIPAllocationMethod
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: domainNameLabel
    }
  }
}

output id string = publicIPAddress.id
