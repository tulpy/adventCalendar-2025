import * as shared from '../../configuration/shared/shared.conf.bicep'

import {
  // Platform Landing Zone User Defined Types
  virtualNetworkGatewayType
} from '../../configuration/shared/platform.type.bicep'

import {
  // Base Landing Zone User Defined Types
  tagsType
  budgetType
} from '../../configuration/shared/lz.type.bicep'

targetScope = 'managementGroup'

metadata name = 'Platform Connectivity Landing Zone - Azure Orchestration Module'
metadata description = 'Platform Connectivity Landing Zone deployment.'
metadata version = '1.0.0'
metadata author = 'Insight APAC Platform Engineering'

type subnetOptionsType = ({
  @description('Name of subnet.')
  name: string
  @description('IP address range for subnet.')
  ipAddressRange: string
  @description('Resource Id of Network Security Group to associate with subnet.')
  networkSecurityGroupId: string?
  @description('Resource Id of Route Table to associate with subnet.')
  routeTableId: string?
  @description('Name of the delegation to create for the subnet.')
  delegation: string?
})[]

@maxLength(10)
@description('Required. Specifies the Landing Zone Id for the deployment.')
param lzId string

@description('Required. Specifies the environment Id for the deployment.')
param envId string

@description('Optional. The Azure Region to deploy the resources into.')
param location string = deployment().location

@description('Required. The Subscription Id for the deployment.')
@maxLength(36)
@minLength(36)
param subscriptionId string

@description('Required. Tags of the resource.')
param tags tagsType

@description('Optional. Whether to move the Subscription to the specified Management Group supplied in the parameter `subscriptionManagementGroupId`.')
param subscriptionManagementGroupAssociationEnabled bool = true

@maxLength(90)
@description('Optional. The Management Group Id to place the subscription in.')
param subscriptionMgPlacement string = ''

@description('Required. The IP address range for all virtual networks to use.')
param addressPrefixes array = ['10.52.0.0/16']

@description('Required. The name, IP address range, network security group, route table and delegation serviceName for each subnet in the virtual networks.')
param subnetsArray subnetOptionsType = [
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

@description('Optional. Array of DNS Server IP addresses for the Hub virtual Network.')
param dnsServerIps array = []

@description('Optional. Switch which allows Azure Firewall deployment to be provisioned.')
param azFirewallEnabled bool = true

@description('Optional. Switch which allows the Azure ER gateway to be provisioned.')
param erGwyEnabled bool = true

@description('Optional. Switch which allows the Azure VPN gateway to be provisioned.')
param vpnGwyEnabled bool = true

@description('Switch which allows Azure Bastion deployment to be provisioned.')
param azBastionEnabled bool = true

@description('Optional. Azure Firewall Tier associated with the Firewall to deploy.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param azFirewallTier string = 'Standard'

@description('Optional. The Azure Firewall Threat Intelligence Mode. If not set, the default value is Alert.')
@allowed([
  'Alert'
  'Deny'
  'Off'
])
param azFirewallIntelMode string = 'Deny'

@description('Optional. List of Custom Public IPs, which are assigned to firewalls ipConfigurations.')
param azFirewallCustomPublicIps array = []

@description('Optional. Azure Bastion SKU or Tier to deploy.  Currently two options exist Basic and Standard.')
@allowed([
  'Basic'
  'Standard'
])
param azBastionSku string = 'Standard'

@description('Optional. Switch to enable/disable Bastion native client support. This is only supported when the Standard SKU is used for Bastion as documented here: <https://learn.microsoft.com/azure/bastion/native-client/>')
param azBastionTunneling bool = false

@description('Optional. The list of Availability zones to use for the zone-redundant resources.')
@allowed([
  1
  2
  3
])
param azFirewallAvailabilityZones int[] = [1, 2, 3]

@allowed([
  1
  2
  3
])
@description('Optional. Availability Zones to deploy the VPN/ER PIP across. Region must support Availability Zones to use. If it does not then leave empty. Ensure that you select a zonal SKU for the ER/VPN Gateway if using Availability Zones for the PIP')
param azErGatewayAvailabilityZones int[] = [1, 2, 3]

@allowed([
  1
  2
  3
])
@description('Optional. Availability Zones to deploy the VPN/ER PIP across. Region must support Availability Zones to use. If it does not then leave empty. Ensure that you select a zonal SKU for the ER/VPN Gateway if using Availability Zones for the PIP')
param azVpnGatewayAvailabilityZones int[] = [1, 2, 3]

@description('Optional. Switch which enables the Azure Firewall DNS Proxy to be enabled on the Azure Firewall.')
param azFirewallDnsProxyEnabled bool = true

@description('Optional. Public IP Address SKU.')
@allowed([
  'Basic'
  'Standard'
])
param publicIpSku string = 'Standard'

@description('Optional. Switch which allows BGP Propagation to be disabled on the route tables.')
param disableBGPRoutePropagation bool = false

@description('Optional. An Array of Routes to be established within the route table for Gateway Subnet.')
param gatewayRoutes array = []

@description('Optional. Switch which allows Private DNS Zones to be provisioned.')
param privateDnsZonesEnabled bool = true

@description('Optional. Switch for Azure Budgets.')
param deployBudgets bool = true

@description('Optional. Configuration for Azure Budgets.')
param budgetConfiguration budgetType?

@description('Optional.Whether to deploy the Azure DNS Private resolver or not.')
param privateResolverEnabled bool = false

@description('Optional. Array of Forwarding Rules for the Private DNS Resolver.')
param forwardingRules array = []

//ASN must be 65515 if deploying VPN & ER for co-existence to work: <https://docs.microsoft.com/en-us/azure/expressroute/expressroute-howto-coexist-resource-manager#limits-and-limitations/>
@description('Configuration for VPN virtual network gateway to be deployed. If a VPN virtual network gateway is not desired an empty object should be used as the input parameter in the parameter file, i.e.')
param vpnGatewayConfig virtualNetworkGatewayType = {
  gatewayType: 'Vpn'
  sku: 'VpnGw1AZ'
  vpnType: 'RouteBased'
  vpnGatewayGeneration: 'Generation1'
  enableBgp: false
  activeActive: false
  enableBgpRouteTranslationForNat: false
  enableDnsForwarding: false
  vpnClientConfiguration: {}
  bgpSettings: {}
}

var vpnGatewayName = {
  name: '${vngId}vpnGwy'
}

var vngConcatConfig = union(vpnGatewayName, vpnGatewayConfig)

@description('Optional. Configuration for ExpressRoute virtual network gateway to be deployed. If a ExpressRoute virtual network gateway is not desired an empty object should be used as the input parameter in the parameter file, i.e.')
param erGatewayConfig virtualNetworkGatewayType = {
  gatewayType: 'ExpressRoute'
  sku: 'ErGw1AZ'
  vpnType: 'RouteBased'
  vpnGatewayGeneration: 'None'
  enableBgp: false
  activeActive: false
  enableBgpRouteTranslationForNat: false
  enableDnsForwarding: false
  bgpSettings: {}
}

var erGatewayName = {
  name: '${vngId}erGwy'
}

var erConcatConfig = union(erGatewayName, erGatewayConfig)

@description('Optional. The Action Group Resource Id to be used for Service Health Alerts.')
param actionGroupResourceId string?

// Orchestration Variables
var argId = toLower('${shared.resIds.resourceGroup}${shared.delimiter.dash}${shared.locIds[location]}${shared.delimiter.dash}${lzId}${shared.delimiter.dash}${envId}${shared.delimiter.dash}')
var vntId = toLower('${shared.resIds.virtualNetwork}${shared.delimiter.dash}${shared.locIds[location]}${shared.delimiter.dash}${lzId}${shared.delimiter.dash}${envId}${shared.delimiter.dash}')
var vngId = toLower('${shared.resIds.virtualNetworkGateway}${shared.delimiter.dash}${shared.locIds[location]}${shared.delimiter.dash}${lzId}${shared.delimiter.dash}${envId}${shared.delimiter.dash}')
var udrId = toLower('${shared.resIds.routeTable}${shared.delimiter.dash}${shared.locIds[location]}${shared.delimiter.dash}${lzId}${shared.delimiter.dash}${envId}${shared.delimiter.dash}')
var basId = toLower('${shared.resIds.azureBastion}${shared.delimiter.dash}${shared.locIds[location]}${shared.delimiter.dash}${lzId}${shared.delimiter.dash}${envId}${shared.delimiter.dash}')
var nsgId = toLower('${shared.resIds.networkSecurityGroup}${shared.delimiter.dash}${shared.locIds[location]}${shared.delimiter.dash}${lzId}${shared.delimiter.dash}${envId}${shared.delimiter.dash}')
var afwId = toLower('${shared.resIds.azureFirewall}${shared.delimiter.dash}${shared.locIds[location]}${shared.delimiter.dash}${lzId}${shared.delimiter.dash}${envId}${shared.delimiter.dash}')
var afpId = toLower('${shared.resIds.azureFirewallPolicy}${shared.delimiter.dash}${shared.locIds[location]}${shared.delimiter.dash}${lzId}${shared.delimiter.dash}${envId}${shared.delimiter.dash}')
var pipId = toLower('${shared.resIds.publicIp}${shared.delimiter.dash}${shared.locIds[location]}${shared.delimiter.dash}${lzId}${shared.delimiter.dash}${envId}${shared.delimiter.dash}')
var dnsrId = toLower('${shared.resIds.privateDnsResolver}${shared.delimiter.dash}${shared.locIds[location]}${shared.delimiter.dash}${lzId}${shared.delimiter.dash}${envId}${shared.delimiter.dash}')
var vnetAddressSpace = replace(varAddressPrefix, '/', '_')
var varAddressPrefix = first(addressPrefixes)

var resourceGroups = {
  network: '${argId}network'
  privateDns: '${argId}privatedns'
}

var resourceNames = {
  virtualNetwork: '${vntId}${vnetAddressSpace}'
  privateDnsResolver: '${dnsrId}privateresolver'
  privateDnsResolverRuleset: '${dnsrId}forwardingruleset'
  azureBastion: '${basId}${uniqueString(subscriptionId)}'
  azureFirewall: '${afwId}${uniqueString(subscriptionId)}'
  azureFirewallPolicy: '${afpId}${uniqueString(subscriptionId)}'
  routeTable: '${udrId}gatewaySubnet'
  bastionPublicIp: '${pipId}bastion'
  bastionNsg: '${nsgId}bastion'
  vpnGwyPublicIp1: '${pipId}vpnGwy1'
  vpnGwyPublicIp2: '${pipId}vpnGwy2'
  erGwyPublicIp: '${pipId}erGwy'
  azFwPublicIp: '${pipId}azFw'
  vpnGateway: '${vngId}vpnGwy'
  erGateway: '${vngId}erGwy'
}

@description('Resource: Subscription Placement - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/mgmt-groups/subscription-placement')
module subscriptionPlacement 'br/public:avm/ptn/mgmt-groups/subscription-placement:0.3.0' = if (subscriptionManagementGroupAssociationEnabled && !empty(subscriptionMgPlacement)) {
  name: take('subscriptionPlacement-${guid(deployment().name)}', 64)
  scope: az.tenant()
  params: {
    parSubscriptionPlacement: [
      {
        disableSubscriptionPlacement: false
        managementGroupId: subscriptionMgPlacement
        subscriptionIds: [
          subscriptionId
        ]
      }
    ]
  }
}

@description('Module: Subscription Tags')
module subscriptionTags '../../modules/tags/subscriptionTags.bicep' = if (!empty(tags)) {
  name: take('subscriptionTags-${guid(deployment().name)}', 64)
  scope: az.subscription(subscriptionId)
  params: {
    tags: tags
  }
}

@description('Module: Resource Group (Network) - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/resources/resource-group')
module resourceGroupForNetwork 'br/public:avm/res/resources/resource-group:0.4.3' = {
  scope: subscription(subscriptionId)
  name: 'resourceGroupForNetwork-${guid(deployment().name)}'
  params: {
    // Required parameters
    name: resourceGroups.network
    // Non-required parameters
    location: location
    tags: tags
  }
}

@description('Module: Azure Budgets - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/consumption/budget')
module budget 'br/public:avm/res/consumption/budget:0.3.8' = [
  for (bg, index) in (budgetConfiguration.?budgets ?? []): if (!empty(budgetConfiguration) && deployBudgets) {
    name: take('budget-${guid(deployment().name)}-${index}', 64)
    scope: subscription(subscriptionId)
    params: {
      // Required parameters
      amount: bg.amount
      name: bg.name
      // Non-required parameters
      contactEmails: bg.contactEmails
      location: location
      startDate: bg.startDate
      thresholdType: bg.thresholdType
      thresholds: bg.thresholds
    }
  }
]

@description('Resource Groups (Common) - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/resources/resource-group')
module commonResourceGroups 'br/public:avm/res/resources/resource-group:0.4.3' = [
  for commonResourceGroup in shared.commonResourceGroupNames: {
    name: take('commonResourceGroups-${commonResourceGroup}', 64)
    scope: subscription(subscriptionId)
    params: {
      // Required parameters
      name: commonResourceGroup
      // Non-required parameters
      location: location
      tags: tags
    }
  }
]

@description('Module: Network Watcher - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/network-watcher')
module networkWatcher 'br/public:avm/res/network/network-watcher:0.5.0' = {
  name: take('networkWatcher-${guid(deployment().name)}', 64)
  scope: resourceGroup(subscriptionId, 'networkWatcherRG')
  dependsOn: [
    commonResourceGroups
  ]
  params: {
    // Non-required parameters
    location: location
    tags: tags
  }
}

@description('Module: Service Health Alerts - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/subscription/service-health-alerts')
module serviceHealthAlerts 'br/public:avm/ptn/subscription/service-health-alerts:0.1.1' = if (!empty(actionGroupResourceId)) {
  name: take('serviceHealthAlerts-${guid(deployment().name)}', 64)
  scope: az.subscription(subscriptionId)
  params: {
    location: location
    serviceHealthAlerts: [
      for alert in shared.serviceHealthAlerts: {
        actionGroup: {
          enabled: true
          existingActionGroupResourceId: actionGroupResourceId
        }
        serviceHealthAlert: alert
      }
    ]
    serviceHealthAlertsResourceGroupName: 'alertsRG'
    subscriptionId: subscriptionId
    tags: tags
  }
}

@description('Module: Hub Networking')
module hubNetworking '../../modules/hubNetworking/hubNetworking.bicep' = {
  scope: resourceGroup(subscriptionId, resourceGroups.network)
  name: take('hubNetworking-${guid(deployment().name)}', 64)
  dependsOn: [
    resourceGroupForNetwork
  ]
  params: {
    location: location
    tags: tags
    erGwyEnabled: erGwyEnabled
    vpnGwyEnabled: vpnGwyEnabled
    azBastionEnabled: azBastionEnabled
    azFirewallEnabled: azFirewallEnabled
    azFirewallDnsProxyEnabled: azFirewallDnsProxyEnabled
    disableBGPRoutePropagation: disableBGPRoutePropagation
    azFirewallTier: azFirewallTier
    azFirewallPoliciesName: resourceNames.azureFirewallPolicy
    azBastionSku: azBastionSku
    azFirewallAvailabilityZones: azFirewallAvailabilityZones
    azErGatewayAvailabilityZones: azErGatewayAvailabilityZones
    azVpnGatewayAvailabilityZones: azVpnGatewayAvailabilityZones
    publicIpSku: publicIpSku
    addressPrefixes: addressPrefixes
    subnetsArray: subnetsArray
    dnsServerIps: dnsServerIps
    erGatewayConfig: erConcatConfig
    vpnGatewayConfig: vngConcatConfig
    azFirewallName: resourceNames.azureFirewall
    azBastionName: resourceNames.azureBastion
    hubRouteTableName: resourceNames.routeTable
    hubNetworkName: resourceNames.virtualNetwork
    vpnGwyPublicIpName1: resourceNames.vpnGwyPublicIp1
    vpnGwyPublicIpName2: resourceNames.vpnGwyPublicIp2
    erGwyPublicIpName: resourceNames.erGwyPublicIp
    azFirewallPublicIpName: resourceNames.azFwPublicIp
    azBastionPublicIpName: resourceNames.bastionPublicIp
    azBastionNsgName: resourceNames.bastionNsg
    vpnGatewayName: resourceNames.vpnGateway
    erGatewayName: resourceNames.erGateway
    gatewayRoutes: gatewayRoutes
    azFirewallIntelMode: azFirewallIntelMode
    azFirewallCustomPublicIps: azFirewallCustomPublicIps
    azBastionTunneling: azBastionTunneling
  }
}

@description('Module: Resource Group (PrivateDNS) - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/resources/resource-group')
module resourceGroupForPrivateDns 'br/public:avm/res/resources/resource-group:0.4.3' = if (privateDnsZonesEnabled || privateResolverEnabled) {
  scope: subscription(subscriptionId)
  name: take('resourceGroupForPrivateDns-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    name: resourceGroups.privateDns
    // Non-required parameters
    location: location
    tags: tags
  }
}

@description('Module: Private DNS Resolver')
module privateDnsResolver '../../modules/privateDnsResolver/privateDnsResolver.bicep' = if (privateResolverEnabled && (contains(
  map(subnetsArray, subnets => subnets.name),
  'inboundDNSSubnet'
)) && (contains(map(subnetsArray, subnets => subnets.name), 'outboundDNSSubnet'))) {
  name: take('privateDnsResolver-${guid(deployment().name)}', 64)
  scope: resourceGroup(subscriptionId, resourceGroups.privateDns)
  params: {
    forwardingRules: forwardingRules
    location: location
    privateDnsResolverName: resourceNames.privateDnsResolver
    privateDnsResolverRulesetName: resourceNames.privateDnsResolverRuleset
    tags: tags
    virtualNetworkResourceId: hubNetworking!.outputs.hubVirtualNetworkId
  }
}

/*
@description('Module: Private Link Private DNS Zones - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/network/private-link-private-dns-zones')
module privateLinkPrivateDnsZones 'br/public:avm/ptn/network/private-link-private-dns-zones:0.7.1' = {
  name: take('privateLinkPrivateDnsZones-${guid(deployment().name)}', 64)
  scope: resourceGroup(subscriptionId, resourceGroups.privateDns)
  dependsOn: [
    resourceGroupForPrivateDNS
  ]
  params: {
    additionalPrivateLinkPrivateDnsZonesToInclude: [
    ]
    location: location
    privateLinkPrivateDnsZones: [
      'privatelink.{regionCode}.backup.windowsazure.com'
      'privatelink.{regionName}.azmk8s.io'
      'privatelink.api.azureml.ms'
      'privatelink.notebooks.azure.net'
    ]
    privateLinkPrivateDnsZonesToExclude: [
    ]
    tags: tags
    virtualNetworkLinks: [
      {
        name: 'vnet2-link-custom-name'
        registrationEnabled: false
        resolutionPolicy: 'NxDomainRedirect'
        tags: tags
        virtualNetworkResourceId: '<virtualNetworkResourceId>'
      }
    ]
    virtualNetworkResourceIdsToLinkTo: [
      '<vnet1ResourceId>'
    ]
  }
}
*/
