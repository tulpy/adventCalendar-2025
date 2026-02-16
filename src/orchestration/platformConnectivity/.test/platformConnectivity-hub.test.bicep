targetScope = 'subscription'

metadata name = 'Test and Validation Deployment'
metadata description = 'Test and Validation of the Platform Connectivity Orchestration Module.'

param lzId string = 'plat'
param envId string = 'conn'

@description('Test Deployment for PS-Rule')
module testDeployment '../platformConnectivity-hub.bicep' = {
  name: take('testDeployment-${guid(deployment().name)}', 64)
  params: {
    lzId: lzId
    envId: envId
    hubNetworkingConfiguration: [
      {
        name: 'hub-connectivity'
        location: 'australiaeast' //Primary location
        addressPrefixes: [
          '10.0.0.0/22'
        ]
        dnsServers: []
        deployPeering: true
        peeringSettings: [
          // Only needed if deployPeering is true (hub to Hub)
          {
            remoteVirtualNetworkName: 'spoke-identity'
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
          azureFirewallName: 'hub-firewall'
          azureSkuTier: 'Standard'
          publicIPAddressObject: {
            name: 'hub-firewall-pip'
          }
          threatIntelMode: 'Deny'
          zones: [1, 2, 3]
          dnsProxyEnabled: true
          firewallDnsServers: []
        }
        bastionHostSettings: {
          deployBastion: false
          bastionHostSettingsName: 'hub-bastion'
          bastionNsgName: 'hub-bastion-nsg'
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
          name: 'hub-vpn'
          skuName: 'VpnGw1AZ'
          vpnMode: 'activePassiveNoBgp'
          vpnType: 'RouteBased'
        }
        expressRouteGatewaySettings: {
          deployExpressRouteGateway: false
          name: 'hub-er'
        }
        privateDnsSettings: {
          deployPrivateDnsZones: false
          deployDnsPrivateResolver: false
          privateDnsResolverName: 'hub-private-dns-resolver'
        }
        ddosProtectionPlanSettings: {
          deployDdosProtectionPlan: false
        }
      }
    ]
    tags: {
      environment: envId
      applicationName: 'Platform Connectivity Landing Zone'
      owner: 'Platform Team'
      criticality: 'Tier1'
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
  }
}
