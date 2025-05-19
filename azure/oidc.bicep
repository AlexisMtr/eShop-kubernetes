targetScope = 'resourceGroup'

param location string = resourceGroup().location
param randomSuffix string = uniqueString(subscription().displayName)
param owner string
param purpose string
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'oidc${replace(purpose, '-', '')}${replace(owner, '-', '')}${replace(randomSuffix, '-', '')}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: union(tags, {})
  properties: {
    allowBlobPublicAccess: true
    publicNetworkAccess: 'Enabled'
  }

  resource blob 'blobServices@2024-01-01' = {
    name: 'default'
    properties: {}
    resource oidcContainer 'containers@2024-01-01' = {
      name: 'oidc'
      properties: {
        publicAccess: 'Blob'
      }
    }
  }
}

resource oidcDocumentsUpload 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  kind: 'AzureCLI'
  location: location
  tags: union(tags, {})
  name: 'uploadOidcDocuments'
  properties: {
    azCliVersion: '2.72.0'
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: storageAccount.name
      }
      {
        name: 'AZURE_STORAGE_CONTAINER'
        value: storageAccount::blob::oidcContainer.name
      }
      {
        name: 'DISCOVERY_CONTENT'
        value: loadTextContent('./resources/oidcDiscoveryDocument.json')
      }
      {
        name: 'JWKS_CONTENT'
        value: loadTextContent('./resources/jwks.json')
      }
    ]
    retentionInterval: 'PT1H'
    scriptContent: '''
      echo $DISCOVERY_CONTENT > openid-configuration.json.tpl
      envsubst < openid-configuration.json.tpl > openid-configuration.json
      az storage blob upload \
        --account-name $AZURE_STORAGE_ACCOUNT \
        --container-name $AZURE_STORAGE_CONTAINER \
        --name .well-known/openid-configuration \
        --file openid-configuration.json

      echo JWKS_CONTENT > jwks.json
      az storage blob upload \
        --account-name $AZURE_STORAGE_ACCOUNT \
        --container-name $AZURE_STORAGE_CONTAINER \
        --name openid/v1/jwks \
        --file jwks.json
    '''
  }
}
