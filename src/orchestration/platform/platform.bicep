targetScope = 'managementGroup'

metadata name = 'ALZ Management Groups & Platform Resources Orchestration'
metadata description = 'Module used to bootstrap an Azure Landing Zone Platform.'
metadata version = '0.0.2'
metadata author = 'Insight APAC Platform Engineering'

@description('Required. An object of Management Groups.')
param managementGroups object

@description('Optional. JSON files containing the custom RBAC role definitions.')
param alzCustomRbacRoleDefsJson array = []

@description('Optional. JSON files containing the custom policy definitions.')
param alzCustomPolicyDefsJson array = []

@description('Optional. JSON files containing the custom policy definitions.')
param alzCustomPolicySetDefsJson array = []

@description('Optional. The name of the management group to create or update.')
param createOrUpdateManagementGroup bool = true

// Custom Role Definitions
var alzCustomRbacRoleDefsJsonParsed = [
  for roleDef in alzCustomRbacRoleDefsJson: {
    name: roleDef.name
    roleName: roleDef.properties.roleName
    description: roleDef.properties.description
    actions: roleDef.properties.permissions[0].actions
    notActions: roleDef.properties.permissions[0].notActions
    dataActions: roleDef.properties.permissions[0].dataActions
    notDataActions: roleDef.properties.permissions[0].notDataActions
  }
]
var additionalCustomRbacRoleDefs = []
var unionedCustomRbacRoleDefs = union(alzCustomRbacRoleDefsJsonParsed, additionalCustomRbacRoleDefs)

// Policy Definitions, Initiatives and Assignments
var managementGroupCustomPolicyDefinitions = [
  for policy in alzCustomPolicyDefsJson: {
    name: policy.name
    properties: {
      description: policy.properties.description
      displayName: policy.properties.displayName
      metadata: policy.properties.metadata
      mode: policy.properties.mode
      parameters: policy.properties.parameters
      policyType: policy.properties.policyType
      policyRule: policy.properties.policyRule
    }
  }
]

var managementGroupCustomPolicySetDefinitions = [
  for policy in alzCustomPolicySetDefsJson: {
    name: policy.name
    properties: {
      description: policy.properties.description
      displayName: policy.properties.displayName
      metadata: policy.properties.metadata
      parameters: policy.properties.parameters
      policyType: policy.properties.policyType
      version: policy.properties.?version
      policyDefinitions: policy.properties.policyDefinitions
    }
  }
]

var managementGroupRoleAssignments = [
  {
    principalId: deployer().objectId
    roleDefinitionIdOrName: 'Owner'
  }
]

@description('Module: Int Root Management Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/alz/empty')
module intRoot 'br/public:avm/ptn/alz/empty:0.3.6' = {
  name: take('intRoot-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    managementGroupName: managementGroups.intRoot.id
    // Non-required parameters
    createOrUpdateManagementGroup: createOrUpdateManagementGroup
    managementGroupCustomRoleDefinitions: unionedCustomRbacRoleDefs
    managementGroupRoleAssignments: managementGroupRoleAssignments
    managementGroupDisplayName: managementGroups.intRoot.displayName
    managementGroupCustomPolicyDefinitions: !empty(managementGroupCustomPolicyDefinitions)
      ? managementGroupCustomPolicyDefinitions
      : null
    managementGroupCustomPolicySetDefinitions: !empty(managementGroupCustomPolicySetDefinitions)
      ? managementGroupCustomPolicySetDefinitions
      : null
    subscriptionsToPlaceInManagementGroup: []
  }
}

@description('Module: Decommissioned Management Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/alz/empty')
module decommissioned 'br/public:avm/ptn/alz/empty:0.3.6' = {
  name: take('decommissioned-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    managementGroupName: managementGroups.decommissioned.id
    // Non-required parameters
    createOrUpdateManagementGroup: createOrUpdateManagementGroup
    managementGroupDisplayName: managementGroups.decommissioned.displayName
    managementGroupParentId: intRoot.outputs.managementGroupId
    subscriptionsToPlaceInManagementGroup: []
  }
}

@description('Module: Sandbox Management Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/alz/empty')
module sandbox 'br/public:avm/ptn/alz/empty:0.3.6' = {
  name: take('sandbox-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    managementGroupName: managementGroups.sandbox.id
    // Non-required parameters
    createOrUpdateManagementGroup: createOrUpdateManagementGroup
    managementGroupDisplayName: managementGroups.sandbox.displayName
    managementGroupParentId: intRoot.outputs.managementGroupId
    subscriptionsToPlaceInManagementGroup: []
  }
}

@description('Module: Platform Management Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/alz/empty')
module platform 'br/public:avm/ptn/alz/empty:0.3.6' = {
  name: take('platform-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    managementGroupName: managementGroups.platform.id
    // Non-required parameters
    createOrUpdateManagementGroup: createOrUpdateManagementGroup
    managementGroupDisplayName: managementGroups.platform.displayName
    managementGroupParentId: intRoot.outputs.managementGroupId
    subscriptionsToPlaceInManagementGroup: []
  }
}

@description('Module: Platform Management Management Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/alz/empty')
module platformManagement 'br/public:avm/ptn/alz/empty:0.3.6' = {
  name: take('platformManagement-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    managementGroupName: managementGroups.platformManagement.id
    // Non-required parameters
    createOrUpdateManagementGroup: createOrUpdateManagementGroup
    managementGroupDisplayName: managementGroups.platformManagement.displayName
    managementGroupParentId: platform.outputs.managementGroupId
    subscriptionsToPlaceInManagementGroup: []
  }
}

@description('Module: Platform Identity Management Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/alz/empty')
module platformIdentity 'br/public:avm/ptn/alz/empty:0.3.6' = {
  name: take('platformIdentity-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    managementGroupName: managementGroups.platformIdentity.id
    // Non-required parameters
    createOrUpdateManagementGroup: createOrUpdateManagementGroup
    managementGroupDisplayName: managementGroups.platformIdentity.displayName
    managementGroupParentId: platform.outputs.managementGroupId
    subscriptionsToPlaceInManagementGroup: []
  }
}

@description('Module: Platform Connectivity Management Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/alz/empty')
module platformConnectivity 'br/public:avm/ptn/alz/empty:0.3.6' = {
  name: take('platformConnectivity-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    managementGroupName: managementGroups.platformConnectivity.id
    // Non-required parameters
    createOrUpdateManagementGroup: createOrUpdateManagementGroup
    managementGroupDisplayName: managementGroups.platformConnectivity.displayName
    managementGroupParentId: platform.outputs.managementGroupId
    subscriptionsToPlaceInManagementGroup: []
  }
}

@description('Module: Platform Security Management Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/alz/empty')
module platformSecurity 'br/public:avm/ptn/alz/empty:0.3.6' = {
  name: take('platformSecurity-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    managementGroupName: managementGroups.platformSecurity.id
    // Non-required parameters
    createOrUpdateManagementGroup: createOrUpdateManagementGroup
    managementGroupDisplayName: managementGroups.platformSecurity.displayName
    managementGroupParentId: platform.outputs.managementGroupId
    subscriptionsToPlaceInManagementGroup: []
  }
}

@description('Module: Landing Zone Management Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/alz/empty')
module landingZones 'br/public:avm/ptn/alz/empty:0.3.6' = {
  name: take('landingZones-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    managementGroupName: managementGroups.landingZones.id
    // Non-required parameters
    createOrUpdateManagementGroup: createOrUpdateManagementGroup
    managementGroupDisplayName: managementGroups.landingZones.displayName
    managementGroupParentId: intRoot.outputs.managementGroupId
    subscriptionsToPlaceInManagementGroup: []
  }
}

@description('Module: Landing Zone Corp Management Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/alz/empty')
module lzCorp 'br/public:avm/ptn/alz/empty:0.3.6' = {
  name: take('corp-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    managementGroupName: managementGroups.corp.id
    // Non-required parameters
    createOrUpdateManagementGroup: createOrUpdateManagementGroup
    managementGroupDisplayName: managementGroups.corp.displayName
    managementGroupParentId: landingZones.outputs.managementGroupId
    subscriptionsToPlaceInManagementGroup: []
  }
}

@description('Module: Landing Zone Online Management Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/alz/empty')
module lzOnline 'br/public:avm/ptn/alz/empty:0.3.6' = {
  name: take('online-${guid(deployment().name)}', 64)
  params: {
    // Required parameters
    managementGroupName: managementGroups.online.id
    // Non-required parameters
    createOrUpdateManagementGroup: createOrUpdateManagementGroup
    managementGroupDisplayName: managementGroups.online.displayName
    managementGroupParentId: landingZones.outputs.managementGroupId
    subscriptionsToPlaceInManagementGroup: []
  }
}
