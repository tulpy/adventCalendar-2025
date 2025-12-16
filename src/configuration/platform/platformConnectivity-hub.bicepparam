using '../../orchestration/platformConnectivity/platformConnectivity-hub.bicep'

param lzId = 'plat'
param envId = 'conn'
param subscriptionId = '5cb7efe0-67af-4723-ab35-0f2b42a85839'
param tags = {
  environment: envId
  applicationName: 'Platform Connectivity Landing Zone'
  owner: 'Platform Team'
  criticality: 'Tier0'
  costCenter: '1234'
  contactEmail: 'test@outlook.com'
  dataClassification: 'Internal'
  iac: 'Bicep'
}
param subscriptionManagementGroupAssociationEnabled = false
param subscriptionMgPlacement = 'mg-alz-platform-connectivity'
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
param addressPrefixes = [
  '10.52.0.0/16'
]
param subnetsArray = [
  {
    name: 'AzureBastionSubnet'
    ipAddressRange: '10.52.0.0/26'
    networkSecurityGroupId: ''
    routeTableId: ''
  }
  {
    name: 'GatewaySubnet'
    ipAddressRange: '10.52.0.64/26'
    networkSecurityGroupId: ''
    routeTableId: ''
  }
  {
    name: 'AzureFirewallSubnet'
    ipAddressRange: '10.52.0.128/26'
    networkSecurityGroupId: ''
    routeTableId: ''
  }
  {
    name: 'inboundDNSSubnet'
    ipAddressRange: '10.52.0.192/27'
    delegation: 'Microsoft.Network/dnsResolvers'
  }
  {
    name: 'outboundDNSSubnet'
    ipAddressRange: '10.52.0.224/27'
    delegation: 'Microsoft.Network/dnsResolvers'
  }
]
param azFirewallEnabled = false
param erGwyEnabled = false
param vpnGwyEnabled = false
param azBastionEnabled = false
param privateResolverEnabled = true
param actionGroupResourceId = '/subscriptions/a50d2a27-93d9-43b1-957c-2a663ffaf37f/resourceGroups/alertsRG/providers/Microsoft.Insights/actiongroups/platmgmtActionGroup'
