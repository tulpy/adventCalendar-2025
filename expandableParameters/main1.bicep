targetScope = 'subscription'

@description('Prefix for Resource Group.')
param rgPrefix string

@description('Location for all resources.')
param location string

@description('Tag to apply to all resources.')
param tags object = {}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: '${rgPrefix}-test'
  location: location
  tags: tags
}
