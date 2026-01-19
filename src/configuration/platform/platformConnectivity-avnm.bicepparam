using '../../modules/avnm/avnm.bicep'

param deploy = true // Set to false to skip deployment of AVNM resources and get a plan only.
param avnmConfiguration = {
  name: 'avnm-aue-plat-conn-01'
  subscriptionScopes: []
  managementGroupScopes: [
    '/providers/Microsoft.Management/managementGroups/mg-alz'
  ]
  ipamRootSettings: {
    rootIpamPoolName: 'AU-RootPool'
    azureCidr: '10.10.0.0/15'
    regionCidrSize: 17 // This number needs to be smaller than or equal to the Azure CIDR size. Each region needs to fit within this CIDR.
    regionLzCidrSize: 22
  }
}
param regions = [
  {
    displayName: 'Australia East'
    name: 'australiaeast'
    cidr: cidrSubnet(avnmConfiguration.ipamRootSettings.azureCidr, avnmConfiguration.ipamRootSettings.regionCidrSize, 0)
    platformAndApplicationSplitFactor: 5
  }
  {
    displayName: 'Australia Southeast'
    name: 'australiasoutheast'
    cidr: cidrSubnet(avnmConfiguration.ipamRootSettings.azureCidr, avnmConfiguration.ipamRootSettings.regionCidrSize, 1)
    platformAndApplicationSplitFactor: 5
  }
    {
    displayName: 'Southeast Asia'
    name: 'southeastasia'
    cidr: cidrSubnet(avnmConfiguration.ipamRootSettings.azureCidr, avnmConfiguration.ipamRootSettings.regionCidrSize, 2)
    platformAndApplicationSplitFactor: 5
  }
  {
    displayName: 'East Asia'
    name: 'eastasia'
    cidr: cidrSubnet(avnmConfiguration.ipamRootSettings.azureCidr, avnmConfiguration.ipamRootSettings.regionCidrSize, 3)
    platformAndApplicationSplitFactor: 5
  }
]
