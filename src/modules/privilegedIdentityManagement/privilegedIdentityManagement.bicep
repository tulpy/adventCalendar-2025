targetScope = 'managementGroup'

metadata name = 'ALZ Bicep - Privileged Identity Management'
metadata description = 'Deploys a roleEligibilityScheduleRequests resource for Azure PIM with optional conditions and ticket info.'
metadata version = '1.0.0'
metadata author = 'Insight APAC Platform Engineering'

@description('Optional. Location deployment metadata.')
param location string = deployment().location

@description('Required. The intermediate root management group where the deployment will be applied.')
param inRootMG string

@description('Optional. Array of PIM Role Assignments for the resource group level. Uses the resource group name for the scope.')
param pimResourceGroups array = []

@description('Optional. Array of PIM Role Assignments for the subscription level. Uses the subscription ID for the scope.')
param pimSubscriptions array = []

@description('Optional. Array of PIM Role Assignments for the management group level. Uses the management group ID for the scope.')
param pimManagementGroups array = []

@description('Optional. Date/time when eligibility starts, defaults to current UTC time.')
param startTime string = utcNow()

@description('Module: PIM Role Assignment - Resource Group Scope - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/authorization/pim-role-assignment')
module pimAssignment_rg 'br/public:avm/ptn/authorization/pim-role-assignment:0.1.2' = [
  for pim in pimResourceGroups: {
    name: take(
      'rgPimAssignment-${guid(pim.subscriptionId, pim.resourceGroup, pim.principalId, pim.roleDefinitionId)}',
      64
    )
    scope: managementGroup(inRootMG)
    params: {
      // Required parameters
      pimRoleAssignmentType: (pim.?roleAssignmentType ?? 'Eligible') == 'Eligible'
        ? {
            roleAssignmentType: pim.?roleAssignmentType ?? 'Eligible'
            scheduleInfo: {
              duration: pim.duration
              durationType: pim.durationType
              startTime: startTime
              endDateTime: pim.?endDateTime ?? ''
            }
          }
        : {
            roleAssignmentType: 'Active'
            scheduleInfo: {
              durationType: 'NoExpiration'
            }
          }
      principalId: pim.principalId
      requestType: pim.requestType
      roleDefinitionIdOrName: pim.roleDefinitionId
      subscriptionId: pim.subscriptionId
      resourceGroupName: pim.resourceGroupName
      // Non-required parameters
      justification: pim.justification ?? ''
      location: location
      ticketInfo: {
        ticketNumber: pim.?ticketNumber ?? null
        ticketSystem: pim.?ticketSystem ?? null
      }
    }
  }
]

@description('Module: PIM Role Assignment - Subscription Scope - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/authorization/pim-role-assignment')
module pimAssignment_sub 'br/public:avm/ptn/authorization/pim-role-assignment:0.1.2' = [
  for pim in pimSubscriptions: {
    name: take('subPimAssignment-${guid(pim.subscriptionId, pim.principalId, pim.roleDefinitionId)}', 64)
    scope: managementGroup(inRootMG)
    params: {
      // Required parameters
      pimRoleAssignmentType: pim.roleAssignmentType == 'Eligible'
        ? {
            roleAssignmentType: pim.roleAssignmentType
            scheduleInfo: {
              duration: pim.duration
              durationType: pim.durationType
              startTime: startTime
              endDateTime: pim.?endDateTime ?? ''
            }
          }
        : {
            roleAssignmentType: 'Active'
            scheduleInfo: {
              durationType: 'NoExpiration'
            }
          }
      principalId: pim.principalId
      requestType: pim.requestType
      roleDefinitionIdOrName: pim.roleDefinitionId
      subscriptionId: pim.subscriptionId
      // Non-required parameters
      justification: pim.justification ?? ''
      location: location
      ticketInfo: {
        ticketNumber: pim.?ticketNumber ?? null
        ticketSystem: pim.?ticketSystem ?? null
      }
    }
  }
]

@description('Module: PIM Role Assignment - Management Group Scope - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/authorization/pim-role-assignment')
module pimAssignment_mg 'br/public:avm/ptn/authorization/pim-role-assignment:0.1.2' = [
  for pim in pimManagementGroups: {
    name: take('mgPimAssignment-${guid(pim.managementGroupId, pim.principalId, pim.roleDefinitionId)}', 64)
    scope: managementGroup(inRootMG)
    params: {
      // Required parameters
      pimRoleAssignmentType: (pim.?roleAssignmentType ?? 'Eligible') == 'Eligible'
        ? {
            roleAssignmentType: pim.?roleAssignmentType ?? 'Eligible'
            scheduleInfo: {
              duration: pim.duration
              durationType: pim.durationType
              startTime: startTime
              endDateTime: pim.?endDateTime ?? ''
            }
          }
        : {
            roleAssignmentType: 'Active'
            scheduleInfo: {
              durationType: 'NoExpiration'
            }
          }
      principalId: pim.principalId
      requestType: pim.requestType
      roleDefinitionIdOrName: pim.roleDefinitionId
      managementGroupId: pim.managementGroupId
      // Non-required parameters
      justification: pim.justification ?? ''
      location: location
      ticketInfo: {
        ticketNumber: pim.?ticketNumber ?? null
        ticketSystem: pim.?ticketSystem ?? null
      }
    }
  }
]
