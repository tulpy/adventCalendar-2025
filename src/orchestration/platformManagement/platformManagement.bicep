import * as shared from '../../configuration/shared/shared.conf.bicep'

import {
  // Platform Landing Zone User Defined Types
  logAnalyticsType
} from '../../configuration/shared/platform.type.bicep'

import {
  // Base Landing Zone User Defined Types
  tagsType
  budgetType
  actionGroupType
  storageAccountType
} from '../../configuration/shared/lz.type.bicep'

targetScope = 'managementGroup'

metadata name = 'Platform Management Landing Zone - Azure Orchestration Module'
metadata description = 'Platform Management Landing Zone deployment.'
metadata version = '1.0.0'
metadata author = 'Insight APAC Platform Engineering'

@maxLength(10)
@description('Required. Specifies the Landing Zone Id for the deployment.')
param lzId string

@maxLength(4)
@description('Required. Specifies the environment Id for the deployment.')
param envId string

@description('Optional. The Azure Region to deploy the resources into.')
param location string = deployment().location

@description('Required. The Subscription Id for the deployment.')
@maxLength(36)
@minLength(36)
param subscriptionId string

@description('Optional. Tags of the resource.')
param tags tagsType?

@description('Optional. Whether to move the Subscription to the specified Management Group supplied in the parameter `subscriptionManagementGroupId`.')
param subscriptionManagementGroupAssociationEnabled bool = true

@maxLength(90)
@description('Optional. The Management Group Id to place the subscription in.')
param subscriptionMgPlacement string = ''

@description('Optional. Configuration for Log Analytics.')
param logAnalyticsConfiguration logAnalyticsType?

@description('Optional. Configuration for Azure Storage Account.')
param storageAccountConfiguration storageAccountType?

@description('Optional. Switch for Azure Budgets.')
param deployBudgets bool = true

@description('Optional. Configuration for Azure Budgets.')
param budgetConfiguration budgetType?

@description('Optional. Configuration for Action Groups.')
param actionGroupConfiguration actionGroupType?

// Orchestration Variables
var argId = toLower('${shared.resIds.resourceGroup}-${shared.locIds[location]}-${lzId}-${envId}')
var lawId = toLower('${shared.resIds.logAnalytics}-${shared.locIds[location]}-${lzId}-${envId}')
var staId = toLower('${shared.resIds.storageAccount}${shared.locIds[location]}${lzId}${envId}')
var dcrId = toLower('${shared.resIds.dataCollectionRule}-${shared.locIds[location]}-${lzId}-${envId}')
var uaiId = toLower('${shared.resIds.userAssignedIdentity}-${shared.locIds[location]}-${lzId}-${envId}')

var resourceGroups = {
  logging: '${argId}-logging'
}

var resourceNames = {
  logAnalyticsWorkspace: '${lawId}-${uniqueString(subscriptionId)}'
  storageAccount: storageAccountConfiguration.?name ?? take('${staId}${uniqueString(subscriptionId)}', 24)
  dcrVMInsights: '${dcrId}-vminsights'
  dcrCT: '${dcrId}-changetracking'
  dcrMDFCSQL: '${dcrId}-mdfcsql'
  actionGroup: '${shared.resIds.platform}${shared.resIds.platformMgmt}ActionGroup'
  actionGroupShort: '${shared.resIds.platform}AG'
  userAssignedIdentityAMA: '${uaiId}-ama'
}

@description('Resource: Subscription Placement - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/mgmt-groups/subscription-placement')
module subscriptionPlacement 'br/public:avm/ptn/mgmt-groups/subscription-placement:0.3.0' = if (subscriptionManagementGroupAssociationEnabled && !empty(subscriptionMgPlacement)) {
  name: take('subscriptionPlacement-${guid(deployment().name)}', 64)
  scope: tenant()
  params: {
    parSubscriptionPlacement: [
      {
        disableSubscriptionPlacement: false
        managementGroupId: subscriptionMgPlacement
        subscriptionIds: [
          subscriptionId
        ]
      }
    ]
  }
}

@description('Module: Subscription Tags')
module subscriptionTags '../../modules/tags/subscriptionTags.bicep' = if (!empty(tags)) {
  name: take('subscriptionTags-${guid(deployment().name)}', 64)
  scope: subscription(subscriptionId)
  params: {
    tags: tags
  }
}

@description('Module: Azure Budgets - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/consumption/budget')
module budget 'br/public:avm/res/consumption/budget:0.3.8' = [
  for (bg, index) in (budgetConfiguration.?budgets ?? []): if (!empty(budgetConfiguration) && deployBudgets) {
    name: take('budget-${guid(deployment().name)}-${index}', 64)
    scope: subscription(subscriptionId)
    params: {
      // Required parameters
      amount: bg.amount
      name: bg.name
      // Non-required parameters
      contactEmails: bg.contactEmails
      location: location
      startDate: bg.startDate
      thresholdType: bg.thresholdType
      thresholds: bg.thresholds
    }
  }
]

@description('Module: Resource Group (Common) - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/resources/resource-group')
module commonResourceGroups 'br/public:avm/res/resources/resource-group:0.4.3' = [
  for commonResourceGroup in shared.commonResourceGroupNames: {
    name: take('commonResourceGroups-${commonResourceGroup}', 64)
    scope: subscription(subscriptionId)
    params: {
      // Required parameters
      name: commonResourceGroup
      // Non-required parameters
      location: location
      tags: tags
    }
  }
]

@description('Module: Resource Group (Logging) - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/resources/resource-group')
module resourceGroupForLogging 'br/public:avm/res/resources/resource-group:0.4.3' = {
  scope: subscription(subscriptionId)
  name: 'resourceGroupForLogging-${guid(deployment().name)}'
  params: {
    // Required parameters
    name: resourceGroups.logging
    // Non-required parameters
    location: location
    tags: tags
  }
}

@description('Module: Action Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/insights/action-group')
module actionGroup 'br/public:avm/res/insights/action-group:0.8.0' = if (!empty(actionGroupConfiguration.?emailReceivers)) {
  name: take('actionGroup-${guid(deployment().name)}', 64)
  scope: resourceGroup(subscriptionId, 'alertsRG')
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

@description('Module: Storage Account - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/storage/storage-account')
module storageAccount 'br/public:avm/res/storage/storage-account:0.30.0' = {
  scope: resourceGroup(subscriptionId, resourceGroups.logging)
  name: take('storageAccount-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    name: resourceNames.storageAccount
    // Non-required parameters
    accessTier: storageAccountConfiguration.?accessTier ?? 'Hot'
    allowBlobPublicAccess: storageAccountConfiguration.?allowBlobPublicAccess ?? false
    allowSharedKeyAccess: storageAccountConfiguration.?allowSharedKeyAccess ?? false
    blobServices: {
      containerDeleteRetentionPolicyDays: storageAccountConfiguration.?containerDeleteRetentionPolicyDays ?? 7
      containerDeleteRetentionPolicyEnabled: storageAccountConfiguration.?containerDeleteRetentionPolicyEnabled ?? true
      deleteRetentionPolicyDays: storageAccountConfiguration.?deleteRetentionPolicyDays ?? 7
      deleteRetentionPolicyEnabled: storageAccountConfiguration.?deleteRetentionPolicyEnabled ?? true
    }
    defaultToOAuthAuthentication: !(storageAccountConfiguration.?allowSharedKeyAccess ?? true)
    managedIdentities: {
      systemAssigned: true
    }
    kind: storageAccountConfiguration.?kind ?? 'StorageV2'
    location: location
    minimumTlsVersion: storageAccountConfiguration.?minimumTlsVersion ?? 'TLS1_2'
    networkAcls: storageAccountConfiguration.?networkAcls ?? {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    publicNetworkAccess: storageAccountConfiguration.?publicNetworkAccess ?? 'Enabled'
    skuName: storageAccountConfiguration.?skuName ?? 'Standard_ZRS'
    supportsHttpsTrafficOnly: storageAccountConfiguration.?supportsHttpsTrafficOnly ?? true
    tags: tags
  }
}

@description('Module: Service Health Alerts - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/subscription/service-health-alerts')
module serviceHealthAlerts 'br/public:avm/ptn/subscription/service-health-alerts:0.1.1' = {
  name: take('serviceHealthAlerts-${guid(deployment().name)}', 64)
  scope: subscription(subscriptionId)
  params: {
    location: location
    serviceHealthAlerts: [
      for alert in shared.serviceHealthAlerts: {
        actionGroup: {
          enabled: true
          existingActionGroupResourceId: actionGroup.?outputs.resourceId ?? ''
        }
        serviceHealthAlert: alert
      }
    ]
    serviceHealthAlertsResourceGroupName: 'alertsRG'
    subscriptionId: subscriptionId
    tags: tags
  }
}

@description('Module: Log Analytics Workspace - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/operational-insights/workspace')
module workspace 'br/public:avm/res/operational-insights/workspace:0.14.2' = {
  scope: resourceGroup(subscriptionId, resourceGroups.logging)
  name: take('workspace-${guid(deployment().name)}', 64)
  dependsOn: [
    resourceGroupForLogging
  ]
  params: {
    // Required parameters
    name: resourceNames.logAnalyticsWorkspace
    // Non-required parameters
    dailyQuotaGb: logAnalyticsConfiguration.?dailyQuotaGb ?? -1
    features: {
      enableLogAccessUsingOnlyResourcePermissions: logAnalyticsConfiguration.?features.?enableLogAccessUsingOnlyResourcePermissions ?? true
      disableLocalAuth: logAnalyticsConfiguration.?features.?disableLocalAuth ?? true
      enableDataExport: logAnalyticsConfiguration.?features.?enableDataExport
      immediatePurgeDataOn30Days: logAnalyticsConfiguration.?features.?immediatePurgeDataOn30Days
    }
    dataRetention: logAnalyticsConfiguration.?dataRetention ?? 30
    location: location
    managedIdentities: {
      systemAssigned: true
    }
    publicNetworkAccessForIngestion: logAnalyticsConfiguration.?publicNetworkAccessForIngestion ?? 'Enabled'
    publicNetworkAccessForQuery: logAnalyticsConfiguration.?publicNetworkAccessForQuery ?? 'Enabled'
    replication: logAnalyticsConfiguration.?replication.enabled == true
      ? {
          enabled: logAnalyticsConfiguration.?replication.enabled
          location: logAnalyticsConfiguration.?replication.location
        }
      : null
    skuName: logAnalyticsConfiguration.?skuName ?? 'PerGB2018'
    skuCapacityReservationLevel: logAnalyticsConfiguration.?skuName == 'CapacityReservation'
      ? logAnalyticsConfiguration.?skuCapacityReservationLevel
      : null
    tags: tags
  }
}

@description('Module: Azure Monitor Agent - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/alz/ama')
module ama 'br/public:avm/ptn/alz/ama:0.1.1' = {
  name: take('ama-${guid(deployment().name)}', 64)
  scope: resourceGroup(subscriptionId, resourceGroups.logging)
  params: {
    // Required parameters
    dataCollectionRuleChangeTrackingName: resourceNames.dcrCT
    dataCollectionRuleMDFCSQLName: resourceNames.dcrMDFCSQL
    dataCollectionRuleVMInsightsName: resourceNames.dcrVMInsights
    logAnalyticsWorkspaceResourceId: workspace.outputs.resourceId
    userAssignedIdentityName: resourceNames.userAssignedIdentityAMA
    // Non-required parameters
    location: location
    tags: tags
  }
}
