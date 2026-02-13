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
} from '../../configuration/shared/lz.type.bicep'

targetScope = 'subscription'

metadata name = 'Platform Security Landing Zone - AVM'
metadata description = 'AVM Platform Security Landing Zone Orchestration.'
metadata version = '0.1.0'
metadata author = 'Insight APAC Platform Engineering'

@minLength(2)
@maxLength(10)
@description('Required. Specifies the Landing Zone Id for the deployment.')
param lzId string

@maxLength(4)
@description('Required. Specifies the environment Id for the deployment.')
param envId string

@description('Required. Array of locations for reference purposes. This parameter is primarily used in parameter files for convenience.')
param locations array

@description('Optional. The Subscription Id for the deployment.')
@maxLength(36)
@minLength(36)
param subscriptionId string = subscription().subscriptionId

@description('Optional. Tags of the resource.')
param tags tagsType?

// Boolean Parameters
@description('Optional. Switch for Azure Budgets.')
param deployBudgets bool = true

// User Defined Type Parameters
@description('Optional. Configuration for Azure Budgets.')
param budgetConfiguration budgetType?

@description('Optional. The Action Group Resource Id to be used for Service Health Alerts.')
param actionGroupResourceId string?

@description('Optional. Configuration for Azure Virtual Network.')
param spokeNetworkingConfiguration virtualNetworkType[]?

@description('Optional. Array of Resource IDs for remote virtual networks or virtual hubs to peer with. Must match the number of spokes in spokeNetworks array if provided.')
param hubVirtualNetworkResourceIds string[] = []

// Orchestration Variables
var udrId = [for location in locations: toLower('${resIds.routeTable}-${locIds[location]}-${lzId}-${envId}')]
var nsgId = [for location in locations: toLower('${resIds.networkSecurityGroup}-${locIds[location]}-${lzId}-${envId}')]
//var argId = toLower('${resIds.resourceGroup}-${locIds[locations[0]]}-${lzId}-${envId}')

var networkResourceGroups = [
  for location in locations: toLower('${resIds.resourceGroup}-${locIds[location]}-${lzId}-${envId}-network')
]

/* Update when the Setinel module is available
var resourceGroups = {
  sentinel: '${argId}-sentinel'
}
*/

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
