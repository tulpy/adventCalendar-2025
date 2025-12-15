targetScope = 'managementGroup'

@description('Test Deployment for Azure Platform Management Landing Zone')
module testPlatformConnLz '../platformManagement.bicep' = {
  name: 'testPlatformMgmtLz'
  params: {
    lzId: 'plat'
    envId: 'mgmt'
    subscriptionId: 'a50d2a27-93d9-43b1-957c-2a663ffaf37f'
    subscriptionMgPlacement: 'mg-alz-platform-management'
    tags: {
      environment: 'mgmt'
      applicationName: 'Platform Management Landing Zone'
      owner: 'Platform Team'
      criticality: 'Tier0'
      costCenter: '1234'
      contactEmail: 'test@outlook.com'
      dataClassification: 'Internal'
      iac: 'Bicep'
    }
    budgetConfiguration: {
      budgets: [
        {
          name: 'budget-forecasted'
          amount: 500
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
