targetScope = 'resourceGroup'

metadata name = 'Test and Validation Deployment'
metadata description = 'Test and Validation of the Spoke Networking Module.'

param envId string = 'conn'

module testDeployment '../spokeNetworking.bicep' = {
  name: take('testDeployment-${guid(deployment().name)}', 64)
  params: {
    nsgId: 'nsg-1234'
    vntId: 'vnt-1234'
    extendedLocation: {
      type: 'EdgeZone'
      name: 'perth'
    }
    tags: {
      environment: envId
      applicationName: 'Hub Connectivity'
      owner: 'Platform Team'
      criticality: 'Tier1'
      costCenter: '1234'
      contactEmail: 'test@outlook.com'
      dataClassification: 'Internal'
      iac: 'Bicep'
    }
    virtualNetworkConfiguration: {
      name: 'spoke-vnet-${envId}'
      addressPrefixes: [
        '10.52.0.0/23'
      ]
      dnsServers: [
        '10.52.0.1'
        '10.52.0.2'
      ]
      subnets: [
        {
          name: 'GatewaySubnet'
          addressPrefix: '10.52.0.0/26'
        }
        {
          name: 'FrontEnd'
          addressPrefix: '10.52.0.64/26'
        }
        {
          name: 'Backend'
          addressPrefix: '10.52.0.128/26'
        }
      ]
    }
  }
}
