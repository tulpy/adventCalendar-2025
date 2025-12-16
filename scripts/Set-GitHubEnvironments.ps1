<#
  .SYNOPSIS
  This script creates GitHub Environments for a specified repo in a given GitHub organization using the GitHub API.

  .DESCRIPTION
  The script uses `Invoke-RestMethod` to interact with GitHub's API and create specified GitHub Environments within the repo.

  .PARAMETER org
  The name of the GitHub organization that owns the repo.

  .PARAMETER repo
  The name of the repo within the specified organization.

  .PARAMETER environmentNames
  A list of environment names to be created in the repo. Defaults to "platform_managementGroup", "platform_connectivity", "platform_management", "platform_identity", "platform_policy", "platform_role", "platform_firewall".

  .EXAMPLE
  .\Set-GitHubEnvironments.ps1 -org "example-org" -repo "example-repo"

  This example creates the environments 'platform_managementGroup', 'platform_connectivity', 'platform_management', 'platform_identity', 'platform_policy', 'platform_role', 'platform_firewall' in the 'example-repo' repo within the 'example-org' organization.

  .NOTES
  Ensure `Invoke-RestMethod` is available in your PowerShell environment before running this script. Also, ensure you have the necessary permissions for the specified GitHub organization and repo.
#>

param (
  [Parameter(Mandatory = $true)]
  [string]$org,

  [Parameter(Mandatory = $true)]
  [string]$repo,

  [string[]]$environmentNames = @("platform", "platform_canary", "platform_connectivity", "epac_tenant_policy", "epac_tenant_roles", "epac_plan", "epac_canary", "what-if")
)

# Function to get GitHub token
function Get-GitHubToken {
  try {
    $token = & gh auth token
    if (-not $token) {
      throw "Failed to retrieve GitHub token. Ensure you are logged in using 'gh auth login'."
    }
    return $token
  }
  catch {
    throw "Failed to retrieve GitHub token. Ensure you have the GitHub CLI installed and are logged in."
  }
}

# Main script execution
try {
  $token = Get-GitHubToken

  foreach ($environment in $environmentNames) {
    $url = "https://api.github.com/repos/$org/$repo/environments/$Environment"
    $headers = @{
      Authorization = "Bearer $Token"
      Accept        = "application/vnd.github.v3+json"
    }

    $response = Invoke-RestMethod -Uri $url -Method Put -Headers $headers
    Write-Host "✅ Environment '$Environment' created in $org/$repo."
  }
}
catch {
  Write-Host "❌ Script execution failed. Error: $_"
}
