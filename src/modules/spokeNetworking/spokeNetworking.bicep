import {
  sharedRoutes
  sharedNSGrulesInbound
  sharedNSGrulesOutbound
} from '../../configuration/shared/shared.conf.bicep'

targetScope = 'subscription'

metadata name = 'Spoke Networking - AVM'
metadata description = 'Spoke Networking - AI Platform Landing Zone Module'
metadata version = '2.0.0'
metadata author = 'Insight APAC Platform Engineering'

// Resource Group Parameters
@description('Optional. The prefix for the Spoke Networking Resource Group names. Will be combined with location to create: {prefix}-{location}. Can be overridden by spokeNetworkingResourceGroupNameOverrides.')
param spokeNetworkingResourceGroupNamePrefix string = 'rg-alz-conn-'

@description('Optional. Array of complete resource group names to override the default naming. If provided, must match the number of hubs in hubNetworks array.')
param spokeNetworkingResourceGroupNameOverrides array = []

// General Parameters
@description('Required. Array of locations for reference purposes. This parameter is primarily used in parameter files for convenience when defining hubNetworks array.')
#disable-next-line no-unused-params
param locations array

@description('Optional. Tags of the resource.')
param tags object?

// Spoke Networking Parameters
@description('Required. The spoke virtual networks to create.')
param spokeNetworks array

@description('Optional. Array of Resource IDs for remote virtual networks or virtual hubs to peer with. Must match the number of spokes in spokeNetworks array if provided.')
param hubVirtualNetworkResourceId string[] = []

@description('Required. Network Security Group name prefix per spoke (e.g., NSG-AUE-PLAT-IDAM). Must match the number of spokes in spokeNetworks array.')
param nsgId string[]

@description('Optional. User Defined Route name prefix per spoke (e.g., UDR-AUE-PLAT-IDAM). Must match the number of spokes in spokeNetworks array.')
param udrId string[] = []

// Logic to bring your own Resource Groups for spoke networking or use a prefix-based naming convention
var spokeResourceGroupNames = [
  for (spoke, i) in spokeNetworks: (empty(spokeNetworkingResourceGroupNameOverrides) || i >= length(spokeNetworkingResourceGroupNameOverrides))
    ? '${spokeNetworkingResourceGroupNamePrefix}${spoke.location}'
    : spokeNetworkingResourceGroupNameOverrides[i]
]

// Enrich spokes with prefixes to avoid array indexing in nested loops
var spokesWithPrefixes = [for (spoke, i) in spokeNetworks: {
  spoke: spoke
  nsgPrefix: nsgId[i]
  udrPrefix: length(udrId) > i ? udrId[i] : ''
  resourceGroupName: (empty(spokeNetworkingResourceGroupNameOverrides) || i >= length(spokeNetworkingResourceGroupNameOverrides))
    ? '${spokeNetworkingResourceGroupNamePrefix}${spoke.location}'
    : spokeNetworkingResourceGroupNameOverrides[i]
  // Support both single hub for all spokes (length==1) or per-spoke hubs
  hubResourceId: !empty(hubVirtualNetworkResourceId) 
    ? (length(hubVirtualNetworkResourceId) == 1 ? hubVirtualNetworkResourceId[0] : (length(hubVirtualNetworkResourceId) > i ? hubVirtualNetworkResourceId[i] : ''))
    : ''
  hubVnetName: !empty(hubVirtualNetworkResourceId) && (length(hubVirtualNetworkResourceId) == 1 || length(hubVirtualNetworkResourceId) > i)
    ? split(length(hubVirtualNetworkResourceId) == 1 ? hubVirtualNetworkResourceId[0] : hubVirtualNetworkResourceId[i], '/')[8]
    : ''
  // Generate spoke resource ID to prevent self-peering
  spokeResourceId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${(empty(spokeNetworkingResourceGroupNameOverrides) || i >= length(spokeNetworkingResourceGroupNameOverrides)) ? '${spokeNetworkingResourceGroupNamePrefix}${spoke.location}' : spokeNetworkingResourceGroupNameOverrides[i]}/providers/Microsoft.Network/virtualNetworks/${spoke.name}'
}]

// Flatten subnets across all spokes for NSG and Route Table creation
var flattenedSubnets = flatten(map(range(0, length(spokeNetworks)), spokeIndex => map(spokeNetworks[spokeIndex].?subnets ?? [], subnet => {
  spokeIndex: spokeIndex
  spoke: spokeNetworks[spokeIndex]
  subnetName: subnet.name
  addressPrefix: subnet.?addressPrefix
  addressPrefixes: subnet.?addressPrefixes
  ipamPoolPrefixAllocations: subnet.?ipamPoolPrefixAllocations
  applicationGatewayIPConfigurations: subnet.?applicationGatewayIPConfigurations
  delegation: subnet.?delegation
  natGatewayResourceId: subnet.?natGatewayResourceId
  privateEndpointNetworkPolicies: subnet.?privateEndpointNetworkPolicies
  privateLinkServiceNetworkPolicies: subnet.?privateLinkServiceNetworkPolicies
  roleAssignments: subnet.?roleAssignments
  routes: subnet.?routes
  serviceEndpointPolicies: subnet.?serviceEndpointPolicies
  serviceEndpoints: subnet.?serviceEndpoints
  defaultOutboundAccess: subnet.?defaultOutboundAccess ?? false
  sharingScope: subnet.?sharingScope
  securityRules: subnet.?securityRules
  nsgPrefix: nsgId[spokeIndex]
  udrPrefix: length(udrId) > spokeIndex ? udrId[spokeIndex] : ''
  resourceGroupName: (empty(spokeNetworkingResourceGroupNameOverrides) || spokeIndex >= length(spokeNetworkingResourceGroupNameOverrides))
    ? '${spokeNetworkingResourceGroupNamePrefix}${spokeNetworks[spokeIndex].location}'
    : spokeNetworkingResourceGroupNameOverrides[spokeIndex]
})))

// Group flattened subnets by spoke index for VNet module consumption
var subnetsPerSpoke = [for i in range(0, length(spokeNetworks)): filter(flattenedSubnets, item => item.spokeIndex == i)]

@description('Resource Groups (Network) - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/resources/resource-group')
module spokeNetworkingResourceGroups 'br/public:avm/res/resources/resource-group:0.4.3' = [
  for (spoke, i) in spokeNetworks: {
    name: 'spokeResourceGroup-${i}-${uniqueString(spokeNetworkingResourceGroupNamePrefix, spoke.location)}'
    scope: az.subscription()
    params: {
      name: spokeResourceGroupNames[i]
      location: spoke.location
      tags: tags
    }
  }
]

@description('Module: Virtual Network - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/virtual-network')
module spokeVirtualNetwork 'br/public:avm/res/network/virtual-network:0.7.2' = [
  for (item, i) in spokesWithPrefixes: {
    name: take('spokeVirtualNetwork-${i}-${uniqueString(item.spoke.name)}', 64)
    scope: az.resourceGroup(item.resourceGroupName)
    dependsOn: [
      spokeNetworkingResourceGroups[i]
      networkSecurityGroup
      routeTable
    ]
    params: {
      // Required parameters
      addressPrefixes: item.spoke.addressPrefixes
      name: item.spoke.name
      // Non-required parameters
      ddosProtectionPlanResourceId: item.spoke.?ddosProtectionPlanId ?? null
      dnsServers: item.spoke.?dnsServers ?? []
      ipamPoolNumberOfIpAddresses: item.spoke.?ipamPoolNumberOfIpAddresses ?? null
      location: item.spoke.location
      // Only create peering if hub resource ID exists AND it's not the same as the spoke (prevent self-peering)
      peerings: !empty(item.hubResourceId) && toLower(item.hubResourceId) != toLower(item.spokeResourceId) ? [
        {
          name: 'FROM-${item.spoke.name}-TO-${item.hubVnetName}'
          allowForwardedTraffic: item.spoke.?peeringSettings.?allowForwardedTraffic ?? true
          allowGatewayTransit: item.spoke.?peeringSettings.?allowGatewayTransit ?? false
          allowVirtualNetworkAccess: item.spoke.?peeringSettings.?allowVirtualNetworkAccess ?? true
          useRemoteGateways: item.spoke.?peeringSettings.?useRemoteGateways ?? false
          remotePeeringEnabled: item.spoke.?peeringSettings.?remotePeeringEnabled ?? true
          remotePeeringName: 'FROM-${item.hubVnetName}-TO-${item.spoke.name}'
          remotePeeringAllowGatewayTransit: item.spoke.?peeringSettings.?remotePeeringAllowGatewayTransit ?? false
          remotePeeringAllowForwardedTraffic: item.spoke.?peeringSettings.?remotePeeringAllowForwardedTraffic ?? true
          remotePeeringAllowVirtualNetworkAccess: item.spoke.?peeringSettings.?remotePeeringAllowVirtualNetworkAccess ?? true
          remotePeeringUseRemoteGateways: item.spoke.?peeringSettings.?remotePeeringUseRemoteGateways ?? false
          remoteVirtualNetworkResourceId: item.hubResourceId
        }
      ] : []
      // Use pre-computed subnets grouped by spoke - no nested loops
      subnets: [
        for subnet in subnetsPerSpoke[i]: {
          name: subnet.subnetName
          addressPrefix: subnet.?addressPrefix
          addressPrefixes: subnet.?addressPrefixes
          ipamPoolPrefixAllocations: subnet.?ipamPoolPrefixAllocations
          applicationGatewayIPConfigurations: subnet.?applicationGatewayIPConfigurations
          delegation: subnet.?delegation
          natGatewayResourceId: subnet.?natGatewayResourceId
          networkSecurityGroupResourceId: resourceId(subscription().subscriptionId, subnet.resourceGroupName, 'Microsoft.Network/networkSecurityGroups', '${subnet.nsgPrefix}-${subnet.subnetName}')
          privateEndpointNetworkPolicies: subnet.?privateEndpointNetworkPolicies
          privateLinkServiceNetworkPolicies: subnet.?privateLinkServiceNetworkPolicies
          roleAssignments: subnet.?roleAssignments
          routeTableResourceId: (!empty(subnet.routes) || !empty(sharedRoutes))
            ? resourceId(subscription().subscriptionId, subnet.resourceGroupName, 'Microsoft.Network/routeTables', '${subnet.udrPrefix}-${subnet.subnetName}')
            : null
          serviceEndpointPolicies: subnet.?serviceEndpointPolicies
          serviceEndpoints: subnet.?serviceEndpoints
          defaultOutboundAccess: subnet.defaultOutboundAccess
          sharingScope: subnet.?sharingScope
        }
      ]
      tags: tags
    }
  }
]

@description('Module: Route Table - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/route-table')
module routeTable 'br/public:avm/res/network/route-table:0.5.0' = [
  for (item, i) in flattenedSubnets: if (!empty(item.routes) || !empty(sharedRoutes)) {
    name: 'routeTable-${item.spokeIndex}-${i}-${uniqueString(item.subnetName)}'
    scope: az.resourceGroup(item.resourceGroupName)
    dependsOn: [
      spokeNetworkingResourceGroups
    ]
    params: {
      // Required parameters
      name: '${item.udrPrefix}-${item.subnetName}'
      // Non-required parameters
      disableBgpRoutePropagation: !empty(sharedRoutes) || !empty(item.routes ?? [])
      location: item.spoke.location
      routes: !empty(sharedRoutes) ? concat(sharedRoutes, item.routes ?? []) : item.routes ?? []
      tags: tags
    }
  }
]

@description('Module: Network Security Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/network-security-group')
module networkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.2' = [
  for (item, i) in flattenedSubnets: {
    name: 'NSG-${item.spokeIndex}-${i}-${uniqueString(item.subnetName)}'
    scope: az.resourceGroup(item.resourceGroupName)
    dependsOn: [
      spokeNetworkingResourceGroups
    ]
    params: {
      // Required parameters
      name: '${item.nsgPrefix}-${item.subnetName}'
      // Non-required parameters
      location: item.spoke.location
      securityRules: concat(sharedNSGrulesInbound, sharedNSGrulesOutbound, item.securityRules ?? [])
      tags: tags
    }
  }
]

// Outputs
@description('The Spoke Resource Group Names.')
output spokeResourceGroupNames string[] = [for (spoke, i) in spokeNetworks: spokeNetworkingResourceGroups[i].outputs.name]

@description('The Virtual Network Resource Ids.')
output virtualNetworkIds string[] = [for (spoke, i) in spokeNetworks: spokeVirtualNetwork[i].outputs.resourceId]

@description('The Virtual Network Names.')
output virtualNetworkNames string[] = [for (spoke, i) in spokeNetworks: spokeVirtualNetwork[i].outputs.name]

@description('The names of the deployed subnets per spoke.')
output subnetNames array[] = [for (spoke, i) in spokeNetworks: spoke.?subnets ?? []]
