import {
  locIds
  resIds
  commonResourceGroupNames
  serviceHealthAlerts
} from '../../configuration/shared/shared.conf.bicep'

import {
  // Base Landing Zone User Defined Types
  tagsType
  roleAssignmentsType
  budgetType
  actionGroupType
  virtualNetworkType
  storageAccountType
} from '../../configuration/shared/lz.type.bicep'

import {
  // Logging User Defined Types
  logAnalyticsType
} from '../../configuration/shared/logging.type.bicep'

targetScope = 'subscription'

metadata name = 'Platform Management Landing Zone - AVM'
metadata description = 'AVM Platform Management Landing Zone Orchestration.'
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
@description('Optional. Supply an array of objects containing the details of the role assignments to create.')
param roleAssignments roleAssignmentsType?

@description('Optional. Configuration for Log Analytics.')
param logAnalyticsConfiguration logAnalyticsType?

@description('Optional. Configuration for Azure Storage Account.')
param storageAccountConfiguration storageAccountType?

@description('Optional. Configuration for Azure Budgets.')
param budgetConfiguration budgetType?

@description('Optional. Configuration for Action Groups.')
param actionGroupConfiguration actionGroupType?

@description('Optional. Configuration for Azure Virtual Network.')
param spokeNetworkingConfiguration virtualNetworkType[]?

// Other Parameters
@description('Optional. Array of Resource IDs for remote virtual networks or virtual hubs to peer with. Must match the number of spokes in spokeNetworks array if provided.')
param hubVirtualNetworkResourceIds string[] = []

// Orchestration Variables
var udrId = [for location in locations: toLower('${resIds.routeTable}-${locIds[location]}-${lzId}-${envId}')]
var nsgId = [for location in locations: toLower('${resIds.networkSecurityGroup}-${locIds[location]}-${lzId}-${envId}')]
var argId = toLower('${resIds.resourceGroup}-${locIds[locations[0]]}-${lzId}-${envId}')
var lawId = toLower('${resIds.logAnalytics}-${locIds[locations[0]]}-${lzId}-${envId}')
var aaaId = toLower('${resIds.azureAutomationAccount}-${locIds[locations[0]]}-${lzId}-${envId}')
var staId = toLower('${resIds.storageAccount}${locIds[locations[0]]}${lzId}${envId}')
var dcrId = toLower('${resIds.dataCollectionRule}-${locIds[locations[0]]}-${lzId}-${envId}')
var uaiId = toLower('${resIds.userAssignedIdentity}-${locIds[locations[0]]}-${lzId}-${envId}')

var networkResourceGroups = [
  for location in locations: toLower('${resIds.resourceGroup}-${locIds[location]}-${lzId}-${envId}-network')
]

var resourceGroups = {
  logging: '${argId}-logging'}

var resourceNames = {
  actionGroup: '${resIds.platform}${resIds.platformMgmt}ActionGroup'
  actionGroupShort: '${resIds.platform}AG'
  automationAccount: '${aaaId}-${uniqueString(subscriptionId)}'
  dcrCT: '${dcrId}-changetracking'
  dcrMDFCSQL: '${dcrId}-mdfcsql'
  dcrVMInsights: '${dcrId}-vminsights'
  logAnalyticsWorkspace: logAnalyticsConfiguration.?name ?? take('${lawId}-${uniqueString(subscriptionId)}', 24)
  storageAccount: storageAccountConfiguration.?name ?? take('${staId}${uniqueString(subscriptionId)}', 24)
  userAssignedIdentityAMA: '${uaiId}-ama'
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

@description('Resource: Role Assignments')
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for assignment in (roleAssignments ?? []): if (!empty(roleAssignments)) {
    name: take(guid(subscriptionId, assignment.principalId, assignment.roleDefinitionIdOrName), 64)
    properties: {
      roleDefinitionId: assignment.roleDefinitionIdOrName
      principalId: assignment.principalId
      principalType: assignment.principalType
    }
  }
]

@description('Module: Action Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/insights/action-group')
module actionGroup 'br/public:avm/res/insights/action-group:0.8.0' = if (!empty(actionGroupConfiguration.?emailReceivers)) {
  name: take('actionGroup-${guid(deployment().name)}', 64)
  scope: az.resourceGroup(subscriptionId, 'alertsRG')
  dependsOn: [
    commonResourceGroups
  ]
  params: {
    // Required parameters
    groupShortName: resourceNames.actionGroupShort
    name: resourceNames.actionGroup
    // Non-required parameters
    emailReceivers: [
      for email in actionGroupConfiguration.?emailReceivers ?? []: {
        emailAddress: email
        name: split(email, '@')[0]
        useCommonAlertSchema: true
      }
    ]
    location: 'Global'
    tags: tags
  }
}

@description('Module: Service Health Alerts - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/subscription/service-health-alerts')
module serviceHealthAlert 'br/public:avm/ptn/subscription/service-health-alerts:0.1.1' = if (!empty(actionGroupConfiguration.?emailReceivers)) {
  name: take('serviceHealthAlerts-${guid(deployment().name)}', 64)
  scope: az.subscription(subscriptionId)
  params: {
    location: locations[0]
    serviceHealthAlerts: [
      for alert in serviceHealthAlerts: {
        actionGroup: {
          enabled: true
          existingActionGroupResourceId: actionGroup!.outputs.resourceId
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

@description('Module: Logging')
module logging '../../modules/logging/logging.bicep' = {
  name: take('logging-${guid(deployment().name)}', 64)
  scope: az.subscription(subscriptionId)
  params: {
    parLocations: locations
    parAutomationAccountName: resourceNames.automationAccount
    parMgmtLoggingResourceGroup: resourceGroups.logging
    parLogAnalyticsWorkspaceName: resourceNames.logAnalyticsWorkspace
    parLogAnalyticsWorkspaceSku: logAnalyticsConfiguration.?skuName ?? 'PerGB2018'
    parLogAnalyticsWorkspaceLocation: locations[0]
    parLogAnalyticsWorkspaceLogRetentionInDays: logAnalyticsConfiguration.?dataRetention ?? 30
    parLogAnalyticsWorkspaceDailyQuotaGb: logAnalyticsConfiguration.?dailyQuotaGb ?? -1
    parLogAnalyticsWorkspaceFeatures: {
      enableLogAccessUsingOnlyResourcePermissions: logAnalyticsConfiguration.?features.?enableLogAccessUsingOnlyResourcePermissions ?? true
      disableLocalAuth: logAnalyticsConfiguration.?features.?disableLocalAuth ?? true
      enableDataExport: logAnalyticsConfiguration.?features.?enableDataExport
      immediatePurgeDataOn30Days: logAnalyticsConfiguration.?features.?immediatePurgeDataOn30Days
    }
    parLogAnalyticsWorkspaceReplication: logAnalyticsConfiguration.?replication.enabled == true
      ? {
          enabled: logAnalyticsConfiguration.?replication.enabled
          location: logAnalyticsConfiguration.?replication.location
        }
      : null
    parDataCollectionRuleChangeTrackingName: resourceNames.dcrCT
    parDataCollectionRuleMDFCSQLName: resourceNames.dcrMDFCSQL
    parDataCollectionRuleVMInsightsName: resourceNames.dcrVMInsights
    parUserAssignedIdentityName: resourceNames.userAssignedIdentityAMA
    parLogAnalyticsWorkspaceCapacityReservationLevel: logAnalyticsConfiguration.?skuName == 'CapacityReservation'
      ? logAnalyticsConfiguration.?skuCapacityReservationLevel
      : null
    parTags: tags
  }
}

@description('Module: Storage Account - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/storage/storage-account')
module storageAccount 'br/public:avm/res/storage/storage-account:0.31.0' = {
  scope: az.resourceGroup(subscriptionId, resourceGroups.logging)
  name: take('storageAccount-${guid(deployment().name)}', 64)
  dependsOn: [
    logging
  ]
  params: {
    // Required parameters
    name: resourceNames.storageAccount
    // Non-required parameters
    accessTier: storageAccountConfiguration.?accessTier ?? 'Hot'
    allowBlobPublicAccess: storageAccountConfiguration.?allowBlobPublicAccess ?? false
    allowSharedKeyAccess: storageAccountConfiguration.?allowSharedKeyAccess ?? false
    defaultToOAuthAuthentication: !(storageAccountConfiguration.?allowSharedKeyAccess ?? true)
    managedIdentities: {
      systemAssigned: true
    }
    kind: storageAccountConfiguration.?kind ?? 'StorageV2'
    location: locations[0]
    minimumTlsVersion: storageAccountConfiguration.?minimumTlsVersion ?? 'TLS1_2'
    networkAcls: storageAccountConfiguration.?networkAcls ?? {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    publicNetworkAccess: storageAccountConfiguration.?publicNetworkAccess ?? 'Enabled'
    skuName: storageAccountConfiguration.?sku ?? 'Standard_ZRS'
    supportsHttpsTrafficOnly: storageAccountConfiguration.?supportsHttpsTrafficOnly ?? true
    tags: tags
  }
}
