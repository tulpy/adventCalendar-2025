targetScope = 'managementGroup'

metadata name = 'Test and Validation Deployment'
metadata description = 'Test and Validation of the Platform Orchestration Module.'

var mgId = 'mg-alz'

module testDeployment '../platform.bicep' = {
  name: take('testDeployment-${guid(deployment().name)}', 64)
  params: {
    managementGroups: {
      intRoot: {
        displayName: 'AVM ALZ CANARY'
        id: mgId
        roleAssignments: []
      }
      decommissioned: {
        displayName: 'Decommissioned'
        id: '${mgId}-decommissioned'
        roleAssignments: [
          {
            roleDefinitionIdOrName: 'f01a6dfd-ba9b-5415-acba-cdd2b5e507d0'
            assigneePrincipalType: 'Group'
            principalId: 'd84fcd16-2d4a-4938-8908-9e7be47fe0c6'
            description: 'Role Assignment for Platform Operators Group'
          }
        ]
      }
      sandbox: {
        displayName: 'Sandbox'
        id: '${mgId}-sandbox'
        roleAssignments: []
      }
      platform: {
        displayName: 'Platform'
        id: '${mgId}-platform'
        roleAssignments: []
      }
      platformConnectivity: {
        displayName: 'Connectivity'
        id: '${mgId}-platform-connectivity'
        roleAssignments: []
      }
      platformManagement: {
        displayName: 'Management'
        id: '${mgId}-platform-management'
        roleAssignments: []
      }
      platformIdentity: {
        displayName: 'Identity'
        id: '${mgId}-platform-identity'
        roleAssignments: []
      }
      platformSecurity: {
        displayName: 'Security'
        id: '${mgId}-platform-security'
        roleAssignments: []
      }
      landingZones: {
        displayName: 'Landing Zones'
        id: '${mgId}-landingzones'
        roleAssignments: []
      }
      corp: {
        displayName: 'Corp'
        id: '${mgId}-lz-corp'
        roleAssignments: []
      }
      online: {
        displayName: 'Online'
        id: '${mgId}-lz-online'
        roleAssignments: []
      }
    }
  }
}
