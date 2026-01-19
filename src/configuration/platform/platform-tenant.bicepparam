using '../../orchestration/platform/platform.bicep'

var mgId = 'mg-alz'
param managementGroups = {
  intRoot: {
    displayName: 'Azure Landing Zones'
    id: mgId
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'f01a6dfd-ba9b-5415-acba-cdd2b5e507d0'
        assigneePrincipalType: 'Group'
        principalId: 'd84fcd16-2d4a-4938-8908-9e7be47fe0c6'
        description: 'Role Assignment for Platform Operators Group'
      }
    ]
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
param alzCustomRbacRoleDefsJson = [
  loadJsonContent('../../lib/roleDefinitions/application_owners.alz_role_definition.json')
  loadJsonContent('../../lib/roleDefinitions/network_management.alz_role_definition.json')
  loadJsonContent('../../lib/roleDefinitions/network_subnet_contributor.alz_role_definition.json')
  loadJsonContent('../../lib/roleDefinitions/security_operations.alz_role_definition.json')
  loadJsonContent('../../lib/roleDefinitions/subscription_owner.alz_role_definition.json')
]
