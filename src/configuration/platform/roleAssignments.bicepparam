using '../../modules/roleAssignments/roleAssignments.bicep'

param inRootMG = 'mg-alz'
param rolesManagementGroups = []
param roleSubscriptions = [
  {
    subscriptionId: '0b5d0018-2879-4810-b8d7-4f8dda5ce0b9'
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7' // Network Contributor
    assigneePrincipalType: 'ServicePrincipal'
    assigneeObjectId: 'eb22721a-8e7a-4f82-8930-880299dc8793' // sp-nopsema-plat-idam
  }
]
param roleResourceGroups = []
param roleResources = []
