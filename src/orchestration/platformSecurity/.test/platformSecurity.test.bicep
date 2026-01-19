targetScope = 'subscription'

@description('Test Deployment for PSRule')
module testDeployment '../platformSecurity.bicep' = {
  name: 'testPlatformSecurityLz'
  params: {
    lzId: 'plat'
    envId: 'sec'
    tags: {
      environment: 'sec'
      applicationName: 'Platform Security Landing Zone'
      owner: 'Security Team'
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
  }
}
