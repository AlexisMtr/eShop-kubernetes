targetScope = 'subscription'

param location string
param randomSuffix string = substring(uniqueString(subscription().displayName), 0, 3)
param owner string
param purpose string

@secure()
@description('Password for the lab VM. Empty to use SSH key.')
param vmssPassword string
@description('Content of the SSH public key.')
param sshPublicKey string

param whitelistIps array = []

param identities array = []

var roles = loadJsonContent('./resources/roles.json')

var tags = {
  owner: owner
  purpose: purpose
}

resource rg 'Microsoft.Resources/resourceGroups@2025-03-01' = {
  name: 'rg-${purpose}-${owner}-${randomSuffix}'
  location: location
  tags: tags
}

module lab 'lab.bicep' = {
  name: 'lab-${purpose}-${owner}-${randomSuffix}'
  scope: rg
  params: {
    randomSuffix: randomSuffix
    owner: owner
    purpose: purpose
    tags: tags
    controlPlaneNodeCount: 3
    workerNodeCount: 0
    allowedIps: whitelistIps
    sshPublicKey: sshPublicKey
    authenticationType: length(vmssPassword) > 0 ? 'password' : 'ssh'
    password: vmssPassword
  }
}

module acr 'acr.bicep' = {
  name: 'acr-${purpose}-${owner}-${randomSuffix}'
  scope: rg
  params: {
    randomSuffix: randomSuffix
    owner: owner
    purpose: purpose
    tags: tags
    location: location
    rbacAssignments: map(identities, id => {
      identity: id
      rbacDefinition: roles.AcrPull
    })
  }
}
