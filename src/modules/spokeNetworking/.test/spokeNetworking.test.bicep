targetScope = 'subscription'

metadata name = 'Test and Validation Deployment'
metadata description = 'Test and Validation of the spokeNetworking Module.'

module testDeployment '../spokeNetworking.bicep' = {
  name: take('testDeployment-${guid(deployment().name)}', 64)
  params: {
    #disable-next-line no-hardcoded-location
    locations: ['australiaeast']
    nsgId: ['nsg-syd-sap-prd']
    udrId: ['udr-syd-sap-prd']
    spokeNetworks: [
      {
        name: 'vnet-syd-sap-prd-001'
        location: 'australiaeast'
        addressPrefixes: ['10.0.0.0/16']
        subnets: [
          {
            name: 'snet-app-001'
            addressPrefix: '10.0.0.0/24'
          }
        ]
      }
    ]
    tags: {
      environment: 'sbx'
      applicationName: 'Spoke Networking'
      owner: 'Platform Team'
      criticality: 'Tier1'
      costCenter: '1234'
      contactEmail: 'test@test.com'
      dataClassification: 'Internal'
      iac: 'Bicep'
    }
  }
}
