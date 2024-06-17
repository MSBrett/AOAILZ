@description('Name of the resource.')
param name string
@description('Location to deploy the resource. Defaults to the location of the resource group.')
param location string = resourceGroup().location
@description('Tags for the resource.')
param tags object = {}

@description('Cognitive Services SKU. Defaults to S0.')
param sku object = {
  name: 'S0'
}
@description('Cognitive Services Kind. Defaults to OpenAI.')
@allowed([
  'Bing.Speech'
  'SpeechTranslation'
  'TextTranslation'
  'Bing.Search.v7'
  'Bing.Autosuggest.v7'
  'Bing.CustomSearch'
  'Bing.SpellCheck.v7'
  'Bing.EntitySearch'
  'Face'
  'ComputerVision'
  'ContentModerator'
  'TextAnalytics'
  'LUIS'
  'SpeakerRecognition'
  'CustomSpeech'
  'CustomVision.Training'
  'CustomVision.Prediction'
  'OpenAI'
])
param kind string = 'OpenAI'
@description('List of deployments for Cognitive Services.')
param deployments array = []
@description('Whether to enable public network access. Defaults to Enabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'
param logAnalyticsWorkspaceId string = ''
var policyName = '${name}-policy'

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    customSubDomainName: toLower(name)
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
  sku: sku
}

resource raiPolicy 'Microsoft.CognitiveServices/accounts/raiPolicies@2023-10-01-preview' = {
  parent: cognitiveServices
  name: policyName
  properties: {
    basePolicyName: 'Microsoft.Default'
    contentFilters:[
      {
          name: 'Hate'
          allowedContentLevel: 'Medium'
          blocking: true
          enabled: true
          source: 'Prompt'
      }
      {
          name: 'Hate'
          allowedContentLevel: 'Medium'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
          name: 'Sexual'
          allowedContentLevel: 'Medium'
          blocking: true
          enabled: true
          source: 'Prompt'
      }
      {
          name: 'Sexual'
          allowedContentLevel: 'Medium'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
          name: 'Violence'
          allowedContentLevel: 'Medium'
          blocking: true
          enabled: true
          source: 'Prompt'
      }
      {
          name: 'Violence'
          allowedContentLevel: 'Medium'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
          name: 'Selfharm'
          allowedContentLevel: 'Medium'
          blocking: true
          enabled: true
          source: 'Prompt'
      }
      {
          name: 'Selfharm'
          allowedContentLevel: 'Medium'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
        name: 'jailbreak'
        blocking: true
        enabled: true
        source: 'Prompt'
      }
      {
          name: 'protected_material_text'
          blocking: true
          enabled: true
          source: 'Completion'
      }
      {
          name: 'protected_material_code'
          blocking: true
          enabled: true
          source: 'Completion'
      }
    ]
  }
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  parent: cognitiveServices
  name: deployment.name
  properties: {
    model: contains(deployment, 'model') ? deployment.model : null
    raiPolicyName: contains(deployment, 'raiPolicyName') ? deployment.raiPolicyName : raiPolicy.name
  }
  sku: contains(deployment, 'sku') ? deployment.sku : {
    name: 'Standard'
    capacity: 100
  }
}]

resource cognitiveServicesDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceId != '') {
  scope: cognitiveServices
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
  }
}

@description('ID for the deployed Cognitive Services resource.')
output id string = cognitiveServices.id
@description('Name for the deployed Cognitive Services resource.')
output name string = cognitiveServices.name
@description('Endpoint for the deployed Cognitive Services resource.')
output endpoint string = cognitiveServices.properties.endpoint
@description('Host for the deployed Cognitive Services resource.')
output host string = split(cognitiveServices.properties.endpoint, '/')[2]
