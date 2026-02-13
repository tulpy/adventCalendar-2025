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
} from '../../configuration/shared/lz.type.bicep'

import {
  // Hub Networking User Defined Types
  hubVirtualNetworkType
} from '../../configuration/shared/hub.type.bicep'

targetScope = 'subscription'

metadata name = 'Platform Connectivity Landing Zone - AVM'
metadata description = 'Platform Connectivity Landing Zone Orchestration.'
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

// User Defined Type Parameters
@description('Optional. Configuration for Azure Budgets.')
param budgetConfiguration budgetType?

@description('Required. Specifies the list of Azure Regions to deploy the Hub resources into.')
param hubNetworkingConfiguration hubVirtualNetworkType

@description('Optional. The Action Group Resource Id to be used for Service Health Alerts.')
param actionGroupResourceId string?

var networkResourceGroups = [
  for location in locations: toLower('${resIds.resourceGroup}-${locIds[location]}-${lzId}-${envId}-network')
]
var privateDnsResourceGroups = [
  for location in locations: toLower('${resIds.resourceGroup}-${locIds[location]}-${lzId}-${envId}-privatedns')
]
var privateDnsResolverResourceGroups = [
  for location in locations: toLower('${resIds.resourceGroup}-${locIds[location]}-${lzId}-${envId}-privatednsresolver')
]

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

@description('Module: Hub Networking')
module hubNetworking '../../modules/hubNetworking/hubNetworking.bicep' = {
  name: take('hubNetworking-${guid(deployment().name)}', 64)
  params: {
    parHubNetworkingResourceGroupNameOverrides: networkResourceGroups
    parDnsResourceGroupNameOverrides: privateDnsResourceGroups
    parDnsPrivateResolverResourceGroupNameOverrides: privateDnsResolverResourceGroups
    parTags: tags
    parLocations: locations
    hubNetworks: hubNetworkingConfiguration
  }
}
