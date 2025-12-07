using 'main.bicep'

// Use the following to set the token:
// export GITHUB_TOKEN=$(gh auth token)
param githubToken = readEnvironmentVariable('GITHUB_TOKEN')

param owner = 'tulpy'
param repoName = 'adventCalendar-2025'
param repoLabels = [
  {
    name: 'bug'
    description: 'Report a bug!'
    color: 'f29513'
  }
  {
    name: 'documentation'
    description: 'Improvements or additions to documentation'
    color: '0075ca'
  }
]
