@description('Name of the resource.')
param name string
// @description('The DNS name of the API Management service. Must be a valid domain name.')
// param dnsName string
@description('Location to deploy the resource. Defaults to the location of the resource group.')
param location string
param location_secondary string
@description('Tags for the resource.')
param tags object = {}
@description('ID for the Managed Identity associated with the API Management resource.')
param apiManagementIdentityId string
param logAnalyticsWorkspaceId string = ''
param publicIpAddressId string
param publicIpAddressId_secondary string

@allowed([
  'External'
  'Internal'
])
param virtualNetworkType string = 'Internal'

type skuInfo = {
  name: 'Developer' | 'Standard' | 'Premium' | 'Basic' | 'Consumption' | 'Isolated' | 'BasicV2' | 'StandardV2'
  capacity: int
}

param apimSubnetId string
param apimSubnetId_secondary string
// param keyvaultid string

@description('Email address of the owner for the API Management resource.')
@minLength(1)
param publisherEmail string
@description('Name of the owner for the API Management resource.')
@minLength(1)
param publisherName string
@description('API Management SKU. Defaults to Developer, capacity 1.')
param sku skuInfo = {
  name: 'Developer'
  capacity: 1
}

resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: sku
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${apiManagementIdentityId}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: virtualNetworkType
    publicIpAddressId: publicIpAddressId
    // natGatewayState: 'Enabled'
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
    additionalLocations: [
      {
        location: location_secondary
        sku: sku
        publicIpAddressId: publicIpAddressId_secondary
        virtualNetworkConfiguration: {
          subnetResourceId: apimSubnetId_secondary
        }
      }
    ]
    hostnameConfigurations: [
    ]
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_GCM_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'true'
    }
    apiVersionConstraint: {
      minApiVersion: '2021-08-01'
    }
  }
}

resource apiManagementDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceId != '') {
  scope: apiManagement
  name: 'diagnosticSettingsConfig'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

@description('ID for the deployed API Management resource.')
output id string = apiManagement.id
@description('Name for the deployed API Management resource.')
output name string = apiManagement.name
@description('Gateway URL for the deployed API Management resource.')
output gatewayUrl string = apiManagement.properties.gatewayUrl
output portalUrl string = apiManagement.properties.portalUrl
output developerPortalUrl string = apiManagement.properties.developerPortalUrl
output managementApiUrl string = apiManagement.properties.managementApiUrl
output scmUrl string = apiManagement.properties.scmUrl

output primaryLocation string = toLower(replace(apiManagement.location, ' ', ''))
output secondaryLocation string = toLower(replace(apiManagement.properties.additionalLocations[0].location, ' ', ''))
output primaryIpAddress string = apiManagement.properties.privateIPAddresses[0]
output secondaryIpAddress string = apiManagement.properties.additionalLocations[0].privateIPAddresses[0]
output primaryRegionalUrl string = apiManagement.properties.gatewayRegionalUrl
output secondaryRegionalUrl string = apiManagement.properties.additionalLocations[0].gatewayRegionalUrl

output gatewayHostName string = apiManagement.properties.hostnameConfigurations[0].hostName
