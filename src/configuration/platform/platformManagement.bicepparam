using '../../orchestration/platformManagement/platformManagement.bicep'

param lzId = 'plat'
param envId = 'mgmt'
param subscriptionId = 'a50d2a27-93d9-43b1-957c-2a663ffaf37f'
param tags = {
  environment: envId
  applicationName: 'Platform Management Landing Zone'
  owner: 'Platform Team'
  criticality: 'Tier0'
  costCenter: '1234'
  contactEmail: 'test@outlook.com'
  dataClassification: 'Internal'
  iac: 'Bicep'
}
param subscriptionManagementGroupAssociationEnabled = false
param subscriptionMgPlacement = 'mg-alz-platform-management'
param deployBudgets = true
param budgetConfiguration = {
  budgets: [
    {
      name: 'budget-forecasted'
      amount: 500
      startDate: '2026-01-01T00:00:00Z' // Date cant be in the past
      thresholdType: 'Forecasted'
      thresholds: [
        90
      ]
      contactEmails: [
        'test@outlook.com'
      ]
    }
    {
      name: 'budget-actual'
      amount: 500
      startDate: '2026-01-01T00:00:00Z' // Date cant be in the past
      thresholdType: 'Actual'
      thresholds: [
        95
        100
      ]
      contactEmails: [
        'test@outlook.com'
      ]
    }
  ]
}
param actionGroupConfiguration = {
  emailReceivers: [
    'test@outlook.com'
  ]
}
param logAnalyticsConfiguration = {
  dataRetention: 90
  skuName: 'PerGB2018'
  replication: {
    enabled: false
    location: 'australiasoutheast'
  }
}
