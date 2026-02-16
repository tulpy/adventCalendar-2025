metadata name = 'ALZ Bicep Accelerator - Hub Networking'
metadata description = 'Used to deploy hub networking resources for ALZ.'

targetScope = 'subscription'

//========================================
// Parameters
//========================================

// Resource Group Parameters
@description('Optional. The prefix for the Hub Networking Resource Group names. Will be combined with location to create: {prefix}-{location}. Can be overridden by parHubNetworkingResourceGroupNameOverrides.')
param parHubNetworkingResourceGroupNamePrefix string = ''

@description('Optional. Array of complete resource group names to override the default naming. If provided, must match the number of hubs in hubNetworks array.')
param parHubNetworkingResourceGroupNameOverrides array = []

@description('''Optional. Resource Lock Configuration for Resource Group.
- `name` - The name of the lock.
- `kind` - The lock settings of the service which can be CanNotDelete, ReadOnly, or None.
- `notes` - Notes about this lock.
''')
param parResourceGroupLock lockType?

@description('Optional. The prefix for the DNS Resource Group names. Will be combined with location to create: {prefix}-{location}. Can be overridden by parDnsResourceGroupNameOverrides.')
param parDnsResourceGroupNamePrefix string = ''

@description('Optional. Array of complete resource group names to override the default naming. If provided, must match the number of hubs in hubNetworks array.')
param parDnsResourceGroupNameOverrides array = []

@description('Optional. The prefix for the Private DNS Resolver Resource Group names. Will be combined with location to create: {prefix}-{location}. Can be overridden by parDnsPrivateResolverResourceGroupNameOverrides.')
param parDnsPrivateResolverResourceGroupNamePrefix string = ''

@description('Optional. Array of complete resource group names to override the default naming. If provided, must match the number of hubs in hubNetworks array.')
param parDnsPrivateResolverResourceGroupNameOverrides array = []

// Hub Networking Parameters
@description('Required. The hub virtual networks to create.')
param hubNetworks array

// Resource Lock Parameters
@sys.description('''Optional. Global Resource Lock Configuration used for all resources deployed in this module.
- `name` - The name of the lock.
- `kind` - The lock settings of the service which can be CanNotDelete, ReadOnly, or None.
- `notes` - Notes about this lock.
''')
param parGlobalResourceLock lockType = {
  kind: 'None'
  notes: 'This lock was created by the ALZ Bicep Hub Networking Module.'
}

// General Parameters
@description('Optional. Array of locations for reference purposes. This parameter is primarily used in parameter files for convenience when defining hubNetworks array.')
#disable-next-line no-unused-params
param parLocations array = []

@description('Optional. Tags to be applied to all resources.')
param parTags object = {}

@description('Optional. Enable or disable telemetry.')
param parEnableTelemetry bool = true

//========================================
// Variables
//========================================

var hubResourceGroupNames = [
  for (hub, i) in hubNetworks: empty(parHubNetworkingResourceGroupNameOverrides)
    ? '${parHubNetworkingResourceGroupNamePrefix}${hub.location}'
    : parHubNetworkingResourceGroupNameOverrides[i]
]
var dnsResourceGroupNames = [
  for (hub, i) in hubNetworks: empty(parDnsResourceGroupNameOverrides)
    ? '${parDnsResourceGroupNamePrefix}-${hub.location}'
    : parDnsResourceGroupNameOverrides[i]
]
var dnsPrivateResolverResourceGroupNames = [
  for (hub, i) in hubNetworks: empty(parDnsPrivateResolverResourceGroupNameOverrides)
    ? '${parDnsPrivateResolverResourceGroupNamePrefix}-${hub.location}'
    : parDnsPrivateResolverResourceGroupNameOverrides[i]
]
var publicIpRecommendedZones = [
  for hub in hubNetworks: map(pickZones('Microsoft.Network', 'publicIPAddresses', hub.location, 3), zone => int(zone))
]
var hubAzureFirewallRecommendedZones = [
  for hub in hubNetworks: map(pickZones('Microsoft.Network', 'azureFirewalls', hub.location, 3), zone => int(zone))
]
var hubBastionRecommendedZones = [
  for hub in hubNetworks: map(pickZones('Microsoft.Network', 'bastionHosts', hub.location, 3), zone => int(zone))
]
var expressRouteGatewaySkuMap = {
  zonal: 'ErGw1AZ'
  nonZonal: 'Standard'
}
var hubExpressRouteGatewayRecommendedSku = [
  for hub in hubNetworks: empty(pickZones('Microsoft.Network', 'virtualNetworkGateways', hub.location))
    ? expressRouteGatewaySkuMap.nonZonal
    : expressRouteGatewaySkuMap.zonal
]
var firewallPrivateIpAddresses = [
  for (hub, i) in hubNetworks: hub.azureFirewallSettings.deployAzureFirewall
    ? cidrHost(
        (filter(hub.subnets, subnet => subnet.?name == 'AzureFirewallSubnet')[?0] ?? { addressPrefix: '' }).?addressPrefix ?? '',
        3
      )
    : ''
]
var dnsResolverInboundIpAddresses = [
  for (hub, i) in hubNetworks: (hub.privateDnsSettings.deployDnsPrivateResolver && hub.privateDnsSettings.deployPrivateDnsZones)
    ? cidrHost(
        (filter(hub.subnets, subnet => subnet.?name == 'DNSPrivateResolverInboundSubnet')[?0] ?? { addressPrefix: '' }).?addressPrefix ?? '',
        3
      )
    : ''
]

//========================================
// Resources Groups
//========================================

module modHubNetworkingResourceGroups 'br/public:avm/res/resources/resource-group:0.4.3' = [
  for (hub, i) in hubNetworks: {
    name: 'modHubResourceGroup-${i}-${uniqueString(parHubNetworkingResourceGroupNamePrefix, hub.location)}'
    scope: subscription()
    params: {
      name: hubResourceGroupNames[i]
      location: hub.location
      lock: parGlobalResourceLock ?? parResourceGroupLock
      tags: parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

module modDnsResourceGroups 'br/public:avm/res/resources/resource-group:0.4.3' = [
  for (hub, i) in hubNetworks: if (hub.privateDnsSettings.deployPrivateDnsZones) {
    name: 'modDnsResourceGroup-${i}-${uniqueString(parDnsResourceGroupNamePrefix, hub.location)}'
    scope: subscription()
    params: {
      name: dnsResourceGroupNames[i]
      location: hub.location
      lock: parGlobalResourceLock ?? parResourceGroupLock
      tags: parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

module modPrivateDnsResolverResourceGroups 'br/public:avm/res/resources/resource-group:0.4.3' = [
  for (hub, i) in hubNetworks: if (hub.privateDnsSettings.deployDnsPrivateResolver) {
    name: 'modPrivateDnsResolverResourceGroup-${i}-${uniqueString(parDnsPrivateResolverResourceGroupNamePrefix, hub.location)}'
    scope: subscription()
    params: {
      name: dnsPrivateResolverResourceGroupNames[i]
      location: hub.location
      lock: parGlobalResourceLock ?? parResourceGroupLock
      tags: parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

//=====================
// Virtual Networks
//=====================
module resHubVirtualNetwork 'br/public:avm/res/network/virtual-network:0.7.2' = [
  for (hub, i) in hubNetworks: {
    name: 'vnet-${hub.name}-${uniqueString(parHubNetworkingResourceGroupNamePrefix, hub.location)}'
    scope: resourceGroup(hubResourceGroupNames[i])
    dependsOn: [
      modHubNetworkingResourceGroups[i]
      ...(hub.ddosProtectionPlanSettings.deployDdosProtectionPlan
        ? [resDdosProtectionPlan[i]]
        : hubNetworks[0].ddosProtectionPlanSettings.deployDdosProtectionPlan ? [resDdosProtectionPlan[0]] : [])
    ]
    params: {
      name: hub.name
      location: hub.location
      addressPrefixes: hub.addressPrefixes
      dnsServers: hub.azureFirewallSettings.deployAzureFirewall && hub.privateDnsSettings.deployDnsPrivateResolver && hub.privateDnsSettings.deployPrivateDnsZones
        ? [firewallPrivateIpAddresses[i]]
        : (hub.?dnsServers ?? [])
      ddosProtectionPlanResourceId: hub.?ddosProtectionPlanResourceId ?? (hub.ddosProtectionPlanSettings.deployDdosProtectionPlan
        ? resDdosProtectionPlan[i].?outputs.resourceId
        : hubNetworks[0].ddosProtectionPlanSettings.deployDdosProtectionPlan
            ? resDdosProtectionPlan[0].?outputs.resourceId
            : null)
      vnetEncryption: hub.?vnetEncryption ?? false
      vnetEncryptionEnforcement: hub.?vnetEncryptionEnforcement ?? 'AllowUnencrypted'
      subnets: [
        for subnet in hub.subnets: {
          name: subnet.name
          addressPrefix: subnet.addressPrefix
          delegation: subnet.?delegation
          networkSecurityGroupResourceId: (subnet.?name == 'AzureBastionSubnet' && hub.bastionHostSettings.deployBastion)
            ? resBastionNsg[i].?outputs.resourceId
            : subnet.?networkSecurityGroupId
        }
      ]
      lock: parGlobalResourceLock ?? hub.?lock
      tags: hub.?tags ?? parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

//=====================
// Azure Firewall
//=====================

module resAzureFirewall 'br/public:avm/res/network/azure-firewall:0.9.2' = [
  for (hub, i) in hubNetworks: if (hub.azureFirewallSettings.deployAzureFirewall) {
    name: 'afw-${hub.name}-${uniqueString(parHubNetworkingResourceGroupNamePrefix, hub.location)}'
    scope: resourceGroup(hubResourceGroupNames[i])
    dependsOn: [
      resHubVirtualNetwork[i]
    ]
    params: {
      name: hub.?azureFirewallSettings.?azureFirewallName ?? 'afw-alz-${hub.location}'
      location: hub.location
      azureSkuTier: hub.?azureFirewallSettings.?azureSkuTier ?? 'Standard'
      firewallPolicyId: hub.?azureFirewallSettings.?firewallPolicyId ?? resFirewallPolicy[i].?outputs.resourceId
      managementIPAddressObject: hub.?azureFirewallSettings.?managementIPAddressObject
      publicIPAddressObject: hub.?azureFirewallSettings.?publicIPAddressObject ?? (!empty(hub.?azureFirewallSettings.?publicIPResourceID ?? '')
        ? null
        : {
            name: '${hub.name}-azfirewall-pip'
          })
      publicIPResourceID: hub.?azureFirewallSettings.?publicIPResourceID
      roleAssignments: hub.?azureFirewallSettings.?roleAssignments
      threatIntelMode: (hub.?azureFirewallSettings.?azureSkuTier == 'Standard')
        ? 'Alert'
        : hub.?azureFirewallSettings.?threatIntelMode ?? 'Alert'
      availabilityZones: hub.?azureFirewallSettings.?zones ?? hubAzureFirewallRecommendedZones[i]
      virtualNetworkResourceId: resHubVirtualNetwork[i].outputs.resourceId
      lock: hub.?azureFirewallSettings.?lock ?? parGlobalResourceLock
      tags: hub.?azureFirewallSettings.?tags ?? parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

//=====================
// Bastion Hosts
//=====================

module resBastion 'br/public:avm/res/network/bastion-host:0.8.2' = [
  for (hub, i) in hubNetworks: if (hub.bastionHostSettings.deployBastion) {
    name: 'bastion-${hub.name}-${uniqueString(parHubNetworkingResourceGroupNamePrefix, hub.location)}'
    scope: resourceGroup(hubResourceGroupNames[i])
    dependsOn: [
      resHubVirtualNetwork[i]
    ]
    params: {
      name: hub.?bastionHostSettings.?bastionHostSettingsName ?? 'bas-alz-${hub.location}'
      location: hub.location
      skuName: hub.?bastionHostSettings.?skuName ?? 'Standard'
      virtualNetworkResourceId: resHubVirtualNetwork[i].outputs.resourceId
      scaleUnits: hub.?bastionHostSettings.?scaleUnits ?? 4
      disableCopyPaste: hub.?bastionHostSettings.?disableCopyPaste ?? false
      enableFileCopy: hub.?bastionHostSettings.?enableFileCopy ?? false
      enableIpConnect: hub.?bastionHostSettings.?enableIpConnect ?? false
      enableKerberos: hub.?bastionHostSettings.?enableKerberos ?? false
      enableShareableLink: hub.?bastionHostSettings.?enableShareableLink ?? false
      availabilityZones: hub.?bastionHostSettings.?zones ?? hubBastionRecommendedZones[i]
      publicIPAddressObject: {
        name: '${hub.name}-bastion-pip'
        availabilityZones: hub.?bastionHostSettings.?zones ?? publicIpRecommendedZones[i]
      }
      lock: hub.?bastionHostSettings.?lock ?? parGlobalResourceLock
      tags: hub.?bastionHostSettings.?tags ?? parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

//=====================
// VNet Peerings
//=====================

@batchSize(1)
module resVnetPeering 'br/public:avm/res/network/virtual-network:0.7.2' = [
  for (hub, i) in hubNetworks: if (hub.deployPeering && !empty(hub.?peeringSettings ?? [])) {
    name: 'peering-${hub.name}-${uniqueString(parHubNetworkingResourceGroupNamePrefix, hub.location)}'
    scope: resourceGroup(hubResourceGroupNames[i])
    dependsOn: [
      resHubVirtualNetwork
      resAzureFirewall
    ]
    params: {
      name: hub.name
      location: hub.location
      addressPrefixes: hub.addressPrefixes
      peerings: [
        for peering in hub.?peeringSettings ?? []: {
          allowForwardedTraffic: peering.?allowForwardedTraffic ?? true
          allowGatewayTransit: peering.?allowGatewayTransit ?? false
          allowVirtualNetworkAccess: peering.?allowVirtualNetworkAccess ?? true
          useRemoteGateways: peering.?useRemoteGateways ?? false
          remotePeeringEnabled: true
          remotePeeringAllowForwardedTraffic: peering.?allowForwardedTraffic ?? true
          remotePeeringAllowGatewayTransit: peering.?allowGatewayTransit ?? false
          remotePeeringAllowVirtualNetworkAccess: peering.?allowVirtualNetworkAccess ?? true
          remotePeeringUseRemoteGateways: peering.?useRemoteGateways ?? false
          remoteVirtualNetworkResourceId: resourceId(
            subscription().subscriptionId,
            hubResourceGroupNames[indexOf(map(hubNetworks, h => h.name), peering.remoteVirtualNetworkName)],
            'Microsoft.Network/virtualNetworks',
            peering.remoteVirtualNetworkName
          )
        }
      ]
      lock: hub.?lock ?? parGlobalResourceLock
      tags: hub.?tags ?? parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

//=====================
// Route Tables
//=====================

// Firewall Route Table - for AzureFirewallSubnet with default route to Internet
module resFirewallRouteTable 'br/public:avm/res/network/route-table:0.5.0' = [
  for (hub, i) in hubNetworks: if (hub.azureFirewallSettings.deployAzureFirewall) {
    name: 'rt-fw-${hub.name}-${uniqueString(parHubNetworkingResourceGroupNamePrefix, hub.location)}'
    scope: resourceGroup(hubResourceGroupNames[i])
    dependsOn: [
      modHubNetworkingResourceGroups
    ]
    params: {
      name: 'rt-hub-fw-${hub.location}'
      location: hub.location
      routes: [
        {
          name: 'internet'
          properties: {
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'Internet'
          }
        }
      ]
      disableBgpRoutePropagation: false
      lock: hub.?azureFirewallSettings.?lock ?? parGlobalResourceLock
      tags: hub.?azureFirewallSettings.?tags ?? parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

// User Subnets Route Table - for regular subnets with default route to Firewall
module resUserSubnetsRouteTable 'br/public:avm/res/network/route-table:0.5.0' = [
  for (hub, i) in hubNetworks: if (hub.azureFirewallSettings.deployAzureFirewall) {
    name: 'rt-user-${hub.name}-${uniqueString(parHubNetworkingResourceGroupNamePrefix, hub.location)}'
    scope: resourceGroup(hubResourceGroupNames[i])
    dependsOn: [
      modHubNetworkingResourceGroups
    ]
    params: {
      name: 'rt-hub-std-${hub.location}'
      location: hub.location
      routes: [
        {
          name: 'default-via-firewall'
          properties: {
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIpAddresses[i]
          }
        }
      ]
      disableBgpRoutePropagation: false
      lock: hub.?azureFirewallSettings.?lock ?? parGlobalResourceLock
      tags: hub.?azureFirewallSettings.?tags ?? parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

//=====================
// Network Security
//=====================
module resDdosProtectionPlan 'br/public:avm/res/network/ddos-protection-plan:0.3.2' = [
  for (hub, i) in hubNetworks: if (hub.ddosProtectionPlanSettings.deployDdosProtectionPlan) {
    name: 'ddosPlan-${uniqueString(parHubNetworkingResourceGroupNamePrefix,hub.?ddosProtectionPlanResourceId ?? '',hub.location)}'
    scope: resourceGroup(hubResourceGroupNames[i])
    dependsOn: [
      modHubNetworkingResourceGroups
    ]
    params: {
      name: hub.?ddosProtectionPlanSettings.?name ?? 'ddos-alz-${hub.location}'
      location: hub.?ddosProtectionPlanSettings.?location ?? hub.location
      lock: hub.?ddosProtectionPlanSettings.?lock ?? parGlobalResourceLock
      tags: hub.?ddosProtectionPlanSettings.?tags ?? parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

module resFirewallPolicy 'br/public:avm/res/network/firewall-policy:0.3.4' = [
  for (hub, i) in hubNetworks: if (hub.azureFirewallSettings.deployAzureFirewall && empty(hub.?azureFirewallSettings.?firewallPolicyId)) {
    name: 'firewallPolicy-${uniqueString(parHubNetworkingResourceGroupNamePrefix,hub.name,hub.location)}'
    scope: resourceGroup(hubResourceGroupNames[i])
    dependsOn: [
      modHubNetworkingResourceGroups
    ]
    params: {
      name: 'afwp-alz-${hub.location}'
      location: hub.location
      tier: hub.?azureFirewallSettings.?azureSkuTier ?? 'Standard'
      threatIntelMode: (hub.?azureFirewallSettings.?azureSkuTier == 'Standard')
        ? 'Alert'
        : hub.?azureFirewallSettings.?threatIntelMode ?? 'Alert'
      enableProxy: hub.?azureFirewallSettings.?azureSkuTier == 'Basic'
        ? false
        : (hub.privateDnsSettings.deployDnsPrivateResolver && hub.privateDnsSettings.deployPrivateDnsZones && hub.azureFirewallSettings.deployAzureFirewall)
            ? true
            : (hub.?azureFirewallSettings.?dnsProxyEnabled ?? false)
      servers: hub.?azureFirewallSettings.?azureSkuTier == 'Basic'
        ? null
        : (hub.privateDnsSettings.deployDnsPrivateResolver && hub.privateDnsSettings.deployPrivateDnsZones && hub.azureFirewallSettings.deployAzureFirewall)
            ? [dnsResolverInboundIpAddresses[i]]
            : hub.?azureFirewallSettings.?firewallDnsServers
      lock: hub.?azureFirewallSettings.?lock ?? parGlobalResourceLock
      tags: hub.?azureFirewallSettings.?tags ?? parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

module resBastionNsg 'br/public:avm/res/network/network-security-group:0.5.2' = [
  for (hub, i) in hubNetworks: if (hub.bastionHostSettings.deployBastion) {
    name: '${hub.name}-bastionNsg-${uniqueString(parHubNetworkingResourceGroupNamePrefix,hub.location)}'
    scope: resourceGroup(hubResourceGroupNames[i])
    dependsOn: [
      modHubNetworkingResourceGroups
    ]
    params: {
      name: hub.?bastionHostSettings.?bastionNsgName ?? 'nsg-bas-alz-${hub.location}'
      location: hub.location
      lock: hub.?bastionHostSettings.?bastionNsgLock ?? parGlobalResourceLock
      securityRules: hub.?bastionHostSettings.?bastionNsgSecurityRules ?? [
        // Inbound Rules
        {
          name: 'AllowHttpsInbound'
          properties: {
            access: 'Allow'
            direction: 'Inbound'
            priority: 120
            sourceAddressPrefix: 'Internet'
            destinationAddressPrefix: '*'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '443'
          }
        }
        {
          name: 'AllowGatewayManagerInbound'
          properties: {
            access: 'Allow'
            direction: 'Inbound'
            priority: 130
            sourceAddressPrefix: 'GatewayManager'
            destinationAddressPrefix: '*'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '443'
          }
        }
        {
          name: 'AllowAzureLoadBalancerInbound'
          properties: {
            access: 'Allow'
            direction: 'Inbound'
            priority: 140
            sourceAddressPrefix: 'AzureLoadBalancer'
            destinationAddressPrefix: '*'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '443'
          }
        }
        {
          name: 'AllowbastionHostSettingsCommunication'
          properties: {
            access: 'Allow'
            direction: 'Inbound'
            priority: 150
            sourceAddressPrefix: 'VirtualNetwork'
            destinationAddressPrefix: 'VirtualNetwork'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRanges: [
              '8080'
              '5701'
            ]
          }
        }
        {
          name: 'DenyAllInbound'
          properties: {
            access: 'Deny'
            direction: 'Inbound'
            priority: 4096
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
          }
        }
        // Outbound Rules
        {
          name: 'AllowSshRdpOutbound'
          properties: {
            access: 'Allow'
            direction: 'Outbound'
            priority: 100
            sourceAddressPrefix: '*'
            destinationAddressPrefix: 'VirtualNetwork'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRanges: hub.?bastionHostSettings.?outboundSshRdpPorts ?? [
              '22'
              '3389'
            ]
          }
        }
        {
          name: 'AllowAzureCloudOutbound'
          properties: {
            access: 'Allow'
            direction: 'Outbound'
            priority: 110
            sourceAddressPrefix: '*'
            destinationAddressPrefix: 'AzureCloud'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '443'
          }
        }
        {
          name: 'AllowBastionCommunication'
          properties: {
            access: 'Allow'
            direction: 'Outbound'
            priority: 120
            sourceAddressPrefix: 'VirtualNetwork'
            destinationAddressPrefix: 'VirtualNetwork'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRanges: [
              '8080'
              '5701'
            ]
          }
        }
        {
          name: 'AllowGetSessionInformation'
          properties: {
            access: 'Allow'
            direction: 'Outbound'
            priority: 130
            sourceAddressPrefix: '*'
            destinationAddressPrefix: 'Internet'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '80'
          }
        }
        {
          name: 'DenyAllOutbound'
          properties: {
            access: 'Deny'
            direction: 'Outbound'
            priority: 4096
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
          }
        }
      ]
      tags: hub.?bastionHostSettings.?tags ?? parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

//=====================
// Hybrid Connectivity
//=====================
module resVpnGateway 'br/public:avm/res/network/virtual-network-gateway:0.10.1' = [
  for (hub, i) in hubNetworks: if (hub.vpnGatewaySettings.deployVpnGateway) {
    name: 'vpnGateway-${uniqueString(parHubNetworkingResourceGroupNamePrefix,hub.name,hub.location)}'
    scope: resourceGroup(hubResourceGroupNames[i])
    dependsOn: [
      resHubVirtualNetwork[i]
      modHubNetworkingResourceGroups
    ]
    params: {
      name: hub.?vpnGatewaySettings.?name ?? 'vgw-alz-${hub.location}'
      clusterSettings: {
        clusterMode: any(hub.?vpnGatewaySettings.?vpnMode)
        asn: hub.?vpnGatewaySettings.?asn ?? 65515
        customBgpIpAddresses: (hub.?vpnGatewaySettings.?vpnMode == 'activePassiveBgp' || hub.?vpnGatewaySettings.?vpnMode == 'activeActiveBgp')
          ? (hub.?vpnGatewaySettings.?customBgpIpAddresses)
          : null
      }
      location: hub.location
      gatewayType: 'Vpn'
      vpnType: hub.?vpnGatewaySettings.?vpnType ?? 'RouteBased'
      skuName: hub.?vpnGatewaySettings.?skuName ?? 'VpnGw1AZ'
      enableBgpRouteTranslationForNat: hub.?vpnGatewaySettings.?enableBgpRouteTranslationForNat ?? false
      enableDnsForwarding: hub.?vpnGatewaySettings.?enableDnsForwarding ?? false
      vpnGatewayGeneration: hub.?vpnGatewaySettings.?vpnGatewayGeneration ?? 'None'
      virtualNetworkResourceId: resHubVirtualNetwork[i].outputs.resourceId
      domainNameLabel: !empty(hub.?vpnGatewaySettings.?domainNameLabel ?? [])
        ? hub.?vpnGatewaySettings.?domainNameLabel
        : [
            'vgw-alz-${hub.location}-${uniqueString(parHubNetworkingResourceGroupNamePrefix, hub.name, hub.location, 'vpn')}'
          ]
      publicIpAvailabilityZones: hub.?vpnGatewaySettings.?skuName != 'Basic'
        ? hub.?vpnGatewaySettings.?publicIpZones ?? publicIpRecommendedZones[i]
        : []
      lock: hub.?vpnGatewaySettings.?lock ?? parGlobalResourceLock
      tags: hub.?vpnGatewaySettings.?tags ?? parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

module resExpressRouteGateway 'br/public:avm/res/network/virtual-network-gateway:0.10.1' = [
  for (hub, i) in hubNetworks: if (hub.?expressRouteGatewaySettings.?deployExpressRouteGateway ?? false) {
    name: 'expressRouteGateway-${uniqueString(parHubNetworkingResourceGroupNamePrefix,hub.name,hub.location)}'
    scope: resourceGroup(hubResourceGroupNames[i])
    dependsOn: [
      resHubVirtualNetwork[i]
      modHubNetworkingResourceGroups
    ]
    params: {
      name: hub.?expressRouteGatewaySettings.?name ?? 'ergw-alz-${hub.location}'
      clusterSettings: {
        clusterMode: 'activePassiveNoBgp'
      }
      location: hub.location
      gatewayType: 'ExpressRoute'
      skuName: hub.?expressRouteGatewaySettings.?skuName ?? hubExpressRouteGatewayRecommendedSku[i]
      enableDnsForwarding: hub.?expressRouteGatewaySettings.?enableDnsForwarding ?? false
      enablePrivateIpAddress: hub.?expressRouteGatewaySettings.?enablePrivateIpAddress ?? false
      virtualNetworkResourceId: resHubVirtualNetwork[i]!.outputs.resourceId
      publicIpAvailabilityZones: hub.?expressRouteGatewaySettings.?publicIpZones ?? publicIpRecommendedZones[i]
      lock: hub.?expressRouteGatewaySettings.?lock ?? parGlobalResourceLock
      tags: hub.?expressRouteGatewaySettings.?tags ?? parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

// =====================
// DNS
// =====================
module resPrivateDnsZones 'br/public:avm/ptn/network/private-link-private-dns-zones:0.7.2' = [
  for (hub, i) in hubNetworks: if (hub.privateDnsSettings.deployPrivateDnsZones) {
    name: 'privateDnsZone-${hub.name}-${uniqueString(parDnsResourceGroupNamePrefix,hub.location)}'
    scope: resourceGroup(dnsResourceGroupNames[i])
    dependsOn: [
      resHubVirtualNetwork
      modDnsResourceGroups
    ]
    params: {
      location: hub.location
      privateLinkPrivateDnsZones: empty(hub.?privateDnsSettings.?privateDnsZones)
        ? null
        : hub.?privateDnsSettings.?privateDnsZones
      additionalPrivateLinkPrivateDnsZonesToInclude: hub.?privateDnsSettings.?additionalPrivateLinkPrivateDnsZonesToInclude ?? []
      privateLinkPrivateDnsZonesToExclude: hub.?privateDnsSettings.?privateLinkPrivateDnsZonesToExclude ?? []
      virtualNetworkLinks: [
        for id in union(
          [
            resourceId(
              subscription().subscriptionId,
              hubResourceGroupNames[i],
              'Microsoft.Network/virtualNetworks',
              hub.name
            )
          ],
          !empty(hub.?privateDnsSettings.?virtualNetworkIdToLinkFailover)
            ? [hub.?privateDnsSettings.?virtualNetworkIdToLinkFailover]
            : [],
          hub.?privateDnsSettings.?virtualNetworkResourceIdsToLinkTo ?? []
        ): {
          virtualNetworkResourceId: id
        }
      ]
      lock: hub.?privateDnsSettings.?lock ?? parGlobalResourceLock
      tags: hub.?privateDnsSettings.?tags ?? parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

module resDnsPrivateResolver 'br/public:avm/res/network/dns-resolver:0.5.6' = [
  for (hub, i) in hubNetworks: if (hub.privateDnsSettings.deployDnsPrivateResolver) {
    name: 'dnsResolver-${hub.name}-${uniqueString(parDnsPrivateResolverResourceGroupNamePrefix,hub.location)}'
    scope: resourceGroup(dnsPrivateResolverResourceGroupNames[i])
    dependsOn: [
      resHubVirtualNetwork[i]
      modPrivateDnsResolverResourceGroups
    ]
    params: {
      name: hub.?privateDnsSettings.?privateDnsResolverName ?? 'dnspr-alz-${hub.location}'
      location: hub.location
      virtualNetworkResourceId: resHubVirtualNetwork[i]!.outputs.resourceId
      inboundEndpoints: hub.?privateDnsSettings.?inboundEndpoints ?? [
        {
          name: 'in-${hub.location}'
          subnetResourceId: '${resHubVirtualNetwork[i]!.outputs.resourceId}/subnets/DNSPrivateResolverInboundSubnet'
        }
      ]
      outboundEndpoints: hub.?privateDnsSettings.?outboundEndpoints ?? [
        {
          name: 'out-${hub.location}'
          subnetResourceId: '${resHubVirtualNetwork[i]!.outputs.resourceId}/subnets/DNSPrivateResolverOutboundSubnet'
        }
      ]
      lock: parGlobalResourceLock ?? hub.?privateDnsSettings.?lock
      tags: parTags
      enableTelemetry: parEnableTelemetry
    }
  }
]

//========================================
// Definitions
//========================================
type lockType = {
  @description('Optional. Specify the name of lock.')
  name: string?

  @description('Optional. The lock settings of the service.')
  kind: ('CanNotDelete' | 'ReadOnly' | 'None')

  @description('Optional. Notes about this lock.')
  notes: string?
}
