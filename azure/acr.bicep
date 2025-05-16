param location string = resourceGroup().location
param randomSuffix string = uniqueString(subscription().displayName)
param owner string
param purpose string
param tags object = {}

param rbacAssignments array = []

resource acr 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  name: 'acr-${purpose}-${owner}-${randomSuffix}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    networkRuleBypassOptions: 'AzureServices'
    publicNetworkAccess: 'Enabled'
  }
  tags: union(tags, {})
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for assignment in rbacAssignments: {
  scope: acr
  name: guid(subscription().id, resourceGroup().id, acr.name, assignment.identity, assignment.rbacDefinition)
  properties: {
    principalId: assignment.identity
    roleDefinitionId: assignment.rbacDefinition
    principalType: 'User'
  }
}]
