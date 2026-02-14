targetScope = 'managementGroup'

metadata name = 'ALZ Bicep - Role Assignment to a Management Group Loop'
metadata description = 'Module used to assign a roles to Management Group'
metadata author = 'Insight APAC Platform Engineering'
metadata version = '1.0.0'

@description('Required. The intermediate root management group where the deployment will be applied.')
param inRootMG string

@description('Optional. Array of Role Assignments to assign at the management group scope.')
param rolesManagementGroups array = []

@description('Optional. Array of Role Assignments to assign at the subscription scope.')
param roleSubscriptions array = []

@description('Optional. Array of Role Assignments to assign at the resource group scope.')
param roleResourceGroups array = []

@description('Optional. Array of Role Assignments to assign at the resource scope.')
param roleResources array = []

@description('Module: Role Assignment - Management Group Scope - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/authorization/role-assignment')
module roleAssignment_mg 'br/public:avm/ptn/authorization/role-assignment:0.2.4' = [
  for role in rolesManagementGroups: {
    name: 'mgRoleAssignment-${guid(role.managementGroupId, role.roleDefinitionId, role.assigneeObjectId)}'
    scope: managementGroup(inRootMG)
    params: {
      principalId: role.assigneeObjectId
      roleDefinitionIdOrName: role.roleDefinitionId
      managementGroupId: role.managementGroupId
      principalType: role.assigneePrincipalType
      description: role.?description ?? ''
    }
  }
]

@description('Module: Role Assignment - Subscription Scope - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/authorization/role-assignment')
module roleAssignment_sub 'br/public:avm/ptn/authorization/role-assignment:0.2.4' = [
  for role in roleSubscriptions: {
    name: 'subRoleAssignment-${guid(role.subscriptionId, role.roleDefinitionId, role.assigneeObjectId)}'
    scope: managementGroup(inRootMG)
    params: {
      principalId: role.assigneeObjectId
      roleDefinitionIdOrName: role.roleDefinitionId
      subscriptionId: role.subscriptionId
      principalType: role.assigneePrincipalType
      description: role.?description ?? ''
    }
  }
]

@description('Module: Role Assignment - Resource Group Scope - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/authorization/role-assignment')
module roleAssignment_rg 'br/public:avm/ptn/authorization/role-assignment:0.2.4' = [
  for role in roleResourceGroups: {
    name: 'rgRoleAssignment-${guid(role.subscriptionId, role.resourceGroupName, role.roleDefinitionId, role.assigneeObjectId)}'
    scope: managementGroup(inRootMG)
    params: {
      principalId: role.assigneeObjectId
      roleDefinitionIdOrName: role.roleDefinitionId
      subscriptionId: role.subscriptionId
      resourceGroupName: role.resourceGroupName
      principalType: role.assigneePrincipalType
      description: role.?description ?? ''
    }
  }
]

module roleAssignment_resource 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = [
  for role in roleResources: {
    scope: resourceGroup(role.subscriptionId, role.resourceGroupName)
    name: 'resRoleAssignment-${guid(role.subscriptionId, role.resourceGroupName, role.assigneeObjectId, role.resourceId)}'
    params: {
      principalId: role.assigneeObjectId
      roleDefinitionId: role.roleDefinitionId
      resourceId: role.resourceId
      principalType: role.assigneePrincipalType
      description: role.?description ?? ''
    }
  }
]
