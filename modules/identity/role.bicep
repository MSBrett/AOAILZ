param principalId string
param roleGuid string
param resourceGroupName string

@allowed([
  'ServicePrincipal'
  'User'
])
param principalType string = 'ServicePrincipal'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceGroupName
  scope: subscription()
}

resource role_assignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup.id, principalId, roleGuid)
  properties: {
    principalId: principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleGuid)
    principalType: principalType
  }
}
