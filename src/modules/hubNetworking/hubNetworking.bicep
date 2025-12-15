import {
  // Platform Landing Zone User Defined Types
  virtualNetworkGatewayType
} from '../../configuration/shared/platform.type.bicep'

import {
  // Base Landing Zone User Defined Types
  tagsType
} from '../../configuration/shared/lz.type.bicep'

metadata name = 'ALZ Bicep - Hub Networking Module'
metadata description = 'Module used to set up Hub Networking.'
metadata version = '2.0.0'
metadata author = 'Insight APAC Platform Engineering'

type subnetOptionsType = ({
  @description('Name of subnet.')
  name: string
  @description('IP-address range for subnet.')
  ipAddressRange: string
  @description('Id of Network Security Group to associate with subnet.')
  networkSecurityGroupId: string?
  @description('Id of Route Table to associate with subnet.')
  routeTableId: string?
  @description('Name of the delegation to create for the subnet.')
  delegation: string?
})[]

@description('Optional. The Azure Region to deploy the resources into.')
param location string = resourceGroup().location

@description('Optional. Tags that will be applied to all resources in this module.')
param tags tagsType

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

@description('Optional. Switch which allows Azure DDoS deployment to be provisioned.')
param ddosEnabled bool = false

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
param azFirewallIntelMode string = 'Alert'

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

@description('Optional. Name Associated with Bastion Service.')
param azBastionName string = ''

@description('Optional. Azure Firewall Name.')
param azFirewallName string = ''

@description('Optional. Azure Firewall Policies Name.')
param azFirewallPoliciesName string = ''

@description('Optional. Name of Route table to create for the default route of Hub.')
param hubRouteTableName string = ''

@description('Required. Prefix Used for Hub Network.')
param hubNetworkName string

@description('Optional. Azure Firewall Public IP Name.')
param azFirewallPublicIpName string = ''

@description('Optional. Azure Firewall Public IP Mgmt Name.')
param azFirewallMgmtPublicIpName string = ''

@description('Optional. NSG Name for Azure Bastion Subnet NSG.')
param azBastionNsgName string = ''

@description('Optional. Name of Azure Bastion Public Ip.')
param azBastionPublicIpName string = ''

@description('Optional. Name of ER Gateway.')
param erGatewayName string = ''

@description('Optional. Name of ER Gateway Public Ip.')
param erGwyPublicIpName string = ''

@description('Optional. Name of VPN Gateway.')
param vpnGatewayName string = ''

@description('Optional. Name of VPN Gateway Public Ip 1.')
param vpnGwyPublicIpName1 string = ''

@description('Optional. Name of VPN Gateway Public Ip 2.')
param vpnGwyPublicIpName2 string = ''

@description('Optional. Switch which allows BGP Propagation to be disabled on the route tables.')
param disableBGPRoutePropagation bool = false

@description('Optional. An Array of Routes to be established within the route table for Gateway Subnet.')
param gatewayRoutes array = []

//ASN must be 65515 if deploying VPN & ER for co-existence to work: <https://docs.microsoft.com/en-us/azure/expressroute/expressroute-howto-coexist-resource-manager#limits-and-limitations/>
@description('Optional. Configuration for VPN virtual network gateway to be deployed. If a VPN virtual network gateway is not desired an empty object should be used as the input parameter in the parameter file, i.e.')
param vpnGatewayConfig virtualNetworkGatewayType = {
  name: vpnGatewayName
  gatewayType: 'Vpn'
  sku: 'VpnGw1AZ'
  vpnType: 'RouteBased'
  vpnGatewayGeneration: 'Generation1'
  enableBgp: true
  activeActive: true
  enableBgpRouteTranslationForNat: false
  enableDnsForwarding: false
  bgpSettings: {}
  vpnClientConfiguration: {}
}

@description('Optional. Configuration for ExpressRoute virtual network gateway to be deployed. If a ExpressRoute virtual network gateway is not desired an empty object should be used as the input parameter in the parameter file, i.e.')
param erGatewayConfig virtualNetworkGatewayType = {
  name: erGatewayName
  gatewayType: 'ExpressRoute'
  sku: 'ErGw1AZ'
  vpnType: 'RouteBased'
  vpnGatewayGeneration: 'None'
  enableBgp: true
  activeActive: true
  enableBgpRouteTranslationForNat: false
  enableDnsForwarding: false
  bgpSettings: {}
}

@description('Optional. Define outbound destination ports or ranges for SSH or RDP that you want to access from Azure Bastion.')
param azBastionOutboundSshRdpPorts array = ['22', '3389']

var subnetMap = map(range(0, length(subnetsArray)), i => {
  name: subnetsArray[i].name
  ipAddressRange: subnetsArray[i].ipAddressRange
  networkSecurityGroupId: subnetsArray[i].?networkSecurityGroupId ?? ''
  routeTableId: subnetsArray[i].?routeTableId ?? ''
  delegation: subnetsArray[i].?delegation ?? ''
})

var subnetProperties = [
  for subnet in subnetMap: {
    name: subnet.name
    properties: {
      addressPrefix: subnet.ipAddressRange
      delegations: (empty(subnet.delegation))
        ? null
        : [
            {
              name: subnet.delegation
              properties: {
                serviceName: subnet.delegation
              }
            }
          ]
      networkSecurityGroup: (subnet.name == 'AzureBastionSubnet' && azBastionEnabled)
        ? {
            id: '${resourceGroup().id}/providers/Microsoft.Network/networkSecurityGroups/${azBastionNsgName}'
          }
        : (empty(subnet.networkSecurityGroupId))
            ? null
            : {
                id: subnet.networkSecurityGroupId
              }
      routeTable: (empty(subnet.routeTableId))
        ? null
        : {
            id: subnet.routeTableId
          }
    }
  }
]

var azFirewallUseCustomPublicIps = length(azFirewallCustomPublicIps) > 0

// Resource: Virtual Network
resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2025-01-01' = {
  dependsOn: [
    bastionNsg
  ]
  name: hubNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    dhcpOptions: {
      dnsServers: dnsServerIps
    }
    subnets: subnetProperties
    enableDdosProtection: ddosEnabled
  }
}

// Module: Public IP - Azure Bastion
module bastionPip 'br/public:avm/res/network/public-ip-address:0.10.0' = if (azBastionEnabled) {
  name: take('bastionPip-${guid(deployment().name)}', 64)
  params: {
    name: azBastionPublicIpName
    location: location
    tags: tags
    skuName: publicIpSku
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionSubnetRef 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' existing = {
  parent: hubVirtualNetwork
  name: 'AzureBastionSubnet'
}

// Resource: NSG - Azure Bastion
resource bastionNsg 'Microsoft.Network/networkSecurityGroups@2025-01-01' = if (azBastionEnabled) {
  name: azBastionNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      // Inbound Rules
      {
        name: 'INBOUND-FROM-Internet-TO-any-PORT-443-PROT-Tcp-ALLOW'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 120
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          description: 'This is required for inbound HTTPS access from the internet.'
        }
      }
      {
        name: 'INBOUND-FROM-gatewayManager-TO-any-PORT-443-PROT-Tcp-ALLOW'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 130
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          description: 'This is required for inbound HTTPS access from the Gateway Manager.'
        }
      }
      {
        name: 'INBOUND-FROM-azureLoadBalancer-TO-any-PORT-443-PROT-Tcp-ALLOW'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 140
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          description: 'This is required for inbound HTTPS access from the Azure Load Balancer.'
        }
      }
      {
        name: 'INBOUND-FROM-virtualNetwork-TO-virtualNetwork-PORT-8080-5701-PROT-Tcp-ALLOW'
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
          description: 'This is required for data plane communication between the underlying components of Azure Bastion.'
        }
      }
      {
        name: 'INBOUND-FROM-any-TO-any-PORT-any-PROT-any-DENY'
        properties: {
          access: 'Deny'
          direction: 'Inbound'
          priority: 4096
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          description: 'Inbound default deny rule.'
        }
      }
      // Outbound Rules
      {
        name: 'OUTBOUND-FROM-subnet-TO-virtualNetwork-PORT-22-3389-PROT-Tcp-ALLOW'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 100
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: azBastionOutboundSshRdpPorts
          description: 'Outbound from the Bastion Subnet to virtual networks on port 3389 and 22.'
        }
      }
      {
        name: 'OUTBOUND-FROM-subnet-TO-azureCloud-PORT-443-PROT-Tcp-ALLOW'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 110
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          description: 'Outbound from the Bastion Subnet to the Azure Cloud on port 443.'
        }
      }
      {
        name: 'OUTBOUND-FROM-virtualNetwork-TO-virtualNetwork-PORT-8080-5701-PROT-any-ALLOW'
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
          description: 'This is required for data plane communication between the underlying components of Azure Bastion.'
        }
      }
      {
        name: 'OUTBOUND-FROM-subnet-TO-internet-PORT-80-PROT-any-ALLOW'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 130
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '80'
          description: 'This is required for Session information.'
        }
      }
      {
        name: 'OUTBOUND-FROM-any-TO-any-PORT-any-PROT-any-DENY'
        properties: {
          access: 'Deny'
          direction: 'Outbound'
          priority: 4096
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          description: 'Outbound default deny rule.'
        }
      }
    ]
  }
}

// AzureBastionSubnet is required to deploy Bastion service. This subnet must exist in the subnets array if you enable Bastion Service.
// There is a minimum subnet requirement of /27 prefix.
// If you are deploying standard this needs to be larger. <https://docs.microsoft.com/en-us/azure/bastion/configuration-settings#subnet/>
resource bastion 'Microsoft.Network/bastionHosts@2025-01-01' = if (azBastionEnabled) {
  location: location
  name: azBastionName
  tags: tags
  sku: {
    name: azBastionSku
  }
  properties: {
    //dnsName: uniqueString(resourceGroup().id)
    enableTunneling: (azBastionSku == 'Standard' && azBastionTunneling) ? azBastionTunneling : false
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: bastionSubnetRef.id
          }
          publicIPAddress: {
            id: azBastionEnabled ? bastionPip!.outputs.resourceId : ''
          }
        }
      }
    ]
  }
}

resource gatewaySubnetRef 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' existing = if (erGwyEnabled || vpnGwyEnabled) {
  parent: hubVirtualNetwork
  name: 'GatewaySubnet'
}

// Module: Public IP - ER Gateway
module erGwyPublicIp 'br/public:avm/res/network/public-ip-address:0.10.0' = if (!empty(erGatewayConfig) && erGwyEnabled) {
  name: take('erGwyPublicIp-${guid(deployment().name)}', 64)
  params: {
    name: erGwyPublicIpName
    location: location
    tags: tags
    skuName: publicIpSku
    availabilityZones: azErGatewayAvailabilityZones
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

// Module: Public IP - VPN Gateway
module vpnGwyPublicIp1 'br/public:avm/res/network/public-ip-address:0.10.0' = if (!empty(vpnGatewayConfig) && vpnGwyEnabled) {
  name: take('vpnGwyPublicIp1-${guid(deployment().name)}', 64)
  params: {
    name: vpnGwyPublicIpName1
    location: location
    tags: tags
    skuName: publicIpSku
    availabilityZones: azVpnGatewayAvailabilityZones
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

// Module: Public IP 2 - VPN Gateway
module vpnGwyPublicIp2 'br/public:avm/res/network/public-ip-address:0.10.0' = if ((vpnGatewayConfig.?activeActive ?? false) && vpnGwyEnabled) {
  name: take('vpnGwyPublicIp2-${guid(deployment().name)}', 64)
  params: {
    name: vpnGwyPublicIpName2
    location: location
    tags: tags
    skuName: publicIpSku
    availabilityZones: azVpnGatewayAvailabilityZones
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

// Resource: ER Gateway
resource erGateway 'Microsoft.Network/virtualNetworkGateways@2025-01-01' = if (!empty(erGatewayConfig) && erGwyEnabled) {
  name: erGatewayConfig.?name ?? erGatewayName
  location: location
  tags: tags
  properties: {
    activeActive: erGatewayConfig.?activeActive ?? false
    enableBgp: erGatewayConfig.?enableBgp ?? true
    enableBgpRouteTranslationForNat: erGatewayConfig.?enableBgpRouteTranslationForNat
    enableDnsForwarding: erGatewayConfig.?enableDnsForwarding
    bgpSettings: erGatewayConfig.?bgpSettings
    gatewayType: erGatewayConfig.gatewayType
    vpnType: erGatewayConfig.vpnType
    sku: {
      name: erGatewayConfig.sku
      tier: erGatewayConfig.sku
    }
    ipConfigurations: [
      {
        id: hubVirtualNetwork.id
        name: 'erGatewayConfig'
        properties: {
          publicIPAddress: {
            id: (!empty(erGatewayConfig) && erGwyEnabled) ? erGwyPublicIp!.outputs.resourceId : 'na'
          }
          subnet: {
            id: gatewaySubnetRef.id
          }
        }
      }
    ]
  }
}

// Resource: VPN Gateway
resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2025-01-01' = if (!empty(vpnGatewayConfig) && vpnGwyEnabled) {
  name: vpnGatewayConfig.?name ?? vpnGatewayName
  location: location
  tags: tags
  properties: {
    activeActive: vpnGatewayConfig.?activeActive ?? false
    enableBgp: vpnGatewayConfig.?enableBgp ?? false
    enableBgpRouteTranslationForNat: vpnGatewayConfig.?enableBgpRouteTranslationForNat
    enableDnsForwarding: vpnGatewayConfig.?enableDnsForwarding
    bgpSettings: vpnGatewayConfig.?bgpSettings
    gatewayType: vpnGatewayConfig.gatewayType
    vpnGatewayGeneration: (toLower(vpnGatewayConfig.gatewayType) == 'vpn')
      ? vpnGatewayConfig.vpnGatewayGeneration
      : 'None'
    vpnType: vpnGatewayConfig.vpnType
    sku: {
      name: vpnGatewayConfig.sku
      tier: vpnGatewayConfig.sku
    }
    vpnClientConfiguration: (vpnGatewayConfig.gatewayType == 'VPN')
      ? {
          vpnClientAddressPool: vpnGatewayConfig.?vpnClientConfiguration.?vpnClientAddressPool ?? ''
          vpnClientProtocols: vpnGatewayConfig.?vpnClientConfiguration.?vpnClientProtocols ?? ''
          vpnAuthenticationTypes: vpnGatewayConfig.?vpnClientConfiguration.?vpnAuthenticationTypes ?? ''
          aadTenant: vpnGatewayConfig.?vpnClientConfiguration.?aadTenant ?? ''
          aadAudience: vpnGatewayConfig.?vpnClientConfiguration.?aadAudience ?? ''
          aadIssuer: vpnGatewayConfig.?vpnClientConfiguration.?aadIssuer ?? ''
          vpnClientRootCertificates: vpnGatewayConfig.?vpnClientConfiguration.?vpnClientRootCertificates ?? ''
          radiusServerAddress: vpnGatewayConfig.?vpnClientConfiguration.?radiusServerAddress ?? ''
        }
      : null
    ipConfigurations: (vpnGatewayConfig.?activeActive == true)
      ? [
          {
            id: hubVirtualNetwork.id
            name: 'vpnGatewayConfig1'
            properties: {
              privateIPAllocationMethod: 'Dynamic'
              publicIPAddress: {
                id: (!empty(vpnGatewayConfig) && vpnGwyEnabled) ? vpnGwyPublicIp1!.outputs.resourceId : 'na'
              }
              subnet: {
                id: gatewaySubnetRef.id
              }
            }
          }
          {
            id: hubVirtualNetwork.id
            name: 'vpnGatewayConfig2'
            properties: {
              privateIPAllocationMethod: 'Dynamic'
              publicIPAddress: {
                id: (!empty(vpnGatewayConfig) && vpnGwyEnabled) ? vpnGwyPublicIp2!.outputs.resourceId : 'na'
              }
              subnet: {
                id: gatewaySubnetRef.id
              }
            }
          }
        ]
      : [
          {
            id: hubVirtualNetwork.id
            name: 'vpnGatewayConfig1'
            properties: {
              privateIPAllocationMethod: 'Dynamic'
              publicIPAddress: {
                id: (!empty(vpnGatewayConfig) && vpnGwyEnabled) ? vpnGwyPublicIp1!.outputs.resourceId : 'na'
              }
              subnet: {
                id: gatewaySubnetRef.id
              }
            }
          }
        ]
  }
}

resource azFirewallSubnetRef 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' existing = if (azFirewallEnabled) {
  parent: hubVirtualNetwork
  name: 'AzureFirewallSubnet'
}

resource azFirewallMgmtSubnetRef 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' existing = if (azFirewallEnabled && (contains(
  map(subnetsArray, subnets => subnets.name),
  'AzureFirewallManagementSubnet'
))) {
  parent: hubVirtualNetwork
  name: 'AzureFirewallManagementSubnet'
}

// Module: Public IP - Azure Firewall
module azFirewallPublicIp 'br/public:avm/res/network/public-ip-address:0.10.0' = if (azFirewallEnabled) {
  name: take('azFirewallPublicIp-${guid(deployment().name)}', 64)
  params: {
    name: azFirewallPublicIpName
    location: location
    tags: tags
    skuName: publicIpSku
    availabilityZones: azFirewallAvailabilityZones
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

// Module: Public IP - Azure Firewall Mgmt
module azFirewallMgmtPublicIp 'br/public:avm/res/network/public-ip-address:0.10.0' = if (azFirewallEnabled && (contains(
  map(subnetsArray, subnets => subnets.name),
  'AzureFirewallManagementSubnet'
))) {
  name: take('azFirewallMgmtPublicIp-${guid(deployment().name)}', 64)
  params: {
    name: azFirewallMgmtPublicIpName
    location: location
    tags: tags
    skuName: publicIpSku
    availabilityZones: azFirewallAvailabilityZones
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

// Resource: Azure Firewall Policy
resource azFirewallPolicy 'Microsoft.Network/firewallPolicies@2025-01-01' = if (azFirewallEnabled) {
  name: azFirewallPoliciesName
  location: location
  tags: tags
  properties: (azFirewallTier == 'Basic')
    ? {
        sku: {
          tier: azFirewallTier
        }
        threatIntelMode: 'Alert'
      }
    : {
        dnsSettings: {
          enableProxy: azFirewallDnsProxyEnabled
        }
        sku: {
          tier: azFirewallTier
        }
        threatIntelMode: azFirewallIntelMode
      }
}

// Resource: Azure Firewall
resource azFirewall 'Microsoft.Network/azureFirewalls@2024-10-01' = if (azFirewallEnabled) {
  name: azFirewallName
  location: location
  tags: tags
  zones: map(azFirewallAvailabilityZones, zone => '${zone}')
  dependsOn: [
    erGateway
    vpnGateway
  ]
  properties: azFirewallTier == 'Basic'
    ? {
        ipConfigurations: azFirewallUseCustomPublicIps
          ? map(azFirewallCustomPublicIps, ip => {
              name: 'ipconfig${uniqueString(ip)}'
              properties: ip == azFirewallCustomPublicIps[0]
                ? {
                    subnet: {
                      id: azFirewallSubnetRef.id
                    }
                    publicIPAddress: {
                      id: azFirewallEnabled ? ip : ''
                    }
                  }
                : {
                    publicIPAddress: {
                      id: azFirewallEnabled ? ip : ''
                    }
                  }
            })
          : [
              {
                name: 'ipconfig1'
                properties: {
                  subnet: {
                    id: azFirewallSubnetRef.id
                  }
                  publicIPAddress: {
                    id: azFirewallEnabled ? azFirewallPublicIp!.outputs.resourceId : ''
                  }
                }
              }
            ]
        managementIpConfiguration: {
          name: 'mgmtIpConfig'
          properties: {
            publicIPAddress: {
              id: azFirewallEnabled ? azFirewallMgmtPublicIp!.outputs.resourceId : ''
            }
            subnet: {
              id: azFirewallMgmtSubnetRef.id
            }
          }
        }
        sku: {
          name: 'AZFW_VNet'
          tier: azFirewallTier
        }
        firewallPolicy: {
          id: azFirewallPolicy.id
        }
      }
    : {
        ipConfigurations: azFirewallUseCustomPublicIps
          ? map(azFirewallCustomPublicIps, ip => {
              name: 'ipconfig${uniqueString(ip)}'
              properties: ip == azFirewallCustomPublicIps[0]
                ? {
                    subnet: {
                      id: azFirewallSubnetRef.id
                    }
                    publicIPAddress: {
                      id: azFirewallEnabled ? ip : ''
                    }
                  }
                : {
                    publicIPAddress: {
                      id: azFirewallEnabled ? ip : ''
                    }
                  }
            })
          : [
              {
                name: 'ipconfig1'
                properties: {
                  subnet: {
                    id: azFirewallSubnetRef.id
                  }
                  publicIPAddress: {
                    id: azFirewallEnabled ? azFirewallPublicIp!.outputs.resourceId : ''
                  }
                }
              }
            ]
        sku: {
          name: 'AZFW_VNet'
          tier: azFirewallTier
        }
        firewallPolicy: {
          id: azFirewallPolicy.id
        }
      }
}

@description('Module: Route Table - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/route-table')
module hubRouteTable 'br/public:avm/res/network/route-table:0.5.0' = if (azFirewallEnabled) {
  name: take('hubRouteTable-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    name: hubRouteTableName
    // Non-required parameters
    disableBgpRoutePropagation: disableBGPRoutePropagation
    location: location
    routes: gatewayRoutes
    tags: tags
  }
}

output azFirewallPrivateIp string = azFirewallEnabled
  ? azFirewall!.properties.ipConfigurations[0].properties.privateIPAddress
  : ''
output azFirewallName string = azFirewallEnabled ? azFirewall.name : ''
output hubVirtualNetworkName string = hubVirtualNetwork.name
output hubVirtualNetworkId string = hubVirtualNetwork.id
