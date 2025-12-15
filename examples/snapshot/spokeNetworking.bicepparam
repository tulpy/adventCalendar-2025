using './spokeNetworking.bicep'

param extendedLocation = {
  name: 'perth'
  type: 'EdgeZone'
}
param tags = {
  environment: 'idam'
  applicationName: 'AEZ Platform Identity Landing Zone'
  owner: 'Platform Team'
  criticality: 'Tier0'
  costCenter: '1234'
  contactEmail: 'test@test.com'
  dataClassification: 'Internal'
  iac: 'Bicep'
}
param virtualNetworkConfiguration = {
  addressPrefixes: [
    '10.52.1.0/24'
  ]
  dnsServers: [
    '10.52.0.1'
    '10.52.0.2'
  ]
  subnets: [
    {
      name: 'adds'
      addressPrefix: '10.52.1.0/26'
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
            destinationAddressPrefix: '10.52.4.0/25' // Platform Identity ADDS Subnet Range. Replace it with actual range.
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
            destinationAddressPrefix: '10.52.4.0/25' // Platform Identity ADDS Subnet Range. Replace it with actual range.
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
            destinationAddressPrefix: '10.52.4.0/25' // Platform Identity ADDS Subnet Range. Replace it with actual ranges.
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
            sourceAddressPrefix: '10.52.4.0/25' // Platform Identity ADDS Subnet Range. Replace it with actual ranges.
            destinationAddressPrefix: '10.52.4.0/25' // Platform Identity ADDS Subnet Range .Replace it with actual ranges.
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
