using '../../orchestration/platform/platform.bicep'

var mgId = 'mg-alz-canary'
param managementGroups = {
  intRoot: {
    displayName: 'Azure Landing Zones - Canary'
    id: mgId
    roleAssignments: []
  }
  decommissioned: {
    displayName: 'Decommissioned'
    id: '${mgId}-decommissioned'
    roleAssignments: []
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
