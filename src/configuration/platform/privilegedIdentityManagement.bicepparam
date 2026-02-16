using '../../modules/privilegedIdentityManagement/privilegedIdentityManagement.bicep'

param inRootMG = 'mg-alz'
param pimResourceGroups = [
  // {
  //   resourceGroup: 'arg-aue-plat-mgmt-jumphosts'
  //   subscriptionId: '693bc0de-b583-4f8a-93a4-3375fced6f04'
  //   principalId: '7189d5e8-1708-4f19-8361-ee345970871b' // SG-Bastion-Reader
  //   roleDefinitionId: 'fb879df8-f326-4884-b1cf-06f3ad86be52' // Virtual Machine User Login RoleId
  //   roleAssignmentType: 'Eligible' 
  //   duration: 'PT8H' // 8 hours
  //   durationType: 'AfterDuration'
  //   justification: 'Grant Virtual Machine User Login permissions to members of SG-Bastion-Reader for secure access to bastion hosts'
  //   requestType: 'AdminUpdate'
  // }
]

param pimSubscriptions = [
  {
    subscriptionId: '0b5d0018-2879-4810-b8d7-4f8dda5ce0b9'
    principalId: 'e5906c27-d401-4768-9c79-1dab42fd1a80' // stephen tulp
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/54e12137-a595-5bd4-8992-77ec228f04f8' // app owner
    roleAssignmentType: 'Eligible'
    duration: 'PT8H' // 8 hours
    durationType: 'AfterDuration'
    justification: 'test'
    requestType: 'AdminUpdate'
  }
]

param pimManagementGroups = [
  // {
  //   managementGroupId: 'mg-platform'
  //   principalId: '2e5413f4-8905-4d78-a2a6-f3fbb53f4c6e' // SG-Platform-owner
  //   roleDefinitionId: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // Owner RoleId
  //   roleAssignmentType: 'Eligible'
  //   duration: 'PT8H' // 8 hours
  //   durationType: 'AfterDuration'
  //   justification: 'Grant Owner role to members of SG-Platform-owner for full administrative control over platform resources'
  //   requestType: 'AdminUpdate'
  // }
]
