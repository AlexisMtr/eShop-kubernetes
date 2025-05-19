param location string = resourceGroup().location
param randomSuffix string = uniqueString(subscription().displayName)
param owner string
param purpose string
param tags object = {}

@allowed(['ssh', 'password'])
param authenticationType string = 'ssh'
param sshPublicKey string
param username string = 'azadm'
@secure()
param password string

param allowedIps array

param controlPlaneNodeCount int = 3
param controlPlaneNodeSize string = 'Standard_B2ls_v2'

param workerNodeCount int = 3
param workerNodeSize string = 'Standard_B2ls_v2'

var roles = loadJsonContent('./resources/roles.json')

var imageReference = {
  offer: 'ubuntu-24_04-lts'
  publisher: 'Canonical'
  sku: 'server'
  version: 'latest'
}

var osDisk = {
  createOption: 'FromImage'
  diskSizeGB: 30
  caching: 'ReadWrite'
  managedDisk: {
    storageAccountType: 'StandardSSD_LRS'
  }
}

resource workloadIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: 'mid-wid-${purpose}-${owner}-${randomSuffix}'
  location: location
  tags: union(tags, {})
}

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, resourceGroup().id, workloadIdentity.id, roles.Contributor)
  properties: {
    principalId: workloadIdentity.properties.principalId
    roleDefinitionId: roles.Contributor
    principalType: 'ServicePrincipal'
  }
}

resource creds 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2025-01-31-preview' = {
  name: 'federated-identity-${purpose}-${owner}-${randomSuffix}'
  parent: workloadIdentity
  properties: {
    audiences: [
     'api://AzureADTokenExchange' 
    ]
    issuer: 'https://sts.windows.net/${subscription().tenantId}/'
    subject: 'system:serviceaccount:kube-system:azadm'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-${purpose}-${owner}-${randomSuffix}'
  location: location
  tags: union(tags, {})
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }

  resource defaultSubnet 'subnets@2024-05-01' = {
    name: 'subnet-${purpose}-${owner}-${randomSuffix}'
    properties: {
      addressPrefix: '10.1.0.0/24'
    }
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${purpose}-${owner}-${randomSuffix}'
  location: location
  tags: union(tags, {})
  properties: {
    securityRules: [
      {
        name: 'allow-ssh'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '22'
            '2022-2032'
          ]
          sourceAddressPrefixes: allowedIps
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'allow-https'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '80'
          ]
          sourceAddressPrefixes: allowedIps
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1010
          direction: 'Inbound'
        }
      }
      {
        name: 'allow-apiserver'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6443'
          sourceAddressPrefixes: allowedIps
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1020
          direction: 'Inbound'
        }
      }      
      {
        name: 'localloop-apiserver'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6443'
          sourceAddressPrefixes: [
            publicIp.properties.ipAddress
          ]
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1030
          direction: 'Inbound'
          description: 'Allow servers to reach inside the vnet with public IP (ansible playbook requirement)'
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-${purpose}-${owner}-${randomSuffix}'
  location: location
  tags: union(tags, {})
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: '${purpose}-${owner}-${randomSuffix}'
    }
  }
}

resource loadbalancer 'Microsoft.Network/loadBalancers@2024-05-01' = {
  name: 'lb-${purpose}-${owner}-${randomSuffix}'
  location: location
  tags: union(tags, {})
  sku: {
    name: 'Standard'
  }
  properties: {
    outboundRules: [
      {
        name: 'internet-outbound'
        properties: {
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-${purpose}-${owner}-${randomSuffix}', 'control-plane')
          }
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', 'lb-${purpose}-${owner}-${randomSuffix}', 'frontendIp')
            }
          ]
          protocol: 'All'
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'apiserver'
        properties: {
          frontendPort: 6443
          backendPort: 6443
          protocol: 'Tcp'
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'lb-${purpose}-${owner}-${randomSuffix}', 'apiserver-probe')
          }
          disableOutboundSnat: true
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-${purpose}-${owner}-${randomSuffix}', 'control-plane')
          }
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', 'lb-${purpose}-${owner}-${randomSuffix}', 'frontendIp')
          }
        }
      }
      {
        name: 'https'
        properties: {
          frontendPort: 443
          backendPort: 443
          protocol: 'Tcp'
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'lb-${purpose}-${owner}-${randomSuffix}', 'https-probe')
          }
          disableOutboundSnat: true
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-${purpose}-${owner}-${randomSuffix}', 'control-plane')
          }
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', 'lb-${purpose}-${owner}-${randomSuffix}', 'frontendIp')
          }
        }
      }
    ]
    probes: [
      {
        name: 'apiserver-probe'
        properties: {
          protocol: 'Tcp'
          port: 6443
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
      {
        name: 'https-probe'
        properties: {
          protocol: 'Tcp'
          port: 30430
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'control-plane'
        properties: {
          virtualNetwork: {
            id: vnet.id
          }
          syncMode: 'Automatic'
        }
      }
      {
        name: 'worker'
        properties: {
          virtualNetwork: {
            id: vnet.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'frontendIp'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource beControlPlane 'Microsoft.Network/loadBalancers/backendAddressPools@2024-05-01' = {
  name: 'control-plane'
  parent: loadbalancer
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    syncMode: 'Automatic'
  }
}

resource natRule 'Microsoft.Network/loadBalancers/inboundNatRules@2024-05-01' = {
  name: 'nat-ssh-${purpose}-${owner}-${randomSuffix}'
  parent: loadbalancer
  properties: {
    frontendIPConfiguration: {
      id: loadbalancer.properties.frontendIPConfigurations[0].id
    }
    backendAddressPool: {
      id: beControlPlane.id
    }
    backendPort: 22
    frontendPortRangeStart: 2022
    frontendPortRangeEnd: 2032
  }
}

resource controlPlaneVMSS 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' = {
  name: 'vmss-control-plane-${purpose}-${owner}-${randomSuffix}'
  location: location
  tags: union(tags, {})
  sku: {
    capacity: controlPlaneNodeCount
    tier: 'Standard'
    name: controlPlaneNodeSize
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${workloadIdentity.id}': {}
    }
  }
  properties: {
    orchestrationMode: 'Flexible'
    upgradePolicy: {
      mode: 'Manual'
    }
    platformFaultDomainCount: 1
    virtualMachineProfile: {
      
      osProfile: {
        computerNamePrefix: '${purpose}-${owner}-${randomSuffix}'
        adminUsername: username
        adminPassword: password
        linuxConfiguration: {
          disablePasswordAuthentication: authenticationType == 'ssh'
          ssh: authenticationType == 'ssh' ? {
            publicKeys: [
              {
                keyData: sshPublicKey
              }
            ]
          } : null
        }
      }
      networkProfile: {
        networkApiVersion: '2022-11-01'
        networkInterfaceConfigurations: [
          {
            name: 'nic-${purpose}-${owner}-${randomSuffix}'
            properties: {
              networkSecurityGroup: {
                id: nsg.id
              }
              ipConfigurations: [
                {
                  name: 'control-plane'
                  properties: {
                    loadBalancerBackendAddressPools: [
                      {
                        id: beControlPlane.id
                      }
                    ]
                    subnet: {
                      id: vnet::defaultSubnet.id
                    }
                    primary: true
                  }
                }
              ]
            }
          }
        ]
      }
      storageProfile: {
        osDisk: osDisk
        imageReference: imageReference
      }
    }
  }
}


resource workerVMSS 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' = if (workerNodeCount > 0) {
  name: 'vmss-worker-${purpose}-${owner}-${randomSuffix}'
  location: location
  tags: union(tags, {})
  sku: {
    capacity: workerNodeCount
    tier: 'Standard'
    name: workerNodeSize
  }
  properties: {
    orchestrationMode: 'Flexible'
    overprovision: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: '${purpose}-${owner}-${randomSuffix}'
        adminUsername: username
        linuxConfiguration: {
          disablePasswordAuthentication: true
          ssh: {
            publicKeys: [
              {
                keyData: sshPublicKey
              }
            ]
          }
        }
      }
      networkProfile: {
        networkApiVersion: '2022-11-01'
        networkInterfaceConfigurations: [
          {
            name: 'nic-${purpose}-${owner}-${randomSuffix}'
            properties: {
              ipConfigurations: [
                {
                  name: 'worker'
                  properties: {
                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-${purpose}-${owner}-${randomSuffix}', 'worker')
                      }
                    ]
                    subnet: {
                      id: vnet::defaultSubnet.id
                    }
                    primary: true
                  }
                }
              ]
            }
          }
        ]
      }
      storageProfile: {
        osDisk: osDisk
        imageReference: imageReference
      }
    }
  }
}
