targetScope = 'managementGroup'

@description('This test deployment validates the configuration and deployment of the Role Assignment module.')
module roleAssignmentTestModule '../roleAssignments.bicep' = {
  name: 'roleAssignmentTestDeployment'
  params: {
    inRootMG: 'mg-alz'
  }
}
