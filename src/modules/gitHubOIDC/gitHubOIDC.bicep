extension microsoftGraphV1

targetScope = 'managementGroup'

metadata name = 'GitHub OIDC Creation '
metadata description = 'GitHub OIDC setup, including Microsoft Entra Enterprise Apps and Service Principals, Federated Identity Credentials and Azure Role Assignments.'
metadata version = '1.0.0'
metadata author = 'Insight APAC Platform Engineering'

@description('The type for GitHub OIDC configuration.')
type gitHubOIDCType = {
  @maxLength(256)
  @description('Required. The unique identifier that can be assigned to an application and used as an alternate key. Immutable.')
  applicationName: string

  @maxLength(256)
  @description('Required. The display name for the application. Maximum length is 256 characters.')
  applicationDisplayName: string

  @maxLength(600)
  @description('Optional. The unvalidated description of the federated identity credential, provided by the user. It has a limit of 600 characters.')
  ficDescription: string?

  @description('Required. You can provide either the display name of the role definition (must be configured in the variable `builtInRoleNames`), or its fully qualified ID in the following format: \'/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11\'.')
  roleDefinitions: array

  @description('Required. The type of GitHub subject claim. Determines what part of the GitHub workflow can authenticate.')
  subjectType: ('environment' | 'branch' | 'tag' | 'pull_request')

  @description('Required. The subject values. For environment: environment names. For branch: branch names (e.g., ["main", "develop"]). For tag: tag patterns (e.g., ["refs/tags/v*"]). For pull_request: use ["pull_request"].')
  subjectValues: array

  @maxLength(90)
  @description('Required. The group IDs of the Management groups.')
  managementGroupIds: array
}

@description('Required. Configuration for GitHub OIDC workload identities')
param gitHubConfiguration gitHubOIDCType[]

@description('Optional. The Azure Region to deploy the resources into.')
param location string = deployment().location

@description('Required. The owner of the Github organisation that is assigned to a workload identity')
param gitHubOwner string

@description('Required. The GitHub repository that is assigned to a workload identity')
param gitHubRepo string

//Variables
var gitHubOIDCProvider = 'https://token.actions.githubusercontent.com'
var microsoftEntraAudience = 'api://AzureADTokenExchange'

// Helper function to build the subject claim based on type
var subjectClaims = flatten(map(
  gitHubConfiguration,
  config =>
    map(
      config.subjectValues,
      subjectValue =>
        config.subjectType == 'environment'
          ? 'repo:${gitHubOwner}/${gitHubRepo}:environment:${subjectValue}'
          : config.subjectType == 'branch'
              ? 'repo:${gitHubOwner}/${gitHubRepo}:ref:refs/heads/${subjectValue}'
              : config.subjectType == 'tag'
                  ? 'repo:${gitHubOwner}/${gitHubRepo}:ref:${subjectValue}'
                  : 'repo:${gitHubOwner}/${gitHubRepo}:pull_request'
    )
))

// Flatten configuration: create one entry for each subject value within each configuration
var expandedGitHubConfiguration = flatten(map(
  range(0, length(gitHubConfiguration)),
  i =>
    map(range(0, length(gitHubConfiguration[i].subjectValues)), k => {
      configIndex: i
      subjectIndex: k
      applicationName: gitHubConfiguration[i].applicationName
      applicationDisplayName: gitHubConfiguration[i].applicationDisplayName
      ficDescription: gitHubConfiguration[i].?ficDescription
      subjectType: gitHubConfiguration[i].subjectType
      subjectValue: gitHubConfiguration[i].subjectValues[k]
      roleDefinitions: gitHubConfiguration[i].roleDefinitions
      managementGroupIds: gitHubConfiguration[i].managementGroupIds
    })
))

// Flatten role assignments: create one entry for each management group and role definition combination in each expanded configuration
var flattenedGitHubConfiguration = flatten(map(
  range(0, length(expandedGitHubConfiguration)),
  i =>
    flatten(map(
      range(0, length(expandedGitHubConfiguration[i].managementGroupIds)),
      k =>
        map(range(0, length(expandedGitHubConfiguration[i].roleDefinitions)), j => {
          configIndex: expandedGitHubConfiguration[i].configIndex
          subjectIndex: expandedGitHubConfiguration[i].subjectIndex
          expandedIndex: i
          managementGroupIndex: k
          roleIndex: j
          applicationName: expandedGitHubConfiguration[i].applicationName
          managementGroupId: expandedGitHubConfiguration[i].managementGroupIds[k]
          roleDefinitions: expandedGitHubConfiguration[i].roleDefinitions[j]
        })
    ))
))

@description('Resource: Microsoft Graph Application')
resource identityGithubActionsApplications 'Microsoft.Graph/applications@v1.0' = [
  for (item, i) in expandedGitHubConfiguration: {
    displayName: item.applicationDisplayName
    uniqueName: replace(replace(toLower(item.applicationName), ' ', '-'), '_', '-')
  }
]

@description('Resource: Microsoft Graph Federated Identity Credential')
resource gitHubFederatedIdentityCredential 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = [
  for (item, i) in expandedGitHubConfiguration: {
    name: '${identityGithubActionsApplications[i].uniqueName}/${identityGithubActionsApplications[i].uniqueName}-${i}'
    description: item.?ficDescription ?? 'Federated credential for ${item.subjectType}: ${item.subjectValue}'
    audiences: [
      microsoftEntraAudience
    ]
    issuer: gitHubOIDCProvider
    subject: subjectClaims[i]
    dependsOn: [
      identityGithubActionsApplications[i]
    ]
  }
]

@description('Resource: Microsoft Graph Service Principal')
resource gitHubActionsSp 'Microsoft.Graph/servicePrincipals@v1.0' = [
  for (item, i) in expandedGitHubConfiguration: {
    appId: identityGithubActionsApplications[i].appId
    dependsOn: [
      gitHubFederatedIdentityCredential
    ]
  }
]

@description('Module: Azure Role Assignments - https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/authorization/role-assignment')
module roleAssignment 'br/public:avm/ptn/authorization/role-assignment:0.2.4' = [
  for (assignment, idx) in flattenedGitHubConfiguration: {
    name: take(
      'roleAssignment-${uniqueString(assignment.applicationName, assignment.roleDefinitions, string(idx))}',
      64
    )
    dependsOn: [
      gitHubActionsSp
    ]
    params: {
      // Required parameters
      principalId: gitHubActionsSp[assignment.expandedIndex].id
      roleDefinitionIdOrName: assignment.roleDefinitions
      // Non-required parameters
      description: 'Role Assignment (management group scope)'
      location: location
      managementGroupId: assignment.managementGroupId
      principalType: 'ServicePrincipal'
    }
  }
]

@description('The Application IDs of the created GitHub Actions applications')
output gitHubActionsAppIds array = [
  for (item, i) in expandedGitHubConfiguration: {
    applicationName: item.applicationName
    subjectValue: item.subjectValue
    appId: identityGithubActionsApplications[i].appId
    objectId: identityGithubActionsApplications[i].id
  }
]

// Outputs
@description('The Service Principal IDs of the created GitHub Actions service principals')
output gitHubActionsSpIds array = [
  for (item, i) in expandedGitHubConfiguration: {
    applicationName: item.applicationName
    subjectValue: item.subjectValue
    servicePrincipalId: gitHubActionsSp[i].id
    servicePrincipalObjectId: gitHubActionsSp[i].id
  }
]
