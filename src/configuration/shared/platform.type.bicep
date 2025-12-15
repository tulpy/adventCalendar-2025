// Platform Landing Zone User Defined Types for Azure Services https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/user-defined-data-types
import * as commonTypes from 'br/public:avm/utl/types/avm-common-types:0.6.1' // Common Types including Locks, Managed Identities, Role Assignments, etc.

///////////////////////////////////////////////

// 1.0 Platform Landing Zone Types
// 1.1 Log Analytics Workspace Type
// 1.2 Azure Maintenance Configuration Type
// 1.3 Azure Virtual Network Gateway Type
// 1.4 Azure Local Network Gateway Type
// 1.5 Azure VPN Connection Type
// 1.6 Azure vWAN VPN Connection Type
// 1.7 Azure Container Registry Type
// 1.8 Azure Bastion Type

///////////////////////////////////////////////

// 1.0 Platform Landing Zone Types
// 1.1 Log Analytics Workspace Type
import {
  storageInsightsConfigType
  linkedServiceType
  linkedStorageAccountType
  savedSearchType
  dataExportType
  dataSourceType
  tableType
  gallerySolutionType
  workspaceFeaturesType
  workspaceReplicationType
} from 'br/public:avm/res/operational-insights/workspace:0.14.2'
@export()
@description('The type for Log Analytics configuration.')
type logAnalyticsType = {
  @minLength(4)
  @maxLength(63)
  @description('Optional. The name of the Log Analytics workspace.')
  name: string?

  @description('Optional. The name of the SKU.')
  skuName: (
    | 'CapacityReservation'
    | 'Free'
    | 'LACluster'
    | 'PerGB2018'
    | 'PerNode'
    | 'Premium'
    | 'Standalone'
    | 'Standard')?

  @minValue(100)
  @maxValue(5000)
  @description('Optional. The capacity reservation level in GB for this workspace, when CapacityReservation sku is selected. Must be in increments of 100 between 100 and 5000.')
  skuCapacityReservationLevel: int?

  @description('Optional. List of storage accounts to be read by the workspace.')
  storageInsightsConfigs: storageInsightsConfigType[]?

  @description('Optional. List of services to be linked.')
  linkedServices: linkedServiceType[]?

  @description('Conditional. List of Storage Accounts to be linked. Required if \'forceCmkForQuery\' is set to \'true\' and \'savedSearches\' is not empty.')
  linkedStorageAccounts: linkedStorageAccountType[]?

  @description('Optional. Kusto Query Language searches to save.')
  savedSearches: savedSearchType[]?

  @description('Optional. LAW data export instances to be deployed.')
  dataExports: dataExportType[]?

  @description('Optional. LAW data sources to configure.')
  dataSources: dataSourceType[]?

  @description('Optional. LAW custom tables to be deployed.')
  tables: tableType[]?

  @description('Optional. List of gallerySolutions to be created in the log analytics workspace.')
  gallerySolutions: gallerySolutionType[]?

  @description('Optional. Onboard the Log Analytics Workspace to Sentinel. Requires \'SecurityInsights\' solution to be in gallerySolutions.')
  onboardWorkspaceToSentinel: bool?

  @description('Optional. Number of days data will be retained for.')
  @minValue(0)
  @maxValue(730)
  dataRetention: int?

  @description('Optional. The workspace daily quota for ingestion.')
  @minValue(-1)
  dailyQuotaGb: int?

  @description('Optional. The network access type for accessing Log Analytics ingestion.')
  publicNetworkAccessForIngestion: ('Enabled' | 'Disabled')?

  @description('Optional. The network access type for accessing Log Analytics query.')
  publicNetworkAccessForQuery: ('Enabled' | 'Disabled')?

  @description('Optional. The workspace features.')
  features: workspaceFeaturesType?

  @description('Optional. The workspace replication properties.')
  replication: workspaceReplicationType?

  @description('Optional. Indicates whether customer managed storage is mandatory for query management.')
  forceCmkForQuery: bool?

  @description('Optional. Tags of the resource.')
  tags: resourceInput<'Microsoft.OperationalInsights/workspaces@2025-02-01'>.tags?

  @description('Optional. The lock settings of the service.')
  lock: commonTypes.lockType?

  @description('Optional. Array of role assignments to create.')
  roleAssignments: commonTypes.roleAssignmentType[]?
}

// 1.2 Azure Maintenance Configuration Type
@export()
@description('The type for Azure Maintenance configuration.')
type maintenanceConfigurationType = {
  @description('Optional. The name of the Maintenance configuration.')
  name: string?

  @description('Optional. Gets or sets extensionProperties of the maintenanceConfiguration.')
  extensionProperties: object?

  @description('Optional. Gets or sets maintenanceScope of the configuration.')
  maintenanceScope: 'Host' | 'OSImage' | 'Extension' | 'InGuestPatch' | 'SQLDB' | 'SQLManagedInstance'?

  @description('Optional. Definition of a MaintenanceWindow.')
  maintenanceWindow: object?

  @description('Optional. Gets or sets namespace of the resource.')
  namespace: string?

  @description('Optional. Gets or sets the visibility of the configuration. The default value is \'Custom\'.')
  visibility: 'Custom' | 'Public' | ''?

  @description('Optional. Configuration settings for VM guest patching with Azure Update Manager.')
  installPatches: object?

  @description('Optional. The lock settings of the service.')
  lock: commonTypes.lockType?

  @description('Optional. Array of role assignments to create.')
  roleAssignments: commonTypes.roleAssignmentType[]?
}

// 1.3 Azure Virtual Network Gateway Type
@export()
@description('The type for Virtual Network Gateway configuration.')
type virtualNetworkGatewayType = {
  @description('Optional. Name of the Virtual Network gateway.')
  name: string?

  @description('Required. Type of gateway.')
  gatewayType: ('Vpn' | 'ExpressRoute')

  @description('Required. SKU of the gateway.')
  sku: (
    | 'Basic'
    | 'VpnGw1AZ'
    | 'VpnGw2AZ'
    | 'VpnGw3AZ'
    | 'VpnGw4AZ'
    | 'VpnGw5AZ'
    | 'ErGw1AZ'
    | 'ErGw2AZ'
    | 'ErGw3AZ'
    | 'ErGwScale'
    | 'HighPerformance'
    | 'Standard'
    | 'UltraPerformance')

  @description('Required. Type of VPN.')
  vpnType: ('PolicyBased' | 'RouteBased')

  @description('Required. Generation of the VPN Gateway.')
  vpnGatewayGeneration: ('Generation1' | 'Generation2' | 'None')

  @description('Optional. Enable BGP on the gateway.')
  enableBgp: bool?

  @description('Optional. Enable Active-Active on the gateway.')
  activeActive: bool?

  @description('Optional. Enable BGP Route Translation for NAT on the gateway.')
  enableBgpRouteTranslationForNat: bool?

  @description('Optional. Enable DNS Forwarding on the gateway.')
  enableDnsForwarding: bool?

  @description('Optional. BGP Settings for the gateway.')
  bgpSettings: {
    @minValue(0)
    @maxValue(4294967295)
    @description('Optional. ASN for the gateway.')
    asn: int?

    @description('Optional. Peer Weight for the gateway.')
    peerWeight: int?
  }?

  @description('Optional. VPN Client Configuration for the gateway.')
  vpnClientConfiguration: object?
}

// 1.4 Azure Local Network Gateway Type
import { bgpSettingsType } from 'br/public:avm/res/network/local-network-gateway:0.4.0'
@export()
@description('The Local Network Gateway Type.')
type localNetworkGatewayType = {
  @minLength(1)
  @maxLength(64)
  @description('Required. Name of the Local Network Gateway.')
  name: string

  @description('Required. List of the local (on-premises) IP address ranges.')
  localAddressPrefixes: string[]

  @description('Required. Public IP of the local gateway.')
  localGatewayPublicIpAddress: string

  @description('Optional. The BGP speaker\'s ASN. Not providing this value will automatically disable BGP on this Local Network Gateway resource.')
  localAsn: string?

  @description('Optional. The BGP peering address and BGP identifier of this BGP speaker. Not providing this value will automatically disable BGP on this Local Network Gateway resource.')
  localBgpPeeringAddress: string?

  @description('Optional. The weight added to routes learned from this BGP speaker. This will only take effect if both the localAsn and the localBgpPeeringAddress values are provided.')
  localPeerWeight: string?

  @description('Optional. FQDN of local network gateway.')
  fqdn: string?

  @description('Optional. Local network gateway\'s BGP speaker settings.')
  bgpSettings: bgpSettingsType?

  @description('Optional. Tags of the resource.')
  tags: resourceInput<'Microsoft.Network/localNetworkGateways@2024-07-01'>.tags?

  @description('Optional. Array of role assignments to create.')
  roleAssignments: commonTypes.roleAssignmentType[]?

  @description('Optional. The lock settings of the service.')
  lock: commonTypes.lockType?
}[]

// 1.5 Azure VPN Connection Type
import { trafficSelectorPolicyType, customIPSecPolicyType } from 'br/public:avm/res/network/connection:0.1.6'
@export()
@description('The type for VPN configuration.')
type hubVpnConnectionType = {
  @description('Required. The type for VPN Link Connection for each local network gateway.')
  vpnLinkConnection: {
    @description('Required. Name of the VPN link connection.')
    name: string

    @description('Optional. Value to specify if BGP is enabled or not.')
    enableBgp: bool?

    @description('Optional. Gateway connection connectionType.')
    connectionType: 'IPsec' | 'Vnet2Vnet' | 'ExpressRoute' | 'VPNClient'

    @description('Optional. Connection connectionProtocol used for this connection. Available for IPSec connections.')
    connectionProtocol: 'IKEv1' | 'IKEv2'

    @description('Optional. The weight added to routes learned from this BGP speaker.')
    routingWeight: int?

    @description('Optional. Bypass the ExpressRoute gateway when accessing private-links. ExpressRoute FastPath (expressRouteGatewayBypass) must be enabled. Only available when connection connectionType is Express Route.')
    enablePrivateLinkFastPath: bool?

    @description('Optional. Bypass ExpressRoute Gateway for data forwarding. Only available when connection connectionType is Express Route.')
    expressRouteGatewayBypass: bool?

    @minValue(9)
    @maxValue(3600)
    @description('Optional. The dead peer detection timeout of this connection in seconds. Setting the timeout to shorter periods will cause IKE to rekey more aggressively, causing the connection to appear to be disconnected in some instances. The general recommendation is to set the timeout between 30 to 45 seconds.')
    dpdTimeoutSeconds: int?

    @description('Optional. The connection connectionMode for this connection. Available for IPSec connections.')
    connectionMode: 'Default' | 'InitiatorOnly' | 'ResponderOnly'

    @description('Optional. Use private local Azure IP for the connection. Only available for IPSec Virtual Network Gateways that use the Azure Private IP Property.')
    useLocalAzureIpAddress: bool?

    @description('Optional. Enable policy-based traffic selectors.')
    usePolicyBasedTrafficSelectors: bool?

    @description('Optional. The traffic selector policies to be considered by this connection.')
    trafficSelectorPolicies: trafficSelectorPolicyType[]?

    @description('Optional. The IPSec Policies to be considered by this connection.')
    customIPSecPolicy: customIPSecPolicyType

    @description('Optional. Tags of the resource.')
    tags: resourceInput<'Microsoft.Network/connections@2024-05-01'>.tags?

    @description('Optional. The lock settings of the service.')
    lock: commonTypes.lockType?

    @description('Optional. Array of role assignments to create.')
    roleAssignments: commonTypes.roleAssignmentType[]?
  }[]
}

// 1.6 Azure vWAN VPN Connection Type
@export()
@description('The type for vWAN VPN configuration.')
type vwanVpnConnectionType = {
  @description('Required. VPN Site Configuration.')
  vpnSite: {
    @description('Required. Name of the VPN Site.')
    name: string

    @description('Optional. An array of IP address ranges that can be used by subnets of the virtual network. Required if no bgpProperties or VPNSiteLinks are configured.')
    addressPrefixes: string[]?

    @description('Optional. List of properties of the device.')
    deviceProperties: {
      @description('Model of the device.')
      deviceModel: string?

      @description('Device vendor.')
      deviceVendor: string?

      @description('Link speed.')
      linkSpeedInMbps: int?
    }?
  }[]

  @description('Optional. List of all VPN site links.')
  vpnSiteLinks: {
    @description('Required. Name of the VPN Site Link.')
    name: string

    @description('The set of bgp properties.')
    bgpProperties: {
      @description('Optional. The BGP peering address and BGP identifier of this BGP speaker.')
      bgpPeeringAddress: string?

      @description('Optional. The BGP speaker ASN.')
      asn: int?
    }?

    @description('The link provider properties.')
    linkProperties: {
      @description('Name of the link provider.')
      linkProviderName: string?

      @description('Link speed.')
      linkSpeedInMbps: int?
    }

    @description('The ip-address for the vpn-site-link.')
    ipAddress: string

    @description('FQDN of vpn-site-link.')
    fqdn: string
  }[]?

  @description('Optional. The type for VPN Link Connections.')
  vpnLinkConnections: {
    @description('Required. Name of the VPN link connection.')
    name: string

    @description('Optional. Expected bandwidth in MBPS.')
    connectionBandwidth: int?

    @description('Optional. Value to specify if BGP is enabled or not.')
    enableBgp: bool?

    @description('Optional. The IPSec Policies to be considered by this connection.')
    ipsecPolicies: {
      @description('Required. The IPSec Security Association (also called Quick Mode or Phase 2 SA) lifetime in seconds for a site to site VPN tunnel.')
      saLifeTimeSeconds: int

      @description('Required. The IPSec Security Association (also called Quick Mode or Phase 2 SA) payload size in KB for a site to site VPN tunnel.')
      saDataSizeKilobytes: int

      @description('Required. The IPSec encryption algorithm (IKE phase 1).')
      ipsecEncryption:
        | 'AES128'
        | 'AES192'
        | 'AES256'
        | 'DES'
        | 'DES3'
        | 'GCMAES128'
        | 'GCMAES192'
        | 'GCMAES256'
        | 'None'

      @description('Required. The IPSec integrity algorithm (IKE phase 1).')
      ipsecIntegrity: 'GCMAES128' | 'GCMAES192' | 'GCMAES256' | 'MD5' | 'SHA1' | 'SHA256'

      @description('Required. The IKE encryption algorithm (IKE phase 2).')
      ikeEncryption: 'AES128' | 'AES192' | 'AES256' | 'DES' | 'DES3' | 'GCMAES128' | 'GCMAES256'

      @description('Required. The IKE integrity algorithm (IKE phase 2).')
      ikeIntegrity: 'GCMAES128' | 'GCMAES256' | 'MD5' | 'SHA1' | 'SHA256' | 'SHA384'

      @description('Required. The DH Group used in IKE Phase 1 for initial SA.')
      dhGroup: 'None' | 'DHGroup1' | 'DHGroup2' | 'DHGroup14' | 'DHGroup2048' | 'DHGroup24' | 'ECP256' | 'ECP384'

      @description('Required. The Pfs Group used in IKE Phase 2 for new child SA.')
      pfsGroup: 'ECP256' | 'ECP384' | 'None' | 'PFS1' | 'PFS14' | 'PFS2' | 'PFS2048' | 'PFS24' | 'PFSMM'
    }[]?

    @description('Optional. Routing weight for vpn connection.')
    routingWeight: int?

    @description('Optional. Use private local Azure IP for the connection. Only available for IPSec Virtual Network Gateways that use the Azure Private IP Property.')
    useLocalAzureIpAddress: bool?

    @description('Optional. Enable policy-based traffic selectors.')
    usePolicyBasedTrafficSelectors: bool?

    @description('Optional. Connection protocol used for this connection.')
    vpnConnectionProtocolType: ('IKEv1' | 'IKEv2')?

    @description('Optional. vpnGatewayCustomBgpAddresses used by this connection.')
    vpnGatewayCustomBgpAddresses: {
      @description('Required. The custom BgpPeeringAddress which belongs to IpconfigurationId.')
      customBgpIpAddress: string

      @description('Required. The IpconfigurationId of ipconfiguration which belongs to gateway..')
      ipConfigurationId: string
    }[]?

    @description('Optional. Vpn link connection mode.')
    vpnLinkConnectionMode: 'Default' | 'InitiatorOnly' | 'ResponderOnly'
  }[]?
}

// 1.7 Azure Container Registry Type
import { scopeMapsType, cacheRuleType, credentialSetType, replicationType, webhookType } from 'br/public:avm/res/container-registry/registry:0.9.3'
@export()
@description('The type for Azure Container Registry configuration.')
type containerRegistryType = {
  @minLength(5)
  @maxLength(50)
  @description('Optional. The name of the container registry, Container registry names must be globally unique.')
  name: string?

  @description('Optional. Whether the trust policy is enabled for the container registry. Defaults to \'enabled\'.')
  trustPolicyStatus: 'enabled' | 'disabled'?

  @description('Optional. Tier of your Azure container registry.')
  sku: 'Basic' | 'Standard' | 'Premium'?

  @description('Optional. This value can be set to \'Enabled\' to avoid breaking changes on existing customer resources and templates. If set to \'Disabled\', traffic over public interface is not allowed, and private endpoint connections would be the exclusive access method.')
  publicNetworkAccess: 'Enabled' | 'Disabled'?

  @description('Optional. Soft Delete policy status. Default is disabled.')
  softDeletePolicyStatus: 'disabled' | 'enabled'?

  @description('Optional. The number of days after which a soft-deleted item is permanently deleted.')
  softDeletePolicyDays: int?

  @description('Optional. Enable admin user that have push / pull permission to the registry.')
  acrAdminUserEnabled: bool?

  @description('Optional. The value that indicates whether the export policy is enabled or not.')
  exportPolicyStatus: 'disabled' | 'enabled'?

  @description('Optional. Whether or not zone redundancy is enabled for this container registry.')
  zoneRedundancy: 'Disabled' | 'Enabled'?

  @description('Optional. Whether to allow trusted Azure services to access a network restricted registry.')
  networkRuleBypassOptions: 'AzureServices' | 'None'?

  @description('Optional. The default action of allow or deny when no other rules match.')
  networkRuleSetDefaultAction: 'Allow' | 'Deny'?

  @description('Optional. Enables registry-wide pull from unauthenticated clients. It\'s in preview and available in the Standard and Premium service tiers.')
  anonymousPullEnabled: bool?

  @description('Optional. Scope maps setting.')
  scopeMaps: scopeMapsType[]?

  @description('Optional. Array of Cache Rules.')
  cacheRules: cacheRuleType[]?

  @description('Optional. Array of Credential Sets.')
  credentialSets: credentialSetType[]?

  @description('Optional. All replications to create.')
  replications: replicationType[]?

  @description('Optional. All webhooks to create.')
  webhooks: webhookType[]?

  @description('Optional. Tags of the resource.')
  tags: resourceInput<'Microsoft.ContainerRegistry/registries@2025-04-01'>.tags?

  @description('Optional. The lock settings of the service.')
  lock: commonTypes.lockType?

  @description('Optional. Array of role assignments to create.')
  roleAssignments: commonTypes.roleAssignmentType[]?
}

// 1.8 Azure Container Registry Type
import { publicIPAddressObjectType } from 'br/public:avm/res/network/bastion-host:0.8.2'
@export()
@description('The type for Azure Container Registry configuration.')
type bastionHostType = {
  @description('Required. Name of the Azure Bastion resource.')
  name: string?

  @description('Required. Shared services Virtual Network resource Id.')
  virtualNetworkResourceId: string?

  @description('Optional. The Public IP resource ID to associate to the azureBastionSubnet. If empty, then the Public IP that is created as part of this module will be applied to the azureBastionSubnet. This parameter is ignored when enablePrivateOnlyBastion is true.')
  bastionSubnetPublicIpResourceId: string?

  @description('Optional. Specifies the properties of the Public IP to create and be used by Azure Bastion, if no existing public IP was provided. This parameter is ignored when enablePrivateOnlyBastion is true.')
  publicIPAddressObject: publicIPAddressObjectType?

  @description('Optional. The lock settings of the service.')
  lock: commonTypes.lockType?

  @description('Optional. Array of role assignments to create.')
  roleAssignments: commonTypes.roleAssignmentType[]?

  @description('Optional. The SKU of this Bastion Host.')
  skuName: ('Basic' | 'Developer' | 'Premium' | 'Standard')?

  @description('Optional. Choose to disable or enable Copy Paste. For Basic and Developer SKU Copy/Paste is always enabled.')
  disableCopyPaste: bool?

  @description('Optional. Choose to disable or enable File Copy. Not supported for Basic and Developer SKU.')
  enableFileCopy: bool?

  @description('Optional. Choose to disable or enable IP Connect. Not supported for Basic and Developer SKU.')
  enableIpConnect: bool?

  @description('Optional. Choose to disable or enable Kerberos authentication. Not supported for Developer SKU.')
  enableKerberos: bool?

  @description('Optional. Choose to disable or enable Shareable Link. Not supported for Basic and Developer SKU.')
  enableShareableLink: bool?

  @description('Optional. Choose to disable or enable Session Recording feature. The Premium SKU is required for this feature. If Session Recording is enabled, the Native client support will be disabled.')
  enableSessionRecording: bool?

  @description('Optional. Choose to disable or enable Private-only Bastion deployment. The Premium SKU is required for this feature.')
  enablePrivateOnlyBastion: bool?

  @description('Optional. The scale units for the Bastion Host resource. The Basic and Developer SKU only support 2 scale units.')
  scaleUnits: int?

  @description('Optional. Tags of the resource.')
  tags: resourceInput<'Microsoft.Network/bastionHosts@2024-07-01'>.tags?

  @description('Optional. The list of Availability zones to use for the zone-redundant resources.')
  availabilityZones: (1 | 2 | 3)[]? // Availability Zones are currently in preview (August 2025, see https://learn.microsoft.com/en-us/azure/bastion/configuration-settings#az) and only available in certain regions, therefore the default is an empty array.
}
