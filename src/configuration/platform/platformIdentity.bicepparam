import {
  locIds
  resIds
} from '../../configuration/shared/shared.conf.bicep'

using '../../orchestration/platformIdentity/platformIdentity.bicep'

param lzId = 'plat'
param envId = 'idam'
param locations = [
  'australiaeast'
  'australiasoutheast'
]
param subscriptionId = '9df3a442-42f1-40dd-8547-958c3e01597a'
param tags = {
  environment: envId
  applicationName: 'Platform Identity Landing Zone'
  owner: 'Platform Team'
  criticality: 'Tier0'
  costCenter: '1234'
  contactEmail: 'test@outlook.com'
  dataClassification: 'Internal'
  iac: 'Bicep'
}
param deployBudgets = true
param budgetConfiguration = {
  budgets: [
    {
      name: 'budget-forecasted'
      amount: 500
      startDate: '2026-01-01T00:00:00Z' // Date cant be in the past
      thresholdType: 'Forecasted'
      thresholds: [
        90
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
param spokeNetworkingConfiguration = [
  {
    name: toLower('${resIds.virtualNetwork}-${locIds[locations[0]]}-${lzId}-${envId}-10.0.4.0_24')
    location: locations[0]
    addressPrefixes: [
      '10.0.4.0/24'
    ]
    dnsServers: [
      '10.0.4.4'
      '10.0.4.5'
    ]
    deployPeering: true
    peeringSettings: {
      allowForwardedTraffic: true
      allowGatewayTransit: false
      allowVirtualNetworkAccess: true
      useRemoteGateways: false
    }
    hubVirtualNetworkResourceId: hubVirtualNetworkResourceIds[0]
    subnets: [
      {
        name: 'adds'
        addressPrefix: '10.0.4.0/26'
        defaultOutboundAccess: false
        routes: []
        securityRules: [
          {
            name: 'INBOUND-FROM-onPremisesADDS-TO-subnet-PORT-adServices-PROT-any-ALLOW'
            properties: {
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRanges: [
                '53'
                '88'
                '123'
                '135'
                '137-139'
                '389'
                '445'
                '464'
                '636'
                '3268'
                '3269'
                '5722'
                '9389'
                '49152-65535'
              ]
              sourceAddressPrefixes: [
                '10.20.11.47'
                '10.20.11.48'
              ] //On-Premises Active Directory Services IPs. Replace it with actual ranges
              destinationAddressPrefix: '10.0.4.0/26' // Platform Identity ADDS Subnet Range. Replace it with actual range.
              access: 'Allow'
              priority: 500
              direction: 'Inbound'
              description: 'Inbound rules from on-premises & Azure Corp ADDS servers to the subnet for the required ports and protocols'
            }
          }
          {
            name: 'INBOUND-FROM-onPremisesCorpNetworks-TO-adds-PORT-aadServices-PROT-any-ALLOW'
            properties: {
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRanges: [
                '53'
                '88'
                '123'
                '135'
                '137-139'
                '389'
                '445'
                '464'
                '636'
                '3268'
                '3269'
                '5722'
                '9389'
                '49152-65535'
              ]
              sourceAddressPrefixes: [
                '10.20.76.0/24'
              ] // OnPremises Corporate networks. Replace it with actual ranges.
              destinationAddressPrefix: '10.0.4.0/26' // Platform Identity ADDS Subnet Range. Replace it with actual range.
              access: 'Allow'
              priority: 501
              direction: 'Inbound'
              description: 'Allow on-premises corp virtual networks traffic to adds subnet on adservices ports'
            }
          }
          {
            name: 'INBOUND-FROM-azureSupernet-TO-adds-PORT-aadServices-PROT-any-ALLOW'
            properties: {
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRanges: [
                '53'
                '88'
                '123'
                '135'
                '137-139'
                '389'
                '445'
                '464'
                '636'
                '3268'
                '3269'
                '5722'
                '9389'
                '49152-65535'
              ]
              sourceAddressPrefix: ''
              sourceAddressPrefixes: [
                '10.52.0.0/16'
              ] // Azure Supernet Range. Replace it with actual ranges.
              destinationAddressPrefix: '10.52.4.0/25' // Platform Identity ADDS Subnet Range. Replace it with actual ranges.
              access: 'Allow'
              priority: 502
              direction: 'Inbound'
              description: 'Inbound rules from Azure Supernet to the ADDS subnet for the required ports and protocols'
            }
          }
          {
            name: 'INBOUND-FROM-RemoteAccessNetwork-TO-azurePlatDCs-PORT-22-3389-PROT-any-ALLOW'
            properties: {
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRanges: [
                '3389'
                '22'
              ]
              sourceAddressPrefixes: [
                '10.20.72.4'
              ] // Remote Access Network Ranges. Ex: Bastion or CyberArk IP. Replace it with actual ranges.
              destinationAddressPrefix: '10.0.4.0/26' // Platform Identity ADDS Subnet Range. Replace it with actual ranges.
              access: 'Allow'
              priority: 503
              direction: 'Inbound'
              description: 'Inbound rule from allowed networks to Azure allowed network to azure Platform Domain Controllers on port 22, 3389 and any protocol'
            }
          }
          {
            name: 'INBOUND-FROM-subnet-TO-subnet-PORT-any-PROT-any-ALLOW'
            properties: {
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRange: '*'
              sourceAddressPrefix: '10.0.4.0/26' // Platform Identity ADDS Subnet Range. Replace it with actual ranges.
              destinationAddressPrefix: '10.0.4.0/26' // Platform Identity ADDS Subnet Range .Replace it with actual ranges.
              access: 'Allow'
              priority: 999
              direction: 'Inbound'
              description: 'Inbound rule from the subnet to the subnet on any port and any protocol'
            }
          }
        ]
        privateEndpointNetworkPolicies: 'Enabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    ]
  }
  {
    name: toLower('${resIds.virtualNetwork}-${locIds[locations[1]]}-${lzId}-${envId}-10.0.5.0_24')
    location: locations[1]
    addressPrefixes: [
      '10.0.5.0/24'
    ]
    dnsServers: [
      '10.0.5.4'
      '10.0.5.5'
    ]
    deployPeering: true
    peeringSettings: {
      allowForwardedTraffic: true
      allowGatewayTransit: false
      allowVirtualNetworkAccess: true
      useRemoteGateways: false
    }
    hubVirtualNetworkResourceId: hubVirtualNetworkResourceIds[1]
    subnets: [
      {
        name: 'adds'
        addressPrefix: '10.0.5.0/26'
        defaultOutboundAccess: false
        routes: []
        securityRules: [
          {
            name: 'INBOUND-FROM-onPremisesADDS-TO-subnet-PORT-adServices-PROT-any-ALLOW'
            properties: {
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRanges: [
                '53'
                '88'
                '123'
                '135'
                '137-139'
                '389'
                '445'
                '464'
                '636'
                '3268'
                '3269'
                '5722'
                '9389'
                '49152-65535'
              ]
              sourceAddressPrefixes: [
                '10.20.11.47'
                '10.20.11.48'
              ] //On-Premises Active Directory Services IPs. Replace it with actual ranges
              destinationAddressPrefix: '10.0.5.0/26' // Platform Identity ADDS Subnet Range. Replace it with actual range.
              access: 'Allow'
              priority: 500
              direction: 'Inbound'
              description: 'Inbound rules from on-premises & Azure Corp ADDS servers to the subnet for the required ports and protocols'
            }
          }
          {
            name: 'INBOUND-FROM-onPremisesCorpNetworks-TO-adds-PORT-aadServices-PROT-any-ALLOW'
            properties: {
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRanges: [
                '53'
                '88'
                '123'
                '135'
                '137-139'
                '389'
                '445'
                '464'
                '636'
                '3268'
                '3269'
                '5722'
                '9389'
                '49152-65535'
              ]
              sourceAddressPrefixes: [
                '10.20.76.0/24'
              ] // OnPremises Corporate networks. Replace it with actual ranges.
              destinationAddressPrefix: '10.0.5.0/26' // Platform Identity ADDS Subnet Range. Replace it with actual range.
              access: 'Allow'
              priority: 501
              direction: 'Inbound'
              description: 'Allow on-premises corp virtual networks traffic to adds subnet on adservices ports'
            }
          }
          {
            name: 'INBOUND-FROM-azureSupernet-TO-adds-PORT-aadServices-PROT-any-ALLOW'
            properties: {
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRanges: [
                '53'
                '88'
                '123'
                '135'
                '137-139'
                '389'
                '445'
                '464'
                '636'
                '3268'
                '3269'
                '5722'
                '9389'
                '49152-65535'
              ]
              sourceAddressPrefix: ''
              sourceAddressPrefixes: [
                '10.52.0.0/16'
              ] // Azure Supernet Range. Replace it with actual ranges.
              destinationAddressPrefix: '10.52.4.0/25' // Platform Identity ADDS Subnet Range. Replace it with actual ranges.
              access: 'Allow'
              priority: 502
              direction: 'Inbound'
              description: 'Inbound rules from Azure Supernet to the ADDS subnet for the required ports and protocols'
            }
          }
          {
            name: 'INBOUND-FROM-RemoteAccessNetwork-TO-azurePlatDCs-PORT-22-3389-PROT-any-ALLOW'
            properties: {
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRanges: [
                '3389'
                '22'
              ]
              sourceAddressPrefixes: [
                '10.20.72.4'
              ] // Remote Access Network Ranges. Ex: Bastion or CyberArk IP. Replace it with actual ranges.
              destinationAddressPrefix: '10.0.5.0/26' // Platform Identity ADDS Subnet Range. Replace it with actual ranges.
              access: 'Allow'
              priority: 503
              direction: 'Inbound'
              description: 'Inbound rule from allowed networks to Azure allowed network to azure Platform Domain Controllers on port 22, 3389 and any protocol'
            }
          }
          {
            name: 'INBOUND-FROM-subnet-TO-subnet-PORT-any-PROT-any-ALLOW'
            properties: {
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRange: '*'
              sourceAddressPrefix: '10.0.5.0/26' // Platform Identity ADDS Subnet Range. Replace it with actual ranges.
              destinationAddressPrefix: '10.0.5.0/26' // Platform Identity ADDS Subnet Range .Replace it with actual ranges.
              access: 'Allow'
              priority: 999
              direction: 'Inbound'
              description: 'Inbound rule from the subnet to the subnet on any port and any protocol'
            }
          }
        ]
        privateEndpointNetworkPolicies: 'Enabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
      {
        name: 'privateEndpoints'
        addressPrefix: '10.0.5.64/26'
        defaultOutboundAccess: false
        routes: []
        securityRules: []
        privateEndpointNetworkPolicies: 'Enabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    ]
  }
]
param hubVirtualNetworkResourceIds = [
  '/subscriptions/5cb7efe0-67af-4723-ab35-0f2b42a85839/resourceGroups/arg-aue-plat-conn-network/providers/Microsoft.Network/virtualNetworks/vnt-aue-plat-conn-10.0.0.0_22'
  '/subscriptions/5cb7efe0-67af-4723-ab35-0f2b42a85839/resourceGroups/arg-ause-plat-conn-network/providers/Microsoft.Network/virtualNetworks/vnt-ause-plat-conn-10.10.0.0_22'
]
