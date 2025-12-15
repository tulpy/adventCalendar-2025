targetScope = 'managementGroup'

metadata name = 'Test and Validation Deployment'
metadata description = 'Test and Validation of the Platform Connectivity Orchestration Module.'

param subscriptionId string = 'a50d2a27-93d9-43b1-957c-2a663ffaf37f'
param lzId string = 'plat'
param envId string = 'conn'

@description('Test Deployment for PS-Rule')
module testDeployment '../platformConnectivity-hub.bicep' = {
  name: take('testDeployment-${guid(deployment().name)}', 64)
  params: {
    lzId: lzId
    envId: envId
    subscriptionId: subscriptionId
    tags: {
      environment: envId
      applicationName: 'Platform Connectivity Landing Zone'
      owner: 'Platform Team'
      criticality: 'Tier1'
      costCenter: '1234'
      contactEmail: 'test@outlook.com'
      dataClassification: 'Internal'
      iac: 'Bicep'
    }
  }
}
