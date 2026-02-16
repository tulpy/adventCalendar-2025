@export()
@description('Mapping of Azure region names to their corresponding short IDs.')
var locIds = {
  australiacentral: 'auc'
  australiacentral2: 'auc2'
  australiaeast: 'aue'
  australiasoutheast: 'ause'
  brazilsouth: 'brs'
  brazilsoutheast: 'brse'
  canadacentral: 'canc'
  canadaeast: 'cane'
  centralindia: 'cin'
  centralus: 'cus'
  centraluseuap: 'cuseuap'
  eastasia: 'ea'
  eastus: 'eus'
  eastus2: 'eus2'
  eastus2euap: 'eus2euap'
  francecentral: 'frc'
  francesouth: 'frs'
  germanynorth: 'gern'
  germanywestcentral: 'gerwc'
  japaneast: 'jae'
  japanwest: 'jaw'
  jioindiacentral: 'jioinc'
  jioindiawest: 'jioinw'
  koreacentral: 'koc'
  koreasouth: 'kors'
  northcentralus: 'ncus'
  northeurope: 'neu'
  norwayeast: 'nore'
  norwaywest: 'norw'
  southafricanorth: 'san'
  southafricawest: 'saw'
  southcentralus: 'scus'
  southeastasia: 'sea'
  southindia: 'sin'
  swedencentral: 'swc'
  switzerlandnorth: 'swn'
  switzerlandwest: 'sww'
  uaecentral: 'uaec'
  uaenorth: 'uaen'
  uksouth: 'uks'
  ukwest: 'ukw'
  westcentralus: 'wcus'
  westeurope: 'weu'
  westindia: 'win'
  westus: 'wus'
  westus2: 'wus2'
  westus3: 'wus3'
}

@export()
@description('Short IDs used for various Azure resources.')
var resIds = {
  azureAutomationAccount: 'aaa'
  azureBastion: 'bas'
  azureDdos: 'ddos'
  azureFirewall: 'afw'
  azureFirewallPolicy: 'afp'
  bastionHost: 'bas'
  dataCollectionRule: 'dcr'
  keyVault: 'kv'
  logAnalytics: 'law'
  networkSecurityGroup: 'nsg'
  networkSecurityPerimeter: 'nsp'
  platform: 'plat'
  platformConn: 'conn'
  platformIdam: 'idam'
  platformMgmt: 'mgmt'
  publicIp: 'pip'
  privateDnsResolver: 'dnsr'
  recoveryServicesVault: 'rsv'
  resourceGroup: 'arg'
  routeTable: 'udr'
  storageAccount: 'st'
  userAssignedIdentity: 'uai'
  virtualNetwork: 'vnt'
  virtualNetworkGateway: 'vng'
}

@export()
@description('Common resource group names across Subscriptions.')
var commonResourceGroupNames = [
  'alertsRG'
  'networkWatcherRG'
  'ascExportRG'
]

@export()
@description('Service health alert types.')
var serviceHealthAlerts = [
  'Resource Health Unhealthy'
  'Service Health Advisory'
  'Service Health Incident'
  'Service Health Maintenance'
  'Service Health Security'
]

@export()
@description('Shared Network Security Group inbound rules.')
var sharedNSGrulesInbound = [
  {
    name: 'INBOUND-FROM-virtualNetwork-TO-virtualNetwork-PORT-any-PROT-Icmp-ALLOW'
    properties: {
      protocol: 'Icmp'
      sourcePortRange: '*'
      sourcePortRanges: []
      destinationPortRange: '*'
      destinationPortRanges: []
      sourceAddressPrefix: 'VirtualNetwork'
      sourceAddressPrefixes: []
      sourceApplicationSecurityGroupIds: []
      destinationAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefixes: []
      destinationApplicationSecurityGroupIds: []
      access: 'Allow'
      priority: 1000
      direction: 'Inbound'
      description: 'Shared - Allow Outbound ICMP traffic (Port *) from the subnet.'
    }
  }
  {
    name: 'INBOUND-FROM-any-TO-any-PORT-any-PROT-any-DENY'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      sourcePortRanges: []
      destinationPortRange: '*'
      destinationPortRanges: []
      sourceAddressPrefix: '*'
      sourceAddressPrefixes: []
      sourceApplicationSecurityGroupIds: []
      destinationAddressPrefix: '*'
      destinationAddressPrefixes: []
      destinationApplicationSecurityGroupIds: []
      access: 'Deny'
      priority: 4096
      direction: 'Inbound'
      description: 'Shared - Deny Inbound traffic (Port *) from the subnet.'
    }
  }
]

@export()
@description('Shared Network Security Group outbound rules.')
var sharedNSGrulesOutbound = [
  {
    name: 'OUTBOUND-FROM-virtualNetwork-TO-virtualNetwork-PORT-any-PROT-Icmp-ALLOW'
    properties: {
      protocol: 'Icmp'
      sourcePortRange: '*'
      sourcePortRanges: []
      destinationPortRange: '*'
      destinationPortRanges: []
      sourceAddressPrefix: 'VirtualNetwork'
      sourceAddressPrefixes: []
      sourceApplicationSecurityGroupIds: []
      destinationAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefixes: []
      destinationApplicationSecurityGroupIds: []
      access: 'Allow'
      priority: 1000
      direction: 'Outbound'
      description: 'Shared - Allow Outbound ICMP traffic (Port *) from the subnet.'
    }
  }
  {
    name: 'OUTBOUND-FROM-virtualNetwork-TO-virtualNetwork-PORT-any-PROT-any-ALLOW'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      sourcePortRanges: []
      destinationPortRange: '*'
      destinationPortRanges: []
      sourceAddressPrefix: 'VirtualNetwork'
      sourceAddressPrefixes: []
      sourceApplicationSecurityGroupIds: []
      destinationAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefixes: []
      destinationApplicationSecurityGroupIds: []
      access: 'Allow'
      priority: 1001
      direction: 'Outbound'
      description: 'Shared - Allow Outbound Virtual Network to Virtual Network traffic (Port *) from the subnet.'
    }
  }
  {
    name: 'OUTBOUND-FROM-subnet-TO-any-PORT-443-PROT-Tcp-ALLOW'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourcePortRanges: []
      destinationPortRange: '443'
      destinationPortRanges: []
      sourceAddressPrefix: '*'
      sourceAddressPrefixes: []
      sourceApplicationSecurityGroupIds: []
      destinationAddressPrefix: '*'
      destinationAddressPrefixes: []
      destinationApplicationSecurityGroupIds: []
      access: 'Allow'
      priority: 1150
      direction: 'Outbound'
      description: 'Shared - Allow Outbound HTTPS traffic (Port 443) from the subnet.'
    }
  }
  {
    name: 'OUTBOUND-FROM-subnet-TO-KMS-PORT-1688-PROT-Tcp-ALLOW'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourcePortRanges: []
      destinationPortRange: ''
      destinationPortRanges: ['1688']
      sourceAddressPrefix: '*'
      sourceAddressPrefixes: []
      sourceApplicationSecurityGroupIds: []
      destinationAddressPrefix: ''
      destinationAddressPrefixes: ['20.118.99.224/32', '40.83.235.53/32', '23.102.135.246/32']
      destinationApplicationSecurityGroupIds: []
      access: 'Allow'
      priority: 1200
      direction: 'Outbound'
      description: 'Shared - Allow Outbound KMS traffic (Port 1688) from the subnet.'
    }
  }
  {
    name: 'OUTBOUND-FROM-any-TO-any-PORT-any-PROT-any-DENY'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      sourcePortRanges: []
      destinationPortRange: '*'
      destinationPortRanges: []
      sourceAddressPrefix: '*'
      sourceAddressPrefixes: []
      sourceApplicationSecurityGroupIds: []
      destinationAddressPrefix: '*'
      destinationAddressPrefixes: []
      destinationApplicationSecurityGroupIds: []
      access: 'Deny'
      priority: 4096
      direction: 'Outbound'
      description: 'Shared - Deny Outbound traffic (Port *) from the subnet.'
    }
  }
]

@export()
@description('Shared Network Routes.')
var sharedRoutes = [
  {
    name: 'FROM-subnet-TO-default-0.0.0.0-0'
    properties: {
      addressPrefix: '0.0.0.0/0'
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: '1.1.1.1'
    }
  }
]
