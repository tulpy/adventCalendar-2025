targetScope = 'subscription'

metadata name = 'Test and Validation Deployment'
metadata description = 'Test and Validation of the Platform Management Orchestration Module.'

param lzId string = 'plat'
param envId string = 'mgmt'

@description('Test Deployment for PSRule')
module testDeployment '../platformManagement.bicep' = {
  name: take('testDeployment-${guid(deployment().name)}', 64)
  params: {
    lzId: lzId
    envId: envId
    tags: {
      environment: envId
      applicationName: 'Platform Management Landing Zone'
      owner: 'Platform Team'
      criticality: 'Tier0'
      costCenter: '1234'
      contactEmail: 'test@outlook.com'
      dataClassification: 'Internal'
      iac: 'Bicep'
    }
    locations: [
      'australiaeast' //Primary location
      'australiasoutheast' //Secondary location
    ]
    budgetConfiguration: {
      budgets: [
        {
          name: 'budget-forecasted'
          amount: 500
          startDate: '2026-01-01T00:00:00Z' // Date cant be in the past
          thresholdType: 'Forecasted'
          thresholds: [
            90
            100
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
    actionGroupConfiguration: {
      emailReceivers: [
        'test@outlook.com'
      ]
    }
    logAnalyticsConfiguration: {
      dataRetention: 90
      skuName: 'PerGB2018'
    }
  }
}
