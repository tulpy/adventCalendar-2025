import {
  locIds
  resIds
} from '../../configuration/shared/shared.conf.bicep'

using '../../orchestration/platformConnectivity/platformConnectivity-hub.bicep'

var uniqueValue = toLower(uniqueString(subscriptionId, envId))

param lzId = 'plat'
param envId = 'conn'
param locations = [
  'australiaeast' //Primary location
  'australiasoutheast' //Secondary location
]
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
param hubNetworkingConfiguration = [
  {
    name: toLower('${resIds.virtualNetwork}-${locIds[locations[0]]}-${lzId}-${envId}-10.0.0.0_22')
    location: locations[0]
    addressPrefixes: [
      '10.0.0.0/22'
    ]
    dnsServers: []
    deployPeering: true
    peeringSettings: [
      // Only needed if deployPeering is true (hub to Hub)
      {
        remoteVirtualNetworkName: toLower('${resIds.virtualNetwork}-${locIds[locations[1]]}-${lzId}-${envId}-10.10.0.0_22')
        allowForwardedTraffic: true
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        useRemoteGateways: false
      }
    ]
    subnets: [
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.0.0.64/26'
      }
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.0.0.128/27'
      }
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: '10.0.0.0/26'
      }
      {
        name: 'AzureFirewallManagementSubnet'
        addressPrefix: '10.0.0.192/26'
      }
      {
        name: 'DNSPrivateResolverInboundSubnet'
        addressPrefix: '10.0.0.160/28'
        delegation: 'Microsoft.Network/dnsResolvers'
      }
      {
        name: 'DNSPrivateResolverOutboundSubnet'
        addressPrefix: '10.0.0.176/28'
        delegation: 'Microsoft.Network/dnsResolvers'
      }
    ]
    azureFirewallSettings: {
      deployAzureFirewall: false
      azureFirewallName: toLower('${resIds.azureFirewall}-${locIds[locations[0]]}-${lzId}-${envId}-${uniqueValue}')
      azureSkuTier: 'Standard'
      publicIPAddressObject: {
        name: toLower('${resIds.azureFirewall}-${locIds[locations[0]]}-${lzId}-${envId}-azfw')
      }
      threatIntelMode: 'Deny'
      zones: [1, 2, 3]
      dnsProxyEnabled: true
      firewallDnsServers: []
    }
    bastionHostSettings: {
      deployBastion: false
      bastionHostSettingsName: toLower('${resIds.bastionHost}-${locIds[locations[0]]}-${lzId}-${envId}-${uniqueValue}')
      bastionNsgName: toLower('${resIds.networkSecurityGroup}-${locIds[locations[0]]}-${lzId}-${envId}-bastion')
      skuName: 'Standard'
      disableCopyPaste: true
      enableFileCopy: true
      enableIpConnect: true
      enableKerberos: false
      enableShareableLink: false
      scaleUnits: 2
      zones: [1, 2, 3]
    }
    vpnGatewaySettings: {
      deployVpnGateway: false
      name: toLower('${resIds.virtualNetworkGateway}-${locIds[locations[0]]}-${lzId}-${envId}-vpn')
      skuName: 'VpnGw1AZ'
      vpnMode: 'activePassiveNoBgp'
      vpnType: 'RouteBased'
    }
    expressRouteGatewaySettings: {
      deployExpressRouteGateway: false
      name: toLower('${resIds.virtualNetworkGateway}-${locIds[locations[0]]}-${lzId}-${envId}-er')
    }
    privateDnsSettings: {
      deployPrivateDnsZones: false
      deployDnsPrivateResolver: false
      privateDnsResolverName: toLower('${resIds.privateDnsResolver}-${locIds[locations[0]]}-${lzId}-${envId}-${uniqueValue}')
    }
    ddosProtectionPlanSettings: {
      deployDdosProtectionPlan: false
    }
  }
  {
    name: toLower('${resIds.virtualNetwork}-${locIds[locations[1]]}-${lzId}-${envId}-10.10.0.0_22')
    location: locations[1]
    addressPrefixes: [
      '10.10.0.0/22'
    ]
    dnsServers: []
    deployPeering: true
    peeringSettings: [
      // Only needed if deployPeering is true (hub to Hub)
      {
        remoteVirtualNetworkName: toLower('${resIds.virtualNetwork}-${locIds[locations[0]]}-${lzId}-${envId}-10.0.0.0_22')
        allowForwardedTraffic: true
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        useRemoteGateways: false
      }
    ]
    subnets: [
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.10.0.64/26'
      }
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.10.0.128/27'
      }
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: '10.10.0.0/26'
      }
      {
        name: 'AzureFirewallManagementSubnet'
        addressPrefix: '10.10.0.192/26'
      }
      {
        name: 'DNSPrivateResolverInboundSubnet'
        addressPrefix: '10.10.0.160/28'
        delegation: 'Microsoft.Network/dnsResolvers'
      }
      {
        name: 'DNSPrivateResolverOutboundSubnet'
        addressPrefix: '10.10.0.176/28'
        delegation: 'Microsoft.Network/dnsResolvers'
      }
    ]
    azureFirewallSettings: {
      deployAzureFirewall: false
      azureFirewallName: toLower('${resIds.azureFirewall}-${locIds[locations[1]]}-${lzId}-${envId}-${uniqueValue}')
      azureSkuTier: 'Standard'
      publicIPAddressObject: {
        name: toLower('${resIds.azureFirewall}-${locIds[locations[1]]}-${lzId}-${envId}-azfw')
      }
      threatIntelMode: 'Deny'
      zones: [1, 2, 3]
      dnsProxyEnabled: true
      firewallDnsServers: []
    }
    bastionHostSettings: {
      deployBastion: false
      bastionHostSettingsName: toLower('${resIds.bastionHost}-${locIds[locations[1]]}-${lzId}-${envId}-${uniqueValue}')
      bastionNsgName: toLower('${resIds.networkSecurityGroup}-${locIds[locations[1]]}-${lzId}-${envId}-bastion')
      skuName: 'Standard'
      disableCopyPaste: true
      enableFileCopy: true
      enableIpConnect: true
      enableKerberos: false
      enableShareableLink: false
      scaleUnits: 2
      zones: [1, 2, 3]
    }
    vpnGatewaySettings: {
      deployVpnGateway: false
      name: toLower('${resIds.virtualNetworkGateway}-${locIds[locations[1]]}-${lzId}-${envId}-vpn')
      skuName: 'VpnGw1AZ'
      vpnMode: 'activePassiveNoBgp'
      vpnType: 'RouteBased'
    }
    expressRouteGatewaySettings: {
      deployExpressRouteGateway: false
      name: toLower('${resIds.virtualNetworkGateway}-${locIds[locations[1]]}-${lzId}-${envId}-er')
    }
    privateDnsSettings: {
      deployPrivateDnsZones: false
      deployDnsPrivateResolver: false
      privateDnsResolverName: toLower('${resIds.privateDnsResolver}-${locIds[locations[1]]}-${lzId}-${envId}-${uniqueValue}')
    }
    ddosProtectionPlanSettings: {
      deployDdosProtectionPlan: false
    }
  }
]

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
param actionGroupResourceId = '/subscriptions/a50d2a27-93d9-43b1-957c-2a663ffaf37f/resourceGroups/alertsRG/providers/Microsoft.Insights/actiongroups/platmgmtActionGroup'
