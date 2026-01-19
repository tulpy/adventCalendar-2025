// Core Landing Zone User Defined Types for Azure Services https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/user-defined-data-types
import {
  lockType
} from 'br/public:avm/utl/types/avm-common-types:0.6.1' // Common Types including Locks, Managed Identities, Role Assignments, etc.

///////////////////////////////////////////////

// 1.0 hub Networking Type

///////////////////////////////////////////////

// 1.0 Hub Networking Type
@export()
@description('The type for Azure Container Registry configuration.')
type hubVirtualNetworkType = {
  @description('Required. The name of the hub.')
  name: string?

  @description('Required. The address prefixes for the virtual network.')
  addressPrefixes: array

  @description('Required. Azure Firewall configuration settings.')
  azureFirewallSettings: azureFirewallType

  @description('Required. Private DNS configuration settings.')
  privateDnsSettings: privateDnsType

  @description('Required. DDoS protection plan configuration settings.')
  ddosProtectionPlanSettings: ddosProtectionPlanType

  @description('Required. The location of the virtual network.')
  location: string

  @description('Optional. Resource ID of an existing DDoS protection plan to associate with the virtual network. If not specified and deployDdosProtectionPlan is true, a new DDoS protection plan will be created.')
  ddosProtectionPlanResourceId: string?

  @description('Optional. The DNS servers of the virtual network.')
  dnsServers: array?

  @description('Required. Deploy VNet peering for the virtual network.')
  deployPeering: bool

  @description('Optional. The peerings of the virtual network.')
  peeringSettings: peeringSettingsType?

  @description('Required. The subnets of the virtual network.')
  subnets: subnetOptionsType

  @description('Optional. Enable/Disable VNet encryption.')
  vnetEncryption: bool?

  @description('Optional. The VNet encryption enforcement settings of the virtual network.')
  vnetEncryptionEnforcement: 'AllowUnencrypted' | 'DropUnencrypted'?

  @description('Required. VPN gateway configuration settings.')
  vpnGatewaySettings: vpnGatewaySettingsType

  @description('Optional. ExpressRoute gateway configuration settings.')
  expressRouteGatewaySettings: expressRouteGatewaySettingsType?

  @description('Required. Azure Bastion configuration settings.')
  bastionHostSettings: bastionHostSettingsType

  @description('Optional. Lock settings for the virtual network.')
  lock: lockType?

  @description('Optional. Tags for the virtual network.')
  tags: object?
}[]

type bastionHostSettingsType = {
  @description('Required. Deploy Azure Bastion for the virtual network.')
  deployBastion: bool

  @description('Optional. Enable/Disable copy/paste functionality.')
  disableCopyPaste: bool?

  @description('Optional. Enable/Disable file copy functionality.')
  enableFileCopy: bool?

  @description('Optional. Enable/Disable IP connect functionality.')
  enableIpConnect: bool?

  @description('Optional. Enable/Disable shareable link functionality.')
  enableShareableLink: bool?

  @description('Optional. Enable/Disable Kerberos authentication.')
  enableKerberos: bool?

  @description('Optional. The number of scale units for the Bastion host.')
  scaleUnits: int?

  @description('Optional. The SKU name of the Bastion host.')
  skuName: 'Basic' | 'Developer' | 'Premium' | 'Standard'?

  @description('Optional. The name of the bastion host.')
  bastionHostSettingsName: string?

  @description('Optional. The bastion\'s outbound ssh and rdp ports.')
  outboundSshRdpPorts: array?

  @description('Optional. Lock settings for Bastion.')
  lock: lockType?

  @description('Optional. The name of the Bastion NSG.')
  bastionNsgName: string?

  @description('Optional. Custom security rules for the Bastion NSG.')
  bastionNsgSecurityRules: array?

  @description('Optional. Lock settings for Bastion NSG.')
  bastionNsgLock: lockType?

  @description('Optional. Availability zones for the Bastion host.')
  zones: int[]?

  @description('Optional. Tags for the Bastion host.')
  tags: object?
}

type peeringSettingsType = {
  @description('Optional. Allow forwarded traffic.')
  allowForwardedTraffic: bool?

  @description('Optional. Allow gateway transit.')
  allowGatewayTransit: bool?

  @description('Optional. Allow virtual network access.')
  allowVirtualNetworkAccess: bool?

  @description('Optional. Use remote gateways.')
  useRemoteGateways: bool?

  @description('Optional. Remote virtual network name.')
  remoteVirtualNetworkName: string?
}[]?

type ddosProtectionPlanType = {
  @description('Required. Deploy a DDoS protection plan in the same region as the virtual network. Typically only needed in the primary region (the 1st declared in `hubNetworks`).')
  deployDdosProtectionPlan: bool

  @description('Optional. The name of the DDoS protection plan.')
  name: string?

  @description('Optional. The location of the DDoS protection plan.')
  location: string?

  @description('Optional. Lock settings for DDoS protection plan.')
  lock: lockType?

  @description('Optional. Tags for DDoS protection plan.')
  tags: object?
}

type azureFirewallType = {
  @description('Required. Deploy Azure Firewall for the virtual network.')
  deployAzureFirewall: bool

  @description('Optional. The name of the Azure Firewall to create.')
  azureFirewallName: string?

  @description('Optional. Azure Firewall SKU.')
  azureSkuTier: 'Basic' | 'Standard' | 'Premium'?

  @description('Optional. Resource ID of an existing Azure Firewall Policy to associate with the firewall. If not specified and enableAzureFirewall is true, a new firewall policy will be created.')
  firewallPolicyId: string?

  @description('Optional. Lock settings.')
  lock: lockType?

  @description('Optional. Management IP address configuration.')
  managementIPAddressObject: object?

  @description('Optional. Public IP address object.')
  publicIPAddressObject: object?

  @description('Optional. Public IP resource ID.')
  publicIPResourceID: string?

  @description('Optional. Role assignments.')
  roleAssignments: roleAssignmentType?

  @description('Optional. Threat Intel mode.')
  threatIntelMode: ('Alert' | 'Deny' | 'Off')?

  @description('Optional. Availability zones for the Azure Firewall.')
  zones: int[]?

  @description('Optional. Enable/Disable dns proxy setting.')
  dnsProxyEnabled: bool?

  @description('Optional. Array of custom DNS servers used by Azure Firewall.')
  firewallDnsServers: array?

  @description('Optional. Tags for Azure Firewall.')
  tags: object?
}

type privateDnsType = {
  @description('Required. Deploy private DNS zones.')
  deployPrivateDnsZones: bool

  @description('Optional. Array of resource IDs of existing virtual networks to link to the Private DNS Zones. The hub virtual network is automatically included.')
  virtualNetworkResourceIdsToLinkTo: array?

  @description('Optional. Array of DNS Zones to provision and link to Hub Virtual Network. Default: All known Azure Private DNS Zones, baked into underlying AVM module see: https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/network/private-link-private-dns-zones#parameter-privatelinkprivatednszones')
  privateDnsZones: array?

  @description('Optional. Resource ID of an existing failover virtual network for Private DNS Zone VNet failover links.')
  virtualNetworkIdToLinkFailover: string?

  @description('Required. Deploy Private DNS Resolver.')
  deployDnsPrivateResolver: bool

  @description('Optional. The name of the Private DNS Resolver.')
  privateDnsResolverName: string?

  @description('Optional. Private DNS Resolver inbound endpoints configuration.')
  inboundEndpoints: array?

  @description('Optional. Private DNS Resolver outbound endpoints configuration.')
  outboundEndpoints: array?

  @description('Optional. Lock settings for Private DNS resources.')
  lock: lockType?

  @description('Optional. Tags for Private DNS resources.')
  tags: object?

  @description('Optional. An array of additional Private Link Private DNS Zones to include in the deployment on top of the defaults set in the parameter `privateLinkPrivateDnsZones`.')
  additionalPrivateLinkPrivateDnsZonesToInclude: string[]?

  @description('Optional. An array of Private Link Private DNS Zones to exclude from the deployment. The DNS zone names must match what is provided as the default values or any input to the `privateLinkPrivateDnsZones` parameter e.g. `privatelink.api.azureml.ms` or `privatelink.{regionCode}.backup.windowsazure.com` or `privatelink.{regionName}.azmk8s.io` .')
  privateLinkPrivateDnsZonesToExclude: string[]?
}

type roleAssignmentType = {
  @description('Optional. The name (as GUID) of the role assignment. If not provided, a GUID will be generated.')
  name: string?

  @description('Required. The role to assign. You can provide either the display name of the role definition, the role definition GUID, or its fully qualified ID in the following format: \'/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11\'.')
  roleDefinitionIdOrName: string

  @description('Required. The principal ID of the principal (user/group/identity) to assign the role to.')
  principalId: string

  @description('Optional. The principal type of the assigned principal ID.')
  principalType: ('ServicePrincipal' | 'Group' | 'User' | 'ForeignGroup' | 'Device')?

  @description('Optional. The description of the role assignment.')
  description: string?

  @description('Optional. The conditions on the role assignment. This limits the resources it can be assigned to. e.g.: @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:ContainerName] StringEqualsIgnoreCase "foo_storage_container".')
  condition: string?

  @description('Optional. Version of the condition.')
  conditionVersion: '2.0'?

  @description('Optional. The Resource Id of the delegated managed identity resource.')
  delegatedManagedIdentityResourceId: string?
}[]?

type diagnosticSettingType = {
  @description('Optional. The name of diagnostic setting.')
  name: string?

  @description('Optional. The name of logs that will be streamed. "allLogs" includes all possible logs for the resource. Set to `[]` to disable log collection.')
  logCategoriesAndGroups: {
    @description('Optional. Name of a Diagnostic Log category for a resource type this setting is applied to. Set the specific logs to collect here.')
    category: string?

    @description('Optional. Name of a Diagnostic Log category group for a resource type this setting is applied to. Set to `allLogs` to collect all logs.')
    categoryGroup: string?

    @description('Optional. Enable or disable the category explicitly. Default is `true`.')
    enabled: bool?
  }[]?

  @description('Optional. The name of metrics that will be streamed. "allMetrics" includes all possible metrics for the resource. Set to `[]` to disable metric collection.')
  metricCategories: {
    @description('Required. Name of a Diagnostic Metric category for a resource type this setting is applied to. Set to `AllMetrics` to collect all metrics.')
    category: string

    @description('Optional. Enable or disable the category explicitly. Default is `true`.')
    enabled: bool?
  }[]?

  @description('Optional. A string indicating whether the export to Log Analytics should use the default destination type, i.e. AzureDiagnostics, or use a destination type.')
  logAnalyticsDestinationType: ('Dedicated' | 'AzureDiagnostics')?

  @description('Optional. Resource ID of the diagnostic log analytics workspace. For security reasons, it is recommended to set diagnostic settings to send data to either storage account, log analytics workspace or event hub.value.')
  workspaceResourceId: string?

  @description('Optional. Resource ID of the diagnostic storage account. For security reasons, it is recommended to set diagnostic settings to send data to either storage account, log analytics workspace or event hub.value.')
  storageAccountResourceId: string?

  @description('Optional. Resource ID of the diagnostic event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to.')
  eventHubAuthorizationRuleResourceId: string?

  @description('Optional. Name of the diagnostic event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category. For security reasons, it is recommended to set diagnostic settings to send data to either storage account, log analytics workspace or event hub.value.')
  eventHubName: string?

  @description('Optional. The full ARM resource ID of the Marketplace resource to which you would like to send Diagnostic Logs.')
  marketplacePartnerResourceId: string?
}[]?

type subnetOptionsType = ({
  @description('Required. Name of subnet.')
  name: string

  @description('Required. IP-address range for subnet.')
  addressPrefix: string

  @description('Optional. Resource ID of Network Security Group to associate with subnet.')
  networkSecurityGroupId: string?

  @description('Optional. Resource ID of Route Table to associate with subnet.')
  routeTable: string?

  @description('Optional. Name of the delegation to create for the subnet.')
  delegation: string?
})[]

type vpnGatewaySettingsType = {
  @description('Required. Deploy VPN virtual network gateway.')
  deployVpnGateway: bool

  @description('Optional. The name of the virtual network gateway.')
  name: string?

  @description('Optional. The SKU name of the virtual network gateway.')
  skuName: 'VpnGw1AZ' | 'VpnGw2AZ' | 'VpnGw3AZ' | 'VpnGw4AZ' | 'VpnGw5AZ'

  @description('Optional. The VPN gateway configuration mode. Determines active/passive setup and BGP usage.')
  vpnMode: ('activeActiveBgp' | 'activeActiveNoBgp' | 'activePassiveBgp' | 'activePassiveNoBgp')?

  @description('Optional. The VPN type.')
  vpnType: 'RouteBased' | 'PolicyBased'?

  @description('Optional. The VPN gateway generation.')
  vpnGatewayGeneration: 'Generation1' | 'Generation2' | 'None'?

  @description('Optional. Enable BGP route translation for NAT scenarios.')
  enableBgpRouteTranslationForNat: bool?

  @description('Optional. Enable DNS forwarding through the VPN gateway.')
  enableDnsForwarding: bool?

  @description('Optional. The Autonomous System Number (ASN) for BGP configuration.')
  asn: int?

  @description('Optional. Custom BGP IP addresses for active-active BGP configurations.')
  customBgpIpAddresses: string[]?

  @description('Optional. Availability zones for the VPN gateway public IP addresses.')
  publicIpZones: array?

  @description('Optional. Domain name labels for the public IP addresses associated with the gateway.')
  domainNameLabel: string[]?

  @description('Optional. Lock settings for Virtual Network Gateway.')
  lock: lockType?

  @description('Optional. Tags for the VPN gateway.')
  tags: object?
}

type expressRouteGatewaySettingsType = {
  @description('Required. Deploy ExpressRoute gateway.')
  deployExpressRouteGateway: bool

  @description('Optional. The name of the ExpressRoute gateway.')
  name: string?

  @description('Optional. The SKU name of the ExpressRoute gateway.')
  skuName: 'Standard' | 'HighPerformance' | 'UltraPerformance' | 'ErGw1AZ' | 'ErGw2AZ' | 'ErGw3AZ' | 'ErGwScale'?

  @description('Optional. Enable DNS forwarding through the ExpressRoute gateway.')
  enableDnsForwarding: bool?

  @description('Optional. Enable private IP support on the ExpressRoute gateway.')
  enablePrivateIpAddress: bool?

  @description('Optional. Availability zones for the ExpressRoute gateway public IP addresses.')
  publicIpZones: array?

  @description('Optional. Lock settings for the ExpressRoute gateway.')
  lock: lockType?

  @description('Optional. Tags for the ExpressRoute gateway.')
  tags: object?
}
