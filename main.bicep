targetScope = 'subscription'

@minLength(1)
@description('Required. To uniquely name everything.')
param workloadName string = 'msbsandbox'

param notificationEmail string = ''

@minLength(1)
@description('Required. Primary location for all resources.')
param location_hub string = 'westus'
param location_sandbox string = 'westus'
param location_ai_primary string = 'westus'
param location_ai_secondary string = 'eastus'

@description('Address space for the workload.  A /23 is required for the workload.')
param virtualNetworkAddressPrefix string = '10.8.0.0/22'

param onpremDomainName string = 'op.brettwil.com.'
param onpremDnsServers array = [
  {
    ipaddress: '192.168.1.2'
    port: 53
  }
  {
    ipaddress: '192.168.1.1'
    port: 53
  }
]

param availabilityZones array = []
param vmSize string = 'Standard_D2s_v4'
param vmStorageAccountType string = 'Standard_LRS'
param windowsVmImageReference object = {
  publisher: 'microsoftwindowsdesktop'
  offer: 'windows-11'
  sku: 'win11-23h2-ent'
  version: 'latest'
}
param linuxVmImageReference object = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-focal'
  sku: '20_04-lts-gen2'
  version: 'latest'
}

param adminUsername string
@secure()
param adminPassword string

param logAnalyticsWorkspaceId string

@description('Path to putlish the api to. Default is /workloadName/v1.')
param apiPathSuffix string = '/api/v1/openai'

var abbrs = loadJsonContent('./abbreviations.json')
//var roles = loadJsonContent('./roles.json')
var safeWorkloadName = replace(replace(replace('${workloadName}', '-', ''), '_', ''), ' ', '')
var safeOnpremDomainName = replace(replace(replace(replace('${onpremDomainName}', '-', ''), '_', ''), ' ', ''), '.', '')
var resourceTokenPrimary = toLower(uniqueString(subscription().id, rgName_ai_primary, location_ai_primary))
var resourceTokenSecondary = toLower(uniqueString(subscription().id, rgName_ai_secondary, location_ai_secondary))

param fwnetworkRuleCollections array = [
  {
    name: 'DefaultRule'
    properties: {
      priority: 200
      action: {
        type: 'Allow'
      }
      rules: [
        {
          name: 'Any'
          protocols: [
            'Any'
          ]
          sourceAddresses: [
            '10.0.0.0/8'
            '192.168.0.0/16'
          ]
          destinationAddresses: [
            '*'
          ]
          destinationPorts: [
            '*'
          ]
        }
      ]
    }
  }
]

param fwapplicationRuleCollections array = [
  {
    name: 'www'
    properties: {
      priority: 101
      action: {
        type: 'Allow'
      }
      rules: [
        {
          name: 'www'
          protocols: [
            {
              port: 80
              protocolType: 'Http'
            }
            {
              port: 443
              protocolType: 'Https'
            }
            {
              port: 1443
              protocolType: 'mssql'
            }
          ]
          targetFqdns: [
            '*'
          ]
          sourceAddresses: [
            '10.0.0.0/8'
            '192.168.0.0/16'
          ]
        }
      ]
    }
  }
]

// HUB
var rgName_hub = '${safeWorkloadName}-${location_hub}-hub'
//var resourceToken_hub = toLower(uniqueString(subscription().id, rgName_hub))
var hubVnetName = '${abbrs.virtualNetwork}hub-${location_hub}'
//var hubDefaultNsgName = '${hubVnetName}-nsg'
var hubBastionNsgName = '${hubVnetName}-${abbrs.bastion}nsg'
var hubVnetAddressPrefix = cidrSubnet(virtualNetworkAddressPrefix, 24, 0)
var hubVnetGatewayName = '${abbrs.virtualNetworkGateway}${location_hub}'
var hubVnetGatewayPipName = '${abbrs.virtualNetworkGateway}${location_hub}-pip'
var hubFirewallName = '${abbrs.firewall}${location_hub}'
var hubFirewallPipName = '${abbrs.firewall}${location_hub}-${abbrs.publicIPAddress}data'
var hubFirewallMgmtPipName = '${abbrs.firewall}${location_hub}-${abbrs.publicIPAddress}mgmt'
var hubSubnets = [
  {
    name: 'GatewaySubnet'
    properties: {
      addressPrefix: cidrSubnet(hubVnetAddressPrefix, 26, 0)
      routeTable: {
        id: return_route_table.outputs.routetableID
      }
    }
  }
  {
    name: 'AzureFirewallSubnet'
    properties: {
      addressPrefix: cidrSubnet(hubVnetAddressPrefix, 26, 1)
    }
  }
  {
    name: 'AzureFirewallManagementSubnet'
    properties: {
      addressPrefix: cidrSubnet(hubVnetAddressPrefix, 26, 2)
    }
  }
  {
    name: 'AzureBastionSubnet'
    properties: {
      addressPrefix: cidrSubnet(hubVnetAddressPrefix, 26, 3)
      networkSecurityGroup: {
        id: hubBastionNsg.outputs.id
      }
    }
  }
]

// DNS Resolver
var dnsResolverName = 'dns-${location_hub}'
var dnsResolverVnetName = '${abbrs.virtualNetwork}dns-${location_hub}'
var dnsResolverDefaultNsgName = '${dnsResolverVnetName}-nsg'
var dnsResolverVnetAddressPrefix = cidrSubnet(virtualNetworkAddressPrefix, 27, 8)
var inboundSubnetName = 'inbound'
var outboundSubnetName = 'outbound'
var dnsResolverVnetSubnets = [
  {
    name: inboundSubnetName
    properties: {
      addressPrefix: cidrSubnet(dnsResolverVnetAddressPrefix, 28, 0)
      delegations: [
        {
          name: 'Microsoft.Network.dnsResolvers'
          properties: {
            serviceName: 'Microsoft.Network/dnsResolvers'
          }
        }
      ]
      routeTable: {
        id: default_route_table_dns.outputs.routetableID
      }
      networkSecurityGroup: {
        id: dnsResolverDefaultNsg.outputs.id
      }
    }
  }
  {
    name: outboundSubnetName
    properties: {
      addressPrefix: cidrSubnet(dnsResolverVnetAddressPrefix, 28, 1)
      delegations: [
        {
          name: 'Microsoft.Network.dnsResolvers'
          properties: {
            serviceName: 'Microsoft.Network/dnsResolvers'
          }
        }
      ]
      routeTable: {
        id: default_route_table_dns.outputs.routetableID
      }
      networkSecurityGroup: {
        id: dnsResolverDefaultNsg.outputs.id
      }
    }
  }
]

// VM Sandbox
var rgName_sandbox = '${safeWorkloadName}-${location_hub}-compute'
var vmNameWindows = 'windowsvm'
var vmNameLinux = 'linuxvm'
var sandboxVnetName = '${abbrs.virtualNetwork}sandbox-${location_hub}'
var sandboxDefaultNsgName = '${sandboxVnetName}-nsg'
var sandboxVnetAddressPrefix = cidrSubnet(virtualNetworkAddressPrefix, 27, 9)
var sandboxVnetSubnets = [
  {
    name: 'compute'
    properties: {
      addressPrefix: sandboxVnetAddressPrefix
      routeTable: {
        id: default_route_table_sandbox.outputs.routetableID
      }
      networkSecurityGroup: {
        id: sandboxDefaultNsg.outputs.id
      }
    }
  }
]

// AI Workloads
var rgName_ai_primary = '${safeWorkloadName}-${location_ai_primary}-ai'
var rgName_ai_secondary = '${safeWorkloadName}-${location_ai_secondary}-ai'
var apimName = '${safeWorkloadName}${resourceTokenPrimary}'
var aiName_primary = '${safeWorkloadName}-${location_ai_primary}-ai'
var aiName_secondary = '${safeWorkloadName}-${location_ai_secondary}-ai'
var aiPrimaryVnetName = '${abbrs.virtualNetwork}ai-${location_ai_primary}'
var aiSecondaryVnetName = '${abbrs.virtualNetwork}ai-${location_ai_secondary}'
var aiPrimaryVnetAddressPrefix = cidrSubnet(virtualNetworkAddressPrefix, 27, 10)
var aiSecondaryVnetAddressPrefix = cidrSubnet(virtualNetworkAddressPrefix, 27, 11)
var aiPrimaryVnetSubnets = [
  {
    name: 'ApiManagement'
    properties: {
      addressPrefix: cidrSubnet(aiPrimaryVnetAddressPrefix, 28, 0)
      networkSecurityGroup: {
        id: apimPrimaryNsg.outputs.id
      }
      serviceEndpoints: [
        {
          service: 'Microsoft.Storage'
        }
        {
          service: 'Microsoft.Sql'
        }
        {
          service: 'Microsoft.EventHub'
        }
        {
          service: 'Microsoft.KeyVault'
        }
        {
          service: 'Microsoft.ServiceBus'
        }
      ]
      routeTable: {
        id: default_route_table_ai_primary.outputs.routetableID
      }
    }
  }
  {
    name: 'ServiceEndpoints'
    properties: {
      addressPrefix: cidrSubnet(aiPrimaryVnetAddressPrefix, 28, 1)
      networkSecurityGroup: {
        id: aiPrimaryNsg.outputs.id
      }
      routeTable: {
        id: default_route_table_ai_primary.outputs.routetableID
      }
    }
  }
]
var aiSecondaryVnetSubnets = [
  {
    name: 'ApiManagement'
    properties: {
      addressPrefix: cidrSubnet(aiSecondaryVnetAddressPrefix, 28, 0)
      networkSecurityGroup: {
        id: apimSecondaryNsg.outputs.id
      }
      serviceEndpoints: [
        {
          service: 'Microsoft.Storage'
        }
        {
          service: 'Microsoft.Sql'
        }
        {
          service: 'Microsoft.EventHub'
        }
        {
          service: 'Microsoft.KeyVault'
        }
        {
          service: 'Microsoft.ServiceBus'
        }
      ]
      routeTable: {
        id: default_route_table_ai_secondary.outputs.routetableID
      }
    }
  }
  {
    name: 'ServiceEndpoints'
    properties: {
      addressPrefix: cidrSubnet(aiSecondaryVnetAddressPrefix, 28, 1)
      networkSecurityGroup: {
        id: aiSecondaryNsg.outputs.id
      }
      routeTable: {
        id: default_route_table_ai_secondary.outputs.routetableID
      }
    }
  }
]

// Resource Groups
module rg_hub 'modules/resource-group/rg.bicep' = {
  name: rgName_hub
  params: {
    rgName: rgName_hub
    location: location_hub
  }
}

module rg_sandbox 'modules/resource-group/rg.bicep' = {
  name: rgName_sandbox
  params: {
    rgName: rgName_sandbox
    location: location_sandbox
  }
}

module rg_ai_primary 'modules/resource-group/rg.bicep' = {
  name: rgName_ai_primary
  params: {
    rgName: rgName_ai_primary
    location: location_ai_primary
  }
}

module rg_ai_secondary 'modules/resource-group/rg.bicep' = {
  name: rgName_ai_secondary
  params: {
    rgName: rgName_ai_secondary
    location: location_ai_secondary
  }
}

// Virtual Networks
module dnsResolverVnet 'modules/vnet/vnet.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: dnsResolverVnetName
  dependsOn: [
    hubVnet
  ]
  params: {
    location: location_hub
    vnetAddressSpace: {
      addressPrefixes: [dnsResolverVnetAddressPrefix]
    }
    vnetName: dnsResolverVnetName
    subnets: dnsResolverVnetSubnets
  }
}

module sandboxVnet 'modules/vnet/vnet.bicep' = {
  scope: resourceGroup(rg_sandbox.name)
  name: sandboxVnetName
  dependsOn: [
    dnsResolverVnet
  ]
  params: {
    location: location_sandbox
    vnetAddressSpace: {
      addressPrefixes: [sandboxVnetAddressPrefix]
    }
    vnetName: sandboxVnetName
    subnets: sandboxVnetSubnets
    dhcpOptions: {
      dnsServers: [dnsResolver.outputs.inboundIpAddress]
    }
  }
}

module hubVnet 'modules/vnet/vnet.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: hubVnetName
  params: {
    location: location_hub
    vnetAddressSpace: {
      addressPrefixes: [hubVnetAddressPrefix]
    }
    vnetName: hubVnetName
    subnets: hubSubnets
  }
  dependsOn: [
    rg_hub
  ]
}

module aiPrimaryVnet 'modules/vnet/vnet.bicep' = {
  scope: resourceGroup(rg_ai_primary.name)
  name: aiPrimaryVnetName
  dependsOn: [
    aiPrimaryNsg
    apimPrimaryNsg
  ]
  params: {
    location: location_ai_primary
    vnetAddressSpace: {
      addressPrefixes: [aiPrimaryVnetAddressPrefix]
    }
    vnetName: aiPrimaryVnetName
    subnets: aiPrimaryVnetSubnets
  }
}

module aiSecondaryVnet 'modules/vnet/vnet.bicep' = {
  scope: resourceGroup(rg_ai_secondary.name)
  name: aiSecondaryVnetName
  dependsOn: [
    aiSecondaryNsg
    apimSecondaryNsg
  ]
  params: {
    location: location_ai_secondary
    vnetAddressSpace: {
      addressPrefixes: [aiSecondaryVnetAddressPrefix]
    }
    vnetName: aiSecondaryVnetName
    subnets: aiSecondaryVnetSubnets
  }
}

resource azureFirewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  scope: resourceGroup(rg_hub.name)
  name: '${hubVnet.name}/AzureFirewallSubnet'
}

resource azureFirewallManagementSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  scope: resourceGroup(rg_hub.name)
  name: '${hubVnet.name}/AzureFirewallManagementSubnet'
}

resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  scope: resourceGroup(rg_hub.name)
  name: '${hubVnet.name}/GatewaySubnet'
}

module peer_dnsResolverVnet_to_hubVnet 'modules/vnet/vnetpeering.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: 'peer-${dnsResolverVnet.name}-to-${hubVnet.name}'
  params: {
    virtualNetworkName1: dnsResolverVnet.name
    virtualNetworkName2: hubVnet.name
    virtualNetworkRgName2: rg_hub.name
  }
}

module peer_hubVnet_to_dnsResolverVnet 'modules/vnet/vnetpeering.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: 'peer-${hubVnet.name}-to-${dnsResolverVnet.name}'
  params: {
    virtualNetworkName1: hubVnet.name
    virtualNetworkName2: dnsResolverVnet.name
    virtualNetworkRgName2: rg_hub.name
  }
}

module peer_hubVnet_to_sandboxVnet 'modules/vnet/vnetpeering.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: 'peer-${hubVnet.name}-to-${sandboxVnet.name}'
  params: {
    virtualNetworkName1: hubVnet.name
    virtualNetworkName2: sandboxVnet.name
    virtualNetworkRgName2: rg_sandbox.name
  }
}

module peer_sandboxVnet_to_hubVnet 'modules/vnet/vnetpeering.bicep' = {
  scope: resourceGroup(rg_sandbox.name)
  name: 'peer-${sandboxVnet.name}-to-${hubVnet.name}'
  params: {
    virtualNetworkName1: sandboxVnet.name
    virtualNetworkName2: hubVnet.name
    virtualNetworkRgName2: rg_hub.name
  }
}

module peer_aiPrimaryVnet_to_hubVnet 'modules/vnet/vnetpeering.bicep' = {
  scope: resourceGroup(rg_ai_primary.name)
  name: 'peer-${aiPrimaryVnet.name}-to-${hubVnet.name}'
  params: {
    virtualNetworkName1: aiPrimaryVnet.name
    virtualNetworkName2: hubVnet.name
    virtualNetworkRgName2: rg_hub.name
  }
}

module peer_hubVnet_to_aiPrimaryVnet 'modules/vnet/vnetpeering.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: 'peer-${hubVnet.name}-to-${aiPrimaryVnet.name}'
  params: {
    virtualNetworkName1: hubVnet.name
    virtualNetworkName2: aiPrimaryVnet.name
    virtualNetworkRgName2: rg_ai_primary.name
  }
}

module peer_aiSecondaryVnet_to_hubVnet 'modules/vnet/vnetpeering.bicep' = {
  scope: resourceGroup(rg_ai_secondary.name)
  name: 'peer-${aiSecondaryVnet.name}-to-${hubVnet.name}'
  params: {
    virtualNetworkName1: aiSecondaryVnet.name
    virtualNetworkName2: hubVnet.name
    virtualNetworkRgName2: rg_hub.name
  }
}

module peer_hubVnet_to_aiSecondaryVnet 'modules/vnet/vnetpeering.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: 'peer-${hubVnet.name}-to-${aiSecondaryVnet.name}'
  params: {
    virtualNetworkName1: hubVnet.name
    virtualNetworkName2: aiSecondaryVnet.name
    virtualNetworkRgName2: rg_ai_secondary.name
  }
}

module default_route_table_sandbox 'modules/vnet/routetable.bicep' = {
  scope: resourceGroup(rg_sandbox.name)
  name: 'default-route-table'
  params: {
    location: location_sandbox
    rtName: 'default-route-table'
  }
}

module default_route_table_dns 'modules/vnet/routetable.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: 'default-route-table'
  params: {
    location: location_hub
    rtName: 'default-route-table'
  }
}

module default_route_table_ai_primary 'modules/vnet/routetable.bicep' = {
  scope: resourceGroup(rg_ai_primary.name)
  name: 'default-route-table'
  params: {
    location: location_ai_primary
    rtName: 'default-route-table'
  }
}

module default_route_table_ai_secondary 'modules/vnet/routetable.bicep' = {
  scope: resourceGroup(rg_ai_secondary.name)
  name: 'default-route-table'
  params: {
    location: location_ai_secondary
    rtName: 'default-route-table'
  }
}

module default_route_sandbox 'modules/vnet/routetableroutes.bicep' = {
  scope: resourceGroup(rg_sandbox.name)
  name: 'route-to-firewall'
  params: {
    routetableName: default_route_table_sandbox.name
    routeName: 'route-to-firewall'
    properties: {
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: hubFirewall.outputs.fwPrivateIP
      addressPrefix: '0.0.0.0/0'
    }
  }
}

module default_route_dns 'modules/vnet/routetableroutes.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: 'route-to-firewall'
  params: {
    routetableName: default_route_table_dns.name
    routeName: 'route-to-firewall'
    properties: {
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: hubFirewall.outputs.fwPrivateIP
      addressPrefix: '0.0.0.0/0'
    }
  }
}

module default_route_ai_primary 'modules/vnet/routetableroutes.bicep' = {
  scope: resourceGroup(rg_ai_primary.name)
  name: 'route-to-firewall'
  params: {
    routetableName: default_route_table_ai_primary.name
    routeName: 'route-to-firewall'
    properties: {
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: hubFirewall.outputs.fwPrivateIP
      addressPrefix: '0.0.0.0/0'
    }
  }
}

module default_route_apim_primary 'modules/vnet/routetableroutes.bicep' = {
  scope: resourceGroup(rg_ai_primary.name)
  name: 'route-to-apimanagement'
  params: {
    routetableName: default_route_table_ai_primary.name
    routeName: 'route-to-apimanagement'
    properties: {
      addressPrefix: 'ApiManagement'
      nextHopType: 'Internet'
      nextHopIpAddress: ''
    }
  }
}

module default_route_ai_secondary 'modules/vnet/routetableroutes.bicep' = {
  scope: resourceGroup(rg_ai_secondary.name)
  name: 'route-to-firewall'
  params: {
    routetableName: default_route_table_ai_secondary.name
    routeName: 'route-to-firewall'
    properties: {
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: hubFirewall.outputs.fwPrivateIP
      addressPrefix: '0.0.0.0/0'
    }
  }
}

module default_route_apim_secondary 'modules/vnet/routetableroutes.bicep' = {
  scope: resourceGroup(rg_ai_secondary.name)
  name: 'route-to-apimanagement'
  params: {
    routetableName: default_route_table_ai_secondary.name
    routeName: 'route-to-apimanagement'
    properties: {
      addressPrefix: 'ApiManagement'
      nextHopType: 'Internet'
      nextHopIpAddress: ''
    }
  }
}

module return_route_table 'modules/vnet/routetable.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: 'return-route-table'
  params: {
    location: location_hub
    rtName: 'return-route-table'
  }
}

module sandboxVnet_route 'modules/vnet/routetableroutes.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: 'route-to-sandbox-vnet'
  params: {
    routetableName: return_route_table.name
    routeName: 'route-to-sandbox-vnet'
    properties: {
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: hubFirewall.outputs.fwPrivateIP
      addressPrefix: sandboxVnet.outputs.vnetAddressSpace[0]
    }
  }
}

module dnsResolverVnet_route 'modules/vnet/routetableroutes.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: 'route-to-dnsResolver-vnet'
  params: {
    routetableName: return_route_table.name
    routeName: 'route-to-dnsResolver-vnet'
    properties: {
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: hubFirewall.outputs.fwPrivateIP
      addressPrefix: dnsResolverVnet.outputs.vnetAddressSpace[0]
    }
  }
}

module aiPrimaryVnet_route 'modules/vnet/routetableroutes.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: 'route-to-aiPrimary-vnet'
  params: {
    routetableName: return_route_table.name
    routeName: 'route-to-aiPrimary-vnet'
    properties: {
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: hubFirewall.outputs.fwPrivateIP
      addressPrefix: aiPrimaryVnet.outputs.vnetAddressSpace[0]
    }
  }
}

module aiSecondaryVnet_route 'modules/vnet/routetableroutes.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: 'route-to-aiSecondary-vnet'
  params: {
    routetableName: return_route_table.name
    routeName: 'route-to-aiSecondary-vnet'
    properties: {
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: hubFirewall.outputs.fwPrivateIP
      addressPrefix: aiSecondaryVnet.outputs.vnetAddressSpace[0]
    }
  }
}

module apimPrimaryNsg 'modules/vnet/nsg.bicep' = {
  scope: resourceGroup(rg_ai_primary.name)
  name: '${apimName}-nsg'
  params: {
    location: location_ai_primary
    nsgName: '${apimName}-nsg'
    nsgType: 'apim'
  }
}

module apimSecondaryNsg 'modules/vnet/nsg.bicep' = {
  scope: resourceGroup(rg_ai_secondary.name)
  name: '${apimName}-nsg'
  params: {
    location: location_ai_secondary
    nsgName: '${apimName}-nsg'
    nsgType: 'apim'
  }
}

module aiPrimaryNsg 'modules/vnet/nsg.bicep' = {
  scope: resourceGroup(rg_ai_primary.name)
  name: '${aiName_primary}-nsg'
  params: {
    location: location_ai_primary
    nsgName: '${aiName_primary}-nsg'
    nsgType: 'apim'
  }
}

module aiSecondaryNsg 'modules/vnet/nsg.bicep' = {
  scope: resourceGroup(rg_ai_secondary.name)
  name: '${aiName_secondary}-nsg'
  params: {
    location: location_ai_secondary
    nsgName: '${aiName_secondary}-nsg'
    nsgType: 'apim'
  }
}

/*
module hubDefaultNsg 'modules/vnet/nsg.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: hubDefaultNsgName
  params: {
    location: location_hub
    nsgName: hubDefaultNsgName
  }
}
*/

module sandboxDefaultNsg 'modules/vnet/nsg.bicep' = {
  scope: resourceGroup(rg_sandbox.name)
  name: sandboxDefaultNsgName
  params: {
    location: location_sandbox
    nsgName: sandboxDefaultNsgName
  }
}

module dnsResolverDefaultNsg 'modules/vnet/nsg.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: dnsResolverDefaultNsgName
  params: {
    location: location_hub
    nsgName: dnsResolverDefaultNsgName
  }
}

module hubBastionNsg 'modules/vnet/nsg.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: hubBastionNsgName
  params: {
    location: location_hub
    nsgName: hubBastionNsgName
    nsgType: 'bastion'
  }
}

// Firewall
module hubFirewallPip 'modules/vnet/publicip.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: hubFirewallPipName
  params: {
    availabilityZones:availabilityZones
    location: location_hub
    publicipName: hubFirewallPipName
    publicipproperties: {
      publicIPAllocationMethod: 'Static'
    }
    publicipsku: {
      name: 'Standard'
      tier: 'Regional'
    }
  }
}

module hubFirewallMgmtPip 'modules/vnet/publicip.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: hubFirewallMgmtPipName
  params: {
    availabilityZones:availabilityZones
    location: location_hub
    publicipName: hubFirewallMgmtPipName
    publicipproperties: {
      publicIPAllocationMethod: 'Static'
    }
    publicipsku: {
      name: 'Standard'
      tier: 'Regional'
    }
  }
}

module hubFirewall 'modules/vnet/firewall.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: hubFirewallName
  params: {
    availabilityZones: availabilityZones
    location: location_hub
    fwname: hubFirewallName
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    fwipConfigurations: [
      {
        name: hubFirewallPipName
        properties: {
          subnet: {
            id: azureFirewallSubnet.id
          }
          publicIPAddress: {
            id: hubFirewallPip.outputs.publicipId
          }
        }
      }
    ]
    fwipManagementConfigurations: {
      name: hubFirewallMgmtPipName
      properties: {
        subnet: {
          id: azureFirewallManagementSubnet.id
        }
        publicIPAddress: {
          id: hubFirewallMgmtPip.outputs.publicipId
        }
      }
    }
    fwapplicationRuleCollections: fwapplicationRuleCollections
    fwnatRuleCollections: []
    fwnetworkRuleCollections: fwnetworkRuleCollections
  }
}

// Gateway
module hubVnetGatewayPip 'modules/vnet/publicip.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: hubVnetGatewayPipName
  params: {
    availabilityZones:availabilityZones
    location: location_hub
    publicipName: hubVnetGatewayPipName
    publicipproperties: {
      publicIPAllocationMethod: 'Static'
    }
    publicipsku: {
      name: 'Standard'
      tier: 'Regional'
    }
  }
}

module hubVnetGateway 'modules/vnet/gateway.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: hubVnetGatewayName
  params: {
    location: location_hub
    gatewayName: hubVnetGatewayName
    gatewayPublicIpId: hubVnetGatewayPip.outputs.publicipId
    gatewaySku: 'VpnGw1'
    gatewaySubnetId: gatewaySubnet.id
  }
}

// DNS Resolver
module dnsResolver 'modules/vnet/dnsresolver.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: dnsResolverName
  params: {
    location: location_hub
    inboundSubnetName: inboundSubnetName
    outboundSubnetName: outboundSubnetName
    virtualNetworkName: dnsResolverVnet.name
    forwardingRuleName: safeOnpremDomainName
    DomainName: onpremDomainName
    targetDNS: onpremDnsServers
  }
}

/*
module dnsResolver_to_sandboxVnet 'modules/vnet/dnsresolvervnetlink.bicep' = {
  scope: resourceGroup(rg_hub.name)
  name: sandboxVnet.name
  params: {
    forwardingRulesetName: dnsResolver.outputs.forwardingRulesetName
    rg_virtualnetwork_name: rg_sandbox.name
    virtualNetworkName: sandboxVnet.name
  }
}
*/

/*
// VMs

module windowsvm 'modules/compute/virtualmachine.bicep' = {
  scope: resourceGroup(rg_sandbox.name)
  name: '${vmNameWindows}01'
  params: {
    location: location_sandbox
    vmName: '${vmNameWindows}01'
    vmSize: vmSize
    vmStorageAccountType: vmStorageAccountType
    subnetId: sandboxVnet.outputs.vnetSubnets[0].id
    adminUsername: adminUsername
    adminPassword: adminPassword
    imageReference: windowsVmImageReference
    emailRecipient: notificationEmail
  }
}
*/
// AI

module aoai_primary_tpu './modules/ai/cognitive-services.bicep' = {
  name: aiName_primary
  scope: resourceGroup(rg_ai_primary.name)
  params: {
    name: aiName_primary
    location: location_ai_primary
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    publicNetworkAccess: 'Disabled'
    sku: {
      name: 'S0'
    }
    kind: 'OpenAI'
    deployments: [
      {
        name: 'gpt-35-turbo'
        model: {
          format: 'OpenAI'
          name: 'gpt-35-turbo'
          version: '1106'
        }
        sku: {
          name: 'Standard'
          capacity: 30
        }
      }
      {
        name: 'text-embedding-ada-002'
        model: {
          format: 'OpenAI'
          name: 'text-embedding-ada-002'
          version: '2'
        }
        sku: {
          name: 'Standard'
          capacity: 30
        }
      }
    ]
  }
}

module aoai_secondary_tpu './modules/ai/cognitive-services.bicep' = {
  name: aiName_secondary
  scope: resourceGroup(rg_ai_secondary.name)
  params: {
    name: aiName_secondary
    location: location_ai_secondary
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    publicNetworkAccess: 'Disabled'
    sku: {
      name: 'S0'
    }
    kind: 'OpenAI'
    deployments: [
      {
        name: 'gpt-35-turbo'
        model: {
          format: 'OpenAI'
          name: 'gpt-35-turbo'
          version: '0301'
        }
        sku: {
          name: 'Standard'
          capacity: 30
        }
      }
      {
        name: 'text-embedding-ada-002'
        model: {
          format: 'OpenAI'
          name: 'text-embedding-ada-002'
          version: '2'
        }
        sku: {
          name: 'Standard'
          capacity: 30
        }
      }
    ]
  }
}

module aoai_dns_zone_primary 'modules/vnet/privatednszone.bicep' = {
  name: 'privatelink.openai.azure.com'
  scope: resourceGroup(rg_ai_primary.name)
  params: {
    privateDnsZoneName: 'privatelink.openai.azure.com'
  }
}

module aoai_dns_zone_secondary 'modules/vnet/privatednszone.bicep' = {
  name: 'privatelink.openai.azure.com'
  scope: resourceGroup(rg_ai_secondary.name)
  params: {
    privateDnsZoneName: 'privatelink.openai.azure.com'
  }
}

module aoai_dns_zone_resolver 'modules/vnet/privatednszone.bicep' = {
  name: 'privatelink.openai.azure.com'
  scope: resourceGroup(rg_hub.name)
  params: {
    privateDnsZoneName: 'privatelink.openai.azure.com'
  }
}

module aoai_dns_zone_primary_link_aoai_primary_vnet 'modules/vnet/privatednszonelink.bicep' = {
  name: '${replace(aoai_dns_zone_primary.name, '.', '-')}-link-to-${aiPrimaryVnet.name}'
  scope: resourceGroup(rg_ai_primary.name)
  params: {
    privateDnsZoneName: aoai_dns_zone_primary.outputs.privateDnsZoneName
    privateDnsZoneLinkName: '${replace(aoai_dns_zone_primary.name, '.', '-')}-link-to-${aiPrimaryVnet.name}'
    virtualNetworkId: aiPrimaryVnet.outputs.vnetId
  }
}

module aoai_dns_zone_secondary_link_aoai_secondary_vnet 'modules/vnet/privatednszonelink.bicep' = {
  name: '${replace(aoai_dns_zone_secondary.name, '.', '-')}-link-to-${aiSecondaryVnet.name}'
  scope: resourceGroup(rg_ai_secondary.name)
  params: {
    privateDnsZoneName: aoai_dns_zone_secondary.outputs.privateDnsZoneName
    privateDnsZoneLinkName: '${replace(aoai_dns_zone_secondary.name, '.', '-')}-link-to-${aiSecondaryVnet.name}'
    virtualNetworkId: aiSecondaryVnet.outputs.vnetId
  }
}

module aoai_dns_zone_resolver_link_resolver_vnet 'modules/vnet/privatednszonelink.bicep' = {
  name: '${replace(aoai_dns_zone_resolver.name, '.', '-')}-link-to-${dnsResolverVnet.name}'
  scope: resourceGroup(rg_hub.name)
  params: {
    privateDnsZoneName: aoai_dns_zone_resolver.outputs.privateDnsZoneName
    privateDnsZoneLinkName: '${replace(aoai_dns_zone_resolver.name, '.', '-')}-link-to-${dnsResolverVnet.name}'
    virtualNetworkId: dnsResolverVnet.outputs.vnetId
  }
}

module aoai_primary_tpu_link_aoai_primary_vnet 'modules/vnet/privatelink.bicep' = {
  name: 'aoai_primary_tpu_link_aoai_primary_vnet'
  scope: resourceGroup(rg_ai_primary.name)
  params: {
    groupIds: ['account']
    location: location_ai_primary
    privateDnsZoneId: aoai_dns_zone_primary.outputs.privateDnsZoneId
    privateEndpointName: '${aoai_primary_tpu.name}-${location_ai_primary}-ep'
    privateEndpointSubnetId: aiPrimaryVnet.outputs.vnetSubnets[1].id
    privateLinkServiceId: aoai_primary_tpu.outputs.id
    pvtEndpointDnsGroupName: '${aoai_primary_tpu.name}-${location_ai_primary}-ep/openai-endpoint-zone'
  }
}

module aoai_primary_tpu_link_aoai_secondary_vnet 'modules/vnet/privatelink.bicep' = {
  name: 'aoai_primary_tpu_link_aoai_secondary_vnet'
  scope: resourceGroup(rg_ai_secondary.name)
  params: {
    groupIds: ['account']
    location: location_ai_secondary
    privateDnsZoneId: aoai_dns_zone_secondary.outputs.privateDnsZoneId
    privateEndpointName: '${aoai_primary_tpu.name}-${location_ai_secondary}-ep'
    privateEndpointSubnetId: aiSecondaryVnet.outputs.vnetSubnets[1].id
    privateLinkServiceId: aoai_primary_tpu.outputs.id
    pvtEndpointDnsGroupName: '${aoai_primary_tpu.name}-${location_ai_secondary}-ep/openai-endpoint-zone'
  }
}

module aoai_secondary_tpu_link_aoai_primary_vnet 'modules/vnet/privatelink.bicep' = {
  name: 'aoai_secondary_tpu_link_aoai_primary_vnet'
  scope: resourceGroup(rg_ai_primary.name)
  params: {
    groupIds: ['account']
    location: location_ai_primary
    privateDnsZoneId: aoai_dns_zone_primary.outputs.privateDnsZoneId
    privateEndpointName: '${aoai_secondary_tpu.name}-${location_ai_primary}-ep'
    privateEndpointSubnetId: aiPrimaryVnet.outputs.vnetSubnets[1].id
    privateLinkServiceId: aoai_secondary_tpu.outputs.id
    pvtEndpointDnsGroupName: '${aoai_secondary_tpu.name}-${location_ai_primary}-ep/openai-endpoint-zone'
  }
}

module aoai_secondary_tpu_link_aoai_secondary_vnet 'modules/vnet/privatelink.bicep' = {
  name: 'aoai_secondary_tpu_link_aoai_secondary_vnet'
  scope: resourceGroup(rg_ai_secondary.name)
  params: {
    groupIds: ['account']
    location: location_ai_secondary
    privateDnsZoneId: aoai_dns_zone_secondary.outputs.privateDnsZoneId
    privateEndpointName: '${aoai_secondary_tpu.name}-${location_ai_secondary}-ep'
    privateEndpointSubnetId: aiSecondaryVnet.outputs.vnetSubnets[1].id
    privateLinkServiceId: aoai_secondary_tpu.outputs.id
    pvtEndpointDnsGroupName: '${aoai_secondary_tpu.name}-${location_ai_secondary}-ep/openai-endpoint-zone'
  }
}

module apim_primary_pip 'modules/vnet/publicipaddress.bicep' = {
  name: '${apimName}-primary-pip'
  scope: resourceGroup(rg_ai_primary.name)
  params: {
    domainNameLabel: '${replace(toLower(apimName), '-', '')}primary'
    location: location_ai_primary
    publicIPAddressName:'${apimName}-primary-pip'
  }
}

module apim_secondary_pip 'modules/vnet/publicipaddress.bicep' = {
  name: '${apimName}-secondary-pip'
  scope: resourceGroup(rg_ai_secondary.name)
  params: {
    domainNameLabel: '${replace(toLower(apimName), '-', '')}secondary'
    location: location_ai_secondary
    publicIPAddressName:'${apimName}-secondary-pip'
  }
}

module apim_identity 'modules/identity/managed-identity.bicep' = {
  name: '${apimName}-mi'
  scope: resourceGroup(rg_ai_primary.name)
  params: {
    location: location_ai_primary
    name: '${apimName}-mi'
  }
}

module apim 'modules/apim/api-management.bicep' = {
  name: apimName
  scope: resourceGroup(rg_ai_primary.name)
  params: {
    apiManagementIdentityId: apim_identity.outputs.id
    apimSubnetId: aiPrimaryVnet.outputs.vnetSubnets[0].id
    apimSubnetId_secondary: aiSecondaryVnet.outputs.vnetSubnets[0].id
    location: location_ai_primary
    location_secondary: location_ai_secondary
    name: apimName
    publicIpAddressId: apim_primary_pip.outputs.id
    publicIpAddressId_secondary: apim_secondary_pip.outputs.id
    publisherEmail: notificationEmail
    publisherName: notificationEmail
    virtualNetworkType: 'Internal'
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    sku: {
      name: 'Premium'
      capacity: 1
    }
  }
}
module apim_dns_zone_resolver 'modules/vnet/privatednszone.bicep' = {
  name: 'azure-api.net'
  scope: resourceGroup(rg_hub.name)
  params: {
    privateDnsZoneName: 'azure-api.net'
  }
}

module apim_dns_zone_primary 'modules/vnet/privatednszone.bicep' = {
  name: 'azure-api.net'
  scope: resourceGroup(rg_ai_primary.name)
  params: {
    privateDnsZoneName: 'azure-api.net'
  }
}

module apim_dns_zone_secondary 'modules/vnet/privatednszone.bicep' = {
  name: 'azure-api.net'
  scope: resourceGroup(rg_ai_secondary.name)
  params: {
    privateDnsZoneName: 'azure-api.net'
  }
}

module apim_dns_zone_primary_link_aoai_primary_vnet 'modules/vnet/privatednszonelink.bicep' = {
  name: '${replace(apim_dns_zone_primary.name, '.', '-')}-link-to-${aiPrimaryVnet.name}'
  scope: resourceGroup(rg_ai_primary.name)
  params: {
    privateDnsZoneName: apim_dns_zone_primary.outputs.privateDnsZoneName
    privateDnsZoneLinkName: '${replace(apim_dns_zone_primary.name, '.', '-')}-link-to-${aiPrimaryVnet.name}'
    virtualNetworkId: aiPrimaryVnet.outputs.vnetId
  }
}

module apim_dns_zone_secondary_link_aoai_secondary_vnet 'modules/vnet/privatednszonelink.bicep' = {
  name: '${replace(apim_dns_zone_secondary.name, '.', '-')}-link-to-${aiSecondaryVnet.name}'
  scope: resourceGroup(rg_ai_secondary.name)
  params: {
    privateDnsZoneName: apim_dns_zone_secondary.outputs.privateDnsZoneName
    privateDnsZoneLinkName: '${replace(apim_dns_zone_secondary.name, '.', '-')}-link-to-${aiSecondaryVnet.name}'
    virtualNetworkId: aiSecondaryVnet.outputs.vnetId
  }
}

module apim_dns_zone_resolver_link_dns_vnet 'modules/vnet/privatednszonelink.bicep' = {
  name: '${replace(apim_dns_zone_resolver.name, '.', '-')}-link-to-${dnsResolverVnet.name}'
  scope: resourceGroup(rg_hub.name)
  params: {
    privateDnsZoneName: apim_dns_zone_resolver.outputs.privateDnsZoneName
    privateDnsZoneLinkName: '${replace(apim_dns_zone_resolver.name, '.', '-')}-link-to-${dnsResolverVnet.name}'
    virtualNetworkId: dnsResolverVnet.outputs.vnetId
  }
}

var apim_regional_primary_a_record = replace(replace(toLower(apim.outputs.primaryRegionalUrl), 'https://', ''), '.${apim_dns_zone_primary.outputs.privateDnsZoneName}', '')
var apim_regional_secondary_a_record = replace(replace(toLower(apim.outputs.secondaryRegionalUrl), 'https://', ''), '.${apim_dns_zone_secondary.outputs.privateDnsZoneName}', '')
var apim_gateway_a_record = replace(replace(toLower(apim.outputs.gatewayUrl), 'https://', ''), '.${apim_dns_zone_primary.outputs.privateDnsZoneName}', '')
var apim_developer_portal_a_record = replace(replace(toLower(apim.outputs.developerPortalUrl), 'https://', ''), '.${apim_dns_zone_primary.outputs.privateDnsZoneName}', '')
var apim_portal_a_record = replace(replace(toLower(apim.outputs.portalUrl), 'https://', ''), '.${apim_dns_zone_primary.outputs.privateDnsZoneName}', '')
var apim_scm_a_record = replace(replace(toLower(apim.outputs.scmUrl), 'https://', ''), '.${apim_dns_zone_primary.outputs.privateDnsZoneName}', '')
var apim_management_a_record = replace(replace(toLower(apim.outputs.managementApiUrl), 'https://', ''), '.${apim_dns_zone_primary.outputs.privateDnsZoneName}', '')

module regional_primary_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'apim_regional_primary_a_record'
  scope: resourceGroup(rg_ai_primary.name)
  params:{
    zoneName: apim_dns_zone_primary.outputs.privateDnsZoneName
    recordName: apim_regional_primary_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.primaryIpAddress
        }
      ]
    }
  }
}

module primary_gateway_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'apim_primary_gateway_a_record'
  scope: resourceGroup(rg_ai_primary.name)
  params:{
    zoneName: apim_dns_zone_primary.outputs.privateDnsZoneName
    recordName: apim_gateway_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.primaryIpAddress
        }
      ]
    }
  }
}

module primary_developer_portal_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'apim_primary_developer_portal_a_record'
  scope: resourceGroup(rg_ai_primary.name)
  params:{
    zoneName: apim_dns_zone_primary.outputs.privateDnsZoneName
    recordName: apim_developer_portal_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.primaryIpAddress
        }
      ]
    }
  }
}

module primary_portal_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'apim_primary_portal_a_record'
  scope: resourceGroup(rg_ai_primary.name)
  params:{
    zoneName: apim_dns_zone_primary.outputs.privateDnsZoneName
    recordName: apim_portal_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.primaryIpAddress
        }
      ]
    }
  }
}

module primary_scm_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'apim_primary_scm_a_record'
  scope: resourceGroup(rg_ai_primary.name)
  params:{
    zoneName: apim_dns_zone_primary.outputs.privateDnsZoneName
    recordName: apim_scm_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.primaryIpAddress
        }
      ]
    }
  }
}

module primary_management_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'apim_primary_management_a_record'
  scope: resourceGroup(rg_ai_primary.name)
  params:{
    zoneName: apim_dns_zone_primary.outputs.privateDnsZoneName
    recordName: apim_management_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.primaryIpAddress
        }
      ]
    }
  }
}

module regional_secondary_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'regional_secondary_a_record'
  scope: resourceGroup(rg_ai_secondary.name)
  params:{
    zoneName: apim_dns_zone_secondary.outputs.privateDnsZoneName
    recordName: apim_regional_secondary_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.secondaryIpAddress
        }
      ]
    }
  }
}

module secondary_gateway_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'apim_secondary_gateway_a_record'
  scope: resourceGroup(rg_ai_secondary.name)
  params:{
    zoneName: apim_dns_zone_secondary.outputs.privateDnsZoneName
    recordName: apim_gateway_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.secondaryIpAddress
        }
      ]
    }
  }
}

module resolver_regional_primary_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'resolver_apim_regional_primary_a_record'
  scope: resourceGroup(rg_hub.name)
  params:{
    zoneName: apim_dns_zone_resolver.outputs.privateDnsZoneName
    recordName: apim_regional_primary_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.primaryIpAddress
        }
      ]
    }
  }
}

module resolver_regional_secondary_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'resolver_apim_regional_secondary_a_record'
  scope: resourceGroup(rg_hub.name)
  params:{
    zoneName: apim_dns_zone_resolver.outputs.privateDnsZoneName
    recordName: apim_regional_secondary_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.secondaryIpAddress
        }
      ]
    }
  }
}

module resolver_gateway_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'apim_resolver_gateway_a_record'
  scope: resourceGroup(rg_hub.name)
  params:{
    zoneName: apim_dns_zone_resolver.outputs.privateDnsZoneName
    recordName: apim_gateway_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.primaryIpAddress
        }
        {
          ipv4Address: apim.outputs.secondaryIpAddress
        }
      ]
    }
  }
}

module resolver_developer_portal_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'apim_resolver_developer_portal_a_record'
  scope: resourceGroup(rg_hub.name)
  params:{
    zoneName: apim_dns_zone_resolver.outputs.privateDnsZoneName
    recordName: apim_developer_portal_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.primaryIpAddress
        }
      ]
    }
  }
}

module resolver_portal_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'apim_resolver_portal_a_record'
  scope: resourceGroup(rg_hub.name)
  params:{
    zoneName: apim_dns_zone_resolver.outputs.privateDnsZoneName
    recordName: apim_portal_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.primaryIpAddress
        }
      ]
    }
  }
}

module resolver_scm_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'apim_resolver_scm_a_record'
  scope: resourceGroup(rg_hub.name)
  params:{
    zoneName: apim_dns_zone_resolver.outputs.privateDnsZoneName
    recordName: apim_scm_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.primaryIpAddress
        }
      ]
    }
  }
}

module resolver_management_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'apim_resolver_management_a_record'
  scope: resourceGroup(rg_hub.name)
  params:{
    zoneName: apim_dns_zone_resolver.outputs.privateDnsZoneName
    recordName: apim_management_a_record
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: apim.outputs.primaryIpAddress
        }
      ]
    }
  }
}

module aoai_primary_tpu_networkinterface 'modules/vnet/getnetworkinterface.bicep' = {
  name: 'aoai_primary_tpu_networkinterface'
  scope: resourceGroup(rg_ai_primary.name)
  params: {
    networkInterfaceId: aoai_primary_tpu_link_aoai_primary_vnet.outputs.networkInterfaceId
  }
}

module aoai_secondary_tpu_networkinterface 'modules/vnet/getnetworkinterface.bicep' = {
  name: 'aoai_secondary_tpu_networkinterface'
  scope: resourceGroup(rg_ai_secondary.name)
  params: {
    networkInterfaceId: aoai_secondary_tpu_link_aoai_secondary_vnet.outputs.networkInterfaceId
  }
}

module resolver_ai_primary_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'resolver_ai_primary_a_record'
  scope: resourceGroup(rg_hub.name)
  params:{
    zoneName: aoai_dns_zone_resolver.outputs.privateDnsZoneName
    recordName: aoai_primary_tpu.name
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: aoai_primary_tpu_networkinterface.outputs.networkinterface.properties.ipConfigurations[0].properties.privateIPAddress
        }
      ]
    }
  }
}

module resolver_ai_secondary_a_record 'modules/vnet/privatednsrecord.bicep'  = {
  name: 'resolver_ai_secondary_a_record'
  scope: resourceGroup(rg_hub.name)
  params:{
    zoneName: aoai_dns_zone_resolver.outputs.privateDnsZoneName
    recordName: aoai_secondary_tpu.name
    properties: {
      ttl: 300
      aRecords: [
        {
          ipv4Address: aoai_secondary_tpu_networkinterface.outputs.networkinterface.properties.ipConfigurations[0].properties.privateIPAddress
        }
      ]
    }
  }
}


