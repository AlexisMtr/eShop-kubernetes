using './main.bicep'

param location = 'francecentral'
param owner = 'ama3694'
param purpose = 'formation'
param vmssPassword = readEnvironmentVariable('ESHOP_VM_PASSWORD', '')
param sshPublicKey = ''
param whitelistIps = []
param identities = []
