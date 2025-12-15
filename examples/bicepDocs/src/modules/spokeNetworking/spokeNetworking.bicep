import * as shared from '../../configuration/shared/shared.conf.bicep'

import { // Base Landing Zone User Defined Types
  tagsType
  virtualNetworkType 
} from '../../configuration/shared/lz.type.bicep'

targetScope = 'resourceGroup'

metadata name = 'Spoke Networking - Azure Extended Zone Module'
metadata description = 'Spoke Networking - Azure Extended Zone deployment.'
metadata version = '1.0.0'
metadata author = 'Insight APAC Platform Engineering'

// Parameters
@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Required. Extended location for the resource.')
param extendedLocation object

@description('Optional. Tags of the resource.')
param tags tagsType?

// Virtual Network Parameters
@description('Required. Configuration for Azure Virtual Network.')
param virtualNetworkConfiguration virtualNetworkType

@description('Required. Network Security Group Id.')
param nsgId string

@description('Optional. User Defined Route Id.')
param udrId string = ''

@description('Required. Virtual Network Id.')
param vntId string

// Variables
var addressPrefix = first(virtualNetworkConfiguration.addressPrefixes)
var vNetAddressSpace = replace(addressPrefix, '/', '_')
var subnetMap = map(range(0, length(virtualNetworkConfiguration.subnets)), i => {
  name: virtualNetworkConfiguration.?subnets[i].name
  addressPrefix: virtualNetworkConfiguration.?subnets[i].?addressPrefix ?? ''
  addressPrefixes: virtualNetworkConfiguration.?subnets[i].?addressPrefixes ?? []
  delegation: virtualNetworkConfiguration.?subnets[i].?delegation ?? ''
  routes: virtualNetworkConfiguration.?subnets[i].?routes ?? []
  privateEndpointNetworkPolicies: virtualNetworkConfiguration.?subnets[i].?privateEndpointNetworkPolicies ?? 'Disabled'
  privateLinkServiceNetworkPolicies: virtualNetworkConfiguration.?subnets[i].?privateLinkServiceNetworkPolicies ?? 'Disabled'
  serviceEndpoints: virtualNetworkConfiguration.?subnets[i].?serviceEndpoints ?? []
  serviceEndpointPolicies: virtualNetworkConfiguration.?subnets[i].?serviceEndpointPolicies ?? []
})

var subnetProperties = [
  for subnet in subnetMap: {
    name: subnet.name
    properties: {
      addressPrefix: !empty(subnet.?addressPrefix) ? subnet.addressPrefix : null
      addressPrefixes: !empty(subnet.?addressPrefixes) ? subnet.addressPrefixes : null
      delegations: !empty(subnet.delegation)
        ? [
            {
              name: subnet.delegation
              properties: {
                serviceName: subnet.delegation
              }
            }
          ]
        : []
      networkSecurityGroup: {
        id: resourceId('Microsoft.Network/networkSecurityGroups', '${nsgId}${subnet.name}')
      }
      routeTable: (!empty(subnet.?routes) || !empty(shared.?sharedRoutes))
        ? {
            id: resourceId('Microsoft.Network/routeTables', '${udrId}${subnet.name}')
          }
        : null
      privateEndpointNetworkPolicies: subnet.privateEndpointNetworkPolicies
      privateLinkServiceNetworkPolicies: subnet.privateLinkServiceNetworkPolicies
      serviceEndpoints: !empty(subnet.serviceEndpoints) ? map(subnet.serviceEndpoints, endpoint => { service: endpoint }) : []
      serviceEndpointPolicies: subnet.serviceEndpointPolicies
    }
  }
]

@description('Resource: Virtual Network')
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  dependsOn: [
    networkSecurityGroup
    routeTable
  ]
  name: '${vntId}${vNetAddressSpace}'
  location: location
  extendedLocation: extendedLocation
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: virtualNetworkConfiguration.addressPrefixes
    }
    ddosProtectionPlan: !empty(virtualNetworkConfiguration.?ddosProtectionPlanId)
      ? {
          id: virtualNetworkConfiguration.?ddosProtectionPlanId
        }
      : null
    dhcpOptions: virtualNetworkConfiguration.?dnsServers != null
      ? {
          dnsServers: virtualNetworkConfiguration.?dnsServers
        }
      : null
    enableDdosProtection: !empty(virtualNetworkConfiguration.?ddosProtectionPlanId)
    subnets: subnetProperties
  }
}

@description('Module: Route Table - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/route-table')
module routeTable 'br/public:avm/res/network/route-table:0.5.0' = [
  for (subnet, i) in (virtualNetworkConfiguration.?subnets ?? []): if (!empty(subnet.?routes) || !empty(shared.?sharedRoutes)) {
    name: 'routeTable-${i}'
    params: {
      // Required parameters
      name: '${udrId}${subnet.name}'
      // Non-required parameters
      disableBgpRoutePropagation: true
      location: location
      routes: !(empty(shared.sharedRoutes)) ? concat(shared.sharedRoutes, subnet.?routes ?? []) : subnet.?routes ?? [] // If shared routes are not empty, use shared routes and subnet routes. If no routes are defined in subnets, pass an empty array
      tags: tags
    }
  }
]

@description('Module: Network Security Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/network-security-group')
module networkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.2' = [
  for (subnet, i) in (virtualNetworkConfiguration.?subnets ?? []): {
    name: 'NSG-${i}'
    params: {
      // Required parameters
      name: '${nsgId}${subnet.name}'
      // Non-required parameters
      location: location
      securityRules: concat(shared.sharedNSGrulesInbound, shared.sharedNSGrulesOutbound, subnet.?securityRules ?? [])
      tags: tags
    }
  }
]

// Outputs
@description('The Virtual Network Resource Id.')
output virtualNetworkId string = virtualNetwork.id

@description('The Virtual Network Name.')
output virtualNetworkName string = virtualNetwork.name

@description('The names of the deployed subnets.')
output subnetNames array = [for (subnet, i) in (virtualNetworkConfiguration.?subnets ?? []): subnet.name]

@description('An array of Route Tables.')
output routeTable array = [
  for (subnet, i) in (virtualNetworkConfiguration.?subnets ?? []): !empty(shared.sharedRoutes)
    ? {
        name: routeTable[i].outputs.name
        id: routeTable[i].outputs.resourceId
      }
    : null
]

@description('An array of Network Security Groups.')
output networkSecurityGroup array = [
  for (subnet, i) in (virtualNetworkConfiguration.?subnets ?? []): {
    name: networkSecurityGroup[i].outputs.name
    id: networkSecurityGroup[i].outputs.name
  }
]
