import {
  locIds
  resIds
} from '../../configuration/shared/shared.conf.bicep'

using '../../orchestration/platformManagement/platformManagement.bicep'

param lzId = 'plat'
param envId = 'mgmt'
param locations = [
  'australiaeast'
]
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
param spokeNetworkingConfiguration = [
  {
    name: toLower('${resIds.virtualNetwork}-${locIds[locations[0]]}-${lzId}-${envId}-01')
    location: locations[0]
    addressPrefixes: [
      '/subscriptions/5cb7efe0-67af-4723-ab35-0f2b42a85839/resourceGroups/arg-aue-plat-conn-network/providers/Microsoft.Network/networkManagers/avnm-aue-plat-conn-01/ipamPools/applicationIpamPool-australiaeast'
    ]
    ipamPoolNumberOfIpAddresses: '254'
    dnsServers: [
      '10.0.6.4'
      '10.0.6.5'
    ]
    deployPeering: true
    peeringSettings: {
      allowForwardedTraffic: true
      allowGatewayTransit: false
      allowVirtualNetworkAccess: true
      useRemoteGateways: false
    }
    hubVirtualNetworkResourceId: hubVirtualNetworkResourceIds[0]
    subnets: [
      {
        name: 'jumphost'
        ipamPoolPrefixAllocations: [
          {
            numberOfIpAddresses: '64'
            pool: {
              id: '/subscriptions/5cb7efe0-67af-4723-ab35-0f2b42a85839/resourceGroups/arg-aue-plat-conn-network/providers/Microsoft.Network/networkManagers/avnm-aue-plat-conn-01/ipamPools/applicationIpamPool-australiaeast'
            }
          }
        ]
        defaultOutboundAccess: false
        routes: []
        securityRules: []
        privateEndpointNetworkPolicies: 'Enabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    ]
  }
]
param hubVirtualNetworkResourceIds = [
  '/subscriptions/5cb7efe0-67af-4723-ab35-0f2b42a85839/resourceGroups/arg-aue-plat-conn-network/providers/Microsoft.Network/virtualNetworks/vnt-aue-plat-conn-10.0.0.0_22'
]
param logAnalyticsConfiguration = {
  dataRetention: 90
  skuName: 'PerGB2018'
  replication: {
    enabled: false
    location: 'australiasoutheast'
  }
}
