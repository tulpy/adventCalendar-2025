metadata name = 'ALZ Bicep - Private DNS Resolver'
metadata description = 'Module used to set up the Private DNS Resolver.'
metadata version = '1.0.1'
metadata author = 'Insight APAC Platform Engineering'

@description('Optional. The Azure Region to deploy the resources into.')
param location string = resourceGroup().location

@description('Optional. Tags that will be applied to all resources in this module.')
param tags object = {}

@description('Required. The resource ID of the Virtual Network.')
param virtualNetworkResourceId string

@description('Required. Name of Private DNS Resolver.')
param privateDnsResolverName string

@description('Required. Name of Private DNS Resolver Ruleset.')
param privateDnsResolverRulesetName string

@description('Optional. Array of Private DNS Resolver Forwarding Rules.')
param forwardingRules array = []

@description('Module: Private DNS Resolver - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/dns-resolver')
module dnsResolver 'br/public:avm/res/network/dns-resolver:0.5.6' = {
  name: take('dnsResolver-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    name: privateDnsResolverName
    virtualNetworkResourceId: virtualNetworkResourceId
    // Non-required parameters
    inboundEndpoints: [
      {
        name: 'inbound'
        subnetResourceId: '${virtualNetworkResourceId}/subnets/inboundDNSSubnet'
      }
    ]
    location: location
    tags: tags
  }
}

@description('Resource: Outbound Endpoint')
resource outEndpoint 'Microsoft.Network/dnsResolvers/outboundEndpoints@2025-10-01-preview' = {
  name: '${privateDnsResolverName}/outbound'
  dependsOn: [
    dnsResolver
  ]
  location: location
  properties: {
    subnet: {
      id: '${virtualNetworkResourceId}/subnets/outboundDNSSubnet'
    }
  }
}

@description('Module: Private DNS Forwarding Ruleset - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/dns-forwarding-ruleset')
module dnsForwardingRuleset 'br/public:avm/res/network/dns-forwarding-ruleset:0.5.3' = {
  name: take('dnsForwardingRuleset-${guid(deployment().name)}', 64)
  dependsOn: [
    dnsResolver
  ]
  params: {
    // Required parameters
    name: privateDnsResolverRulesetName
    dnsForwardingRulesetOutboundEndpointResourceIds: [
      outEndpoint.id
    ]
    // Non-required parameters
    forwardingRules: forwardingRules
    location: location
    tags: tags
    virtualNetworkLinks: [
      {
        name: 'RuleSetLink-Connectivity-vNet'
        virtualNetworkResourceId: virtualNetworkResourceId
      }
    ]
  }
}

@description('The resource ID of the DNS Private Resolver.')
output dnsResolverId string = dnsResolver.outputs.resourceId

@description('The name of the DNS Private Resolver.')
output dnsResolverName string = dnsResolver.name

@description('The resource ID of the DNS Forwarding Ruleset.')
output dnsForwardingRulesetId string = dnsForwardingRuleset.outputs.resourceId

@description('The name of the DNS Forwarding Ruleset.')
output dnsForwardingRulesetName string = dnsForwardingRuleset.name
