targetScope = 'local'

extension github with {
  token: githubToken
}

metadata name = 'GitHub - Bicep Local Deploy'
metadata description = 'Experimental Bicep Local Deploy GitHub deployment.'
metadata version = '0.0.1'
metadata author = 'Insight APAC Platform Engineering'

@secure()
@description('Required. GitHub personal access token with repo and admin:repo_hook scopes')
param githubToken string

@description('Required. GitHub repository owner')
param owner string

@description('Required. GitHub repository name')
param repoName string

@description('Optional. GitHub repository labels')
param repoLabels array = []

resource repo 'Repository' = {
  owner: owner
  name: repoName
  description: 'Test bicep repository'
  visibility: 'Private'
}

@description('Resource: Create Github labels in the repository')
resource bugLabel 'Label' = [for label in repoLabels: {
  owner: owner
  repo: repo.name
  name: label.name
  description: label.description
  color: label.color
}]

@description('Resource: Create a GitHub secret in the repository')
resource secret 'ActionsSecret' = {
  owner: owner
  repo: repo.name
  name: 'MY_SECRET'
  #disable-next-line use-secure-value-for-secure-inputs
  value: 'super-secret-value' // not a secure value, just for demo purposes
}

@description('Resource: Create a GitHub variable in the repository')
resource variable 'ActionsVariable' = {
  owner: owner
  repo: repoName
  name: 'MY_VARIABLE'
  value: 'just-another-value'
}

// Ouputs
@description('Output: The created repository')
output repo object = repo

@description('Output: The created label')
output variable object = variable

@description('Output: The created labels')
output labels array = bugLabel
