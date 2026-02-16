@description('Test Deployment for Azure Virtual Network Manager Module')
module testAVNM '../avnm.bicep' = {
  name: 'testAzureVirtualNetworkManager'
  params: {
    #disable-next-line no-hardcoded-location
    location: 'australiaeast'
    avnmConfiguration: {
      name: 'avnm-aue-plat-conn-01'
      subscriptionScopes: []
      managementGroupScopes: [
        '/providers/Microsoft.Management/managementGroups/mg-alz'
      ]
      ipamRootSettings: {
        rootIpamPoolName: 'AU-RootPool'
        azureCidr: '10.4.0.0/16'
        regionCidrSize: 17 // This number needs to be smaller than or equal to the Azure CIDR size. Each region needs to fit within this CIDR.
        regionLzCidrSize: 22
      }
    }
    regions: [
      {
        displayName: 'Australia East'
        name: 'australiaeast'
        cidr: '10.0.0.0/20'
        platformAndApplicationSplitFactor: 5
      }
      {
        displayName: 'Australia Southeast'
        name: 'australiasoutheast'
        cidr: '10.0.1.0/20'
        platformAndApplicationSplitFactor: 5
      }
    ]
    tags: {
      applicationName: 'Azure Virtual Network Manager'
      owner: 'IT'
      criticality: 'Tier0'
      costCenter: '1234'
      contactEmail: 'test@example.com'
      dataClassification: 'Internal'
      environment: 'prd'
      iac: 'Bicep'
    }
  }
}
