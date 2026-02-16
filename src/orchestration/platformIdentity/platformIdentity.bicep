import {
  locIds
  resIds
  commonResourceGroupNames
  serviceHealthAlerts
} from '../../configuration/shared/shared.conf.bicep'

import {
  // Base Landing Zone User Defined Types
  tagsType
  budgetType
  virtualNetworkType
  keyVaultType
} from '../../configuration/shared/lz.type.bicep'

targetScope = 'subscription'

metadata name = 'Platform Identity Landing Zone - AVM'
metadata description = 'AVM Platform Identity Landing Zone Orchestration.'
metadata version = '1.0.0'
metadata author = 'Insight APAC Platform Engineering'

@minLength(2)
@maxLength(10)
@description('Required. Specifies the Landing Zone Id for the deployment.')
param lzId string

@maxLength(4)
@description('Required. Specifies the environment Id for the deployment.')
param envId string

@description('Optional. Array of locations for reference purposes. This parameter is primarily used in parameter files for convenience when defining hubNetworks array.')
#disable-next-line no-unused-params
param locations array = []

@description('Optional. The Subscription Id for the deployment.')
@maxLength(36)
@minLength(36)
param subscriptionId string = subscription().subscriptionId

@description('Optional. Tags of the resource.')
param tags tagsType?

// Boolean Parameters
@description('Optional. Switch for Azure Budgets.')
param deployBudgets bool = true

@description('Optional. Switch for ADDS.')
param deployAdds bool = true

@description('Optional. Deployment flag for Private Endpoints (network isolation).')
param deployPrivateEndpoints bool = true

@description('Optional. Deployment flag for Private DNS Zone Records (attaching resources to DNS zones via private endpoint configuration).')
param deployPrivateDNSZoneRecords bool = true

// User Defined Type Parameters
@description('Optional. Configuration for Azure Budgets.')
param budgetConfiguration budgetType?

@description('Optional. Configuration for Azure Virtual Network.')
param spokeNetworkingConfiguration virtualNetworkType[]?

@description('Optional. Configuration for Azure Key Vault.')
param keyVaultConfiguration keyVaultType?

// Other Parameters
@description('Optional. Array of Resource IDs for remote virtual networks or virtual hubs to peer with. Must match the number of spokes in spokeNetworks array if provided.')
param hubVirtualNetworkResourceIds string[] = []

@description('Optional. Configuration for Azure Virtual Machines.')
param virtualMachineConfiguration array?

@description('Optional. The Action Group Resource Id to be used for Service Health Alerts.')
param actionGroupResourceId string?

@description('Optional. Local VM password. Must be at least 8 characters if provided.')
@secure()
param vmLocalUserPassword string = ''

@description('Optional. Object of Private DNS Zone resource Ids keyed by zone name. Required if deployPrivateEndpoints is true.')
param privateDnsZoneResourceIds object = {
  keyVault: ''
}

// Orchestration Variables
var udrId = [for location in locations: toLower('${resIds.routeTable}-${locIds[location]}-${lzId}-${envId}')]
var nsgId = [for location in locations: toLower('${resIds.networkSecurityGroup}-${locIds[location]}-${lzId}-${envId}')]
var networkResourceGroups = [
  for location in locations: toLower('${resIds.resourceGroup}-${locIds[location]}-${lzId}-${envId}-network')
]
var addsResourceGroups = [
  for location in locations: toLower('${resIds.resourceGroup}-${locIds[location]}-${lzId}-${envId}-adds')
]

var resourceNames = {
  keyVault: keyVaultConfiguration.?name ?? take(
    toLower('${resIds.resourceGroup}-${locIds[locations[0]]}-${lzId}-${envId}-${uniqueString(subscriptionId)}'),
    24
  )
  networkSecurityPerimeter: take(
    toLower('${resIds.networkSecurityPerimeter}-${locIds[locations[0]]}-${lzId}-${envId}-${uniqueString(subscriptionId)}'),
    24
  )
}

@description('Module: Subscription Tags')
module subscriptionTags '../../modules/tags/subscriptionTags.bicep' = if (!empty(tags)) {
  name: take('subscriptionTags-${guid(deployment().name)}', 64)
  scope: az.subscription(subscriptionId)
  params: {
    tags: tags
  }
}

@description('Module: Azure Budgets - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/consumption/budget')
module budget 'br/public:avm/res/consumption/budget:0.3.8' = [
  for (bg, index) in (budgetConfiguration.?budgets ?? []): if (!empty(budgetConfiguration) && deployBudgets) {
    name: take('budget-${guid(deployment().name)}-${index}', 64)
    scope: az.subscription(subscriptionId)
    params: {
      // Required parameters
      amount: bg.amount
      name: bg.name
      // Non-required parameters
      contactEmails: bg.contactEmails
      location: locations[0]
      startDate: bg.startDate
      thresholdType: bg.thresholdType
      thresholds: bg.thresholds
    }
  }
]

@description('Module: Resource Groups (Common) - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/resources/resource-group')
module commonResourceGroups 'br/public:avm/res/resources/resource-group:0.4.3' = [
  for commonResourceGroup in commonResourceGroupNames: {
    name: take('commonResourceGroups-${commonResourceGroup}', 64)
    scope: az.subscription(subscriptionId)
    params: {
      // Required parameters
      name: commonResourceGroup
      // Non-required parameters
      location: locations[0]
      tags: tags
    }
  }
]

@description('Module: Service Health Alerts - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/subscription/service-health-alerts')
module serviceHealthAlert 'br/public:avm/ptn/subscription/service-health-alerts:0.1.1' = if (!empty(actionGroupResourceId)) {
  name: take('serviceHealthAlerts-${guid(deployment().name)}', 64)
  scope: az.subscription(subscriptionId)
  params: {
    location: locations[0]
    serviceHealthAlerts: [
      for alert in serviceHealthAlerts: {
        actionGroup: {
          enabled: true
          existingActionGroupResourceId: actionGroupResourceId
        }
        serviceHealthAlert: alert
      }
    ]
    serviceHealthAlertsResourceGroupName: 'alertsRG'
    subscriptionId: subscriptionId
    tags: tags
  }
}

@description('Module: Network Watcher - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/network-watcher')
module networkWatcher 'br/public:avm/res/network/network-watcher:0.5.0' = [
  for (location, index) in locations: {
    name: take('networkWatcher-${location}-${guid(deployment().name)}', 64)
    scope: az.resourceGroup(subscriptionId, 'networkWatcherRG')
    dependsOn: [
      commonResourceGroups
    ]
    params: {
      // Non-required parameters
      location: location
      tags: tags
    }
  }
]

@description('Module: Spoke Networking')
module spokeNetworking '../../modules/spokeNetworking/spokeNetworking.bicep' = if (!empty(spokeNetworkingConfiguration)) {
  scope: az.subscription(subscriptionId)
  params: {
    spokeNetworkingResourceGroupNameOverrides: networkResourceGroups
    nsgId: nsgId
    tags: tags
    udrId: udrId
    locations: locations
    spokeNetworks: spokeNetworkingConfiguration ?? []
    hubVirtualNetworkResourceId: hubVirtualNetworkResourceIds
  }
}

@description('Resource Groups (ADDS) - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/resources/resource-group')
module resourceGroupForAdds 'br/public:avm/res/resources/resource-group:0.4.3' = [
  for (location, index) in locations: if (deployAdds) {
    name: take('resourceGroupForAdds-${location}-${guid(deployment().name)}', 64)
    scope: az.subscription(subscriptionId)
    params: {
      // Required parameters
      name: addsResourceGroups[index]
      // Non-required parameters
      location: location
      tags: tags
    }
  }
]

/*
@description('Module: Network Security Perimeter - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/network-security-perimeter')
module networkSecurityPerimeter 'br/public:avm/res/network/network-security-perimeter:0.1.3' = if (deployAdds) {
  name: take('keyVault-${guid(deployment().name)}', 64)
  scope: az.resourceGroup(subscriptionId, addsResourceGroups[0])
  dependsOn: [
    resourceGroupForAdds
  ]
  params: {
    // Required parameters
    name: resourceNames.networkSecurityPerimeter
    // Non-required parameters
    location: locations[0]
    profiles: [
      {
        accessRules: [
          {
            addressPrefixes: [
              '198.168.1.0/24'
            ]
            direction: 'Inbound'
            name: 'rule-inbound-01'
          }
        ]
        name: 'profile-01'
      }
    ]
    resourceAssociations: [
      {
        accessMode: 'Learning'
        privateLinkResource: '<privateLinkResource>'
        profile: 'profile-01'
      }
    ]
    tags: tags
  }
}
*/

@description('Module: Azure Key Vault - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/key-vault/vault')
module vault 'br/public:avm/res/key-vault/vault:0.13.3' = if (deployAdds) {
  name: take('keyVault-${guid(deployment().name)}', 64)
  scope: az.resourceGroup(subscriptionId, addsResourceGroups[0])
  dependsOn: [
    resourceGroupForAdds
  ]
  params: {
    // Required parameters
    name: resourceNames.keyVault
    // Non-required parameters
    enablePurgeProtection: keyVaultConfiguration.?enablePurgeProtection ?? true
    enableSoftDelete: keyVaultConfiguration.?enableSoftDelete ?? true
    location: locations[0]
    networkAcls: !empty(keyVaultConfiguration.?networkAcls ?? {})
      ? {
          bypass: keyVaultConfiguration.?networkAcls.?bypass
          defaultAction: keyVaultConfiguration.?networkAcls.?defaultAction
          virtualNetworkRules: keyVaultConfiguration.?networkAcls.?virtualNetworkRules ?? []
          ipRules: keyVaultConfiguration.?networkAcls.?ipRules ?? []
        }
      : null
    privateEndpoints: deployPrivateEndpoints
    ? [
      {
        privateDnsZoneGroup: deployPrivateDNSZoneRecords && !empty(privateDnsZoneResourceIds.keyVault)
          ? {
              privateDnsZoneGroupConfigs: [
                {
                  privateDnsZoneResourceId: privateDnsZoneResourceIds.keyVault
                }
              ]
            }
          : null
        service: 'vault'
        subnetResourceId: '${spokeNetworking!.outputs.virtualNetworkIds[0]}/subnets/privateEndpoints'
      }
    ]: []
    publicNetworkAccess: !empty(keyVaultConfiguration.?publicNetworkAccess)
      ? keyVaultConfiguration.?publicNetworkAccess
      : ((deployPrivateEndpoints && empty(keyVaultConfiguration.?networkAcls ?? {})) ? 'Disabled' : null)
    roleAssignments: keyVaultConfiguration.?roleAssignments
    secrets: !empty(vmLocalUserPassword)
      ? [
          {
            name: 'vmPassword'
            value: vmLocalUserPassword
            contentType: 'The Azure Virtual Machine ADDS Password Secret'
          }
        ]
      : []
    sku: keyVaultConfiguration.?sku ?? 'premium'
    softDeleteRetentionInDays: keyVaultConfiguration.?softDeleteRetentionInDays ?? 90
    tags: tags
  }
}

@description('Resource: Existing Key Vault')
resource kv 'Microsoft.KeyVault/vaults@2024-11-01' existing = if (deployAdds) {
  scope: az.resourceGroup(subscriptionId, addsResourceGroups[0])
  name: resourceNames.keyVault
}

@description('Module: Virtual Machines for ADDS')
module adds '../../modules/virtualMachine/virtualMachine.bicep' = if (deployAdds && !empty(virtualMachineConfiguration) && (!empty(spokeNetworkingConfiguration))) {
  scope: az.resourceGroup(subscriptionId, addsResourceGroups[0])
  dependsOn: [
    vault
  ]
  params: {
    adminPassword: kv!.getSecret('vmPassword')
    location: locations[0]
    subnetName: 'adds'
    tags: tags
    virtualMachines: virtualMachineConfiguration
    virtualNetworkResourceGroup: spokeNetworking!.outputs.spokeResourceGroupNames[0]
    virtualNetworkName: spokeNetworking!.outputs.virtualNetworkNames[0]
  }
}
