
function Get-CurrentUserAzureAdObjectId() {
  $account = (Get-AzContext).Account
  if ($account.Type -eq 'User') {
    $user = Get-AzADUser -UserPrincipalName $account.Id
    if (-not $user) {
      $user = Get-AzADUser -Mail $account.Id
    }
    return $user.Id
  }
  $servicePrincipal = Get-AzADServicePrincipal -ApplicationId $account.Id
  return $servicePrincipal.Id
}

function Get-AdTokenForServicePrincipal (
  [Parameter(Mandatory = $true)]
  [string] $tenantId,
    
  [Parameter(Mandatory = $true)]
  [string] $scope,

  [Parameter(Mandatory = $true)]
  [string] $clientId,

  [Parameter(Mandatory = $true)]
  [SecureString] $clientSecret
) {

  $plainTextSecureString = ConvertFrom-SecureString -SecureString $secureString

  $getTokenUrl = "https://login.microsoftonline.com/$($tenantId)/oauth2/v2.0/token"
  $getTokenHeaders = @{'Content-Type' = "application/x-www-form-urlencoded" }
  $getTokenBody = @{
    "client_secret" = "$plainTextSecureString";
    "client_id"     = "$clientId";
    "grant_type"    = 'client_credentials';
    "scope"         = $scope
  }



  $adAccessToken = (Invoke-RestMethod -Uri $getTokenUrl -Headers $getTokenHeaders -Method POST -Body $getTokenBody).access_token
  Write-Host "Subscriber Active Directory Token created successfully"
  return $adAccessToken
}

function Get-OrNewAzureADGroup {
  param(
    [Parameter(Mandatory)]
    [string] $azureGraphApiAadToken,

    [Parameter(Mandatory)]
    [string]
    $displayName,

    [Parameter(Mandatory)]
    [string]
    $description,

    [switch]
    $isAssignableToRole = $false,

    [switch]
    $isMailEnabled = $false,

    [switch]
    $isSecurityEnabled = $false,

    [switch]
    $isO365Group = $false
  )

  $headers = @{
    "Authorization" = "Bearer $azureGraphApiAadToken";
    "Content-Type"  = "application/json";
  }

  $getUri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$displayName'"
  $existing = Invoke-RestMethod -Uri $getUri -Method "GET" -Headers $headers -Verbose:$false

  if ($existing.value.Length -eq 1) {
    return $existing.value[0]
  }
  else {
    $uri = "https://graph.microsoft.com/beta/groups"

    $ownerUrl = "https://graph.microsoft.com/v1.0/users/"
    $userType = (Get-AzContext).Account.Type
    if ($userType -eq "ServicePrincipal") {
      $ownerUrl = "https://graph.microsoft.com/v1.0/servicePrincipals/"
    }

    $bodyObject = @{
      "description"        = $description;
      "groupTypes"         = $isO365Group ? @("Unified") : @();
      "mailEnabled"        = $isMailEnabled ? $true : $false;
      "securityEnabled"    = $isSecurityEnabled ? $true : $false;
      "mailNickname"       = ($displayName -replace "[@\(\)\\\[\]"";:\.<>, ]", "-");
      "displayName"        = $displayName;
      "isAssignableToRole" = $isAssignableToRole ? $true : $false;
      # Set current user as the owner
      "owners@odata.bind"  = @($ownerUrl + (Get-CurrentUserAzureAdObjectId))
    }

    $bodyJSON = $bodyObject | ConvertTo-Json -Depth 10
    $response = Invoke-RestMethod -Uri $uri -Method "POST" -Body $bodyJSON -Headers $headers -Verbose:$false
    return $response
  }
}

function Get-CurrentUserAzureAdObject() {
  $account = (Get-AzContext).Account
  $returnValue = "" | Select-Object -Property Id, Type

  if ($account.Type -eq 'User') {
    $user = Get-AzADUser -UserPrincipalName $account.Id
    if (-not $user) {
      $user = Get-AzADUser -Mail $account.Id
      $returnValue.Type = "User" # As this is not returned by Get-AzADUser -Mail *
    }
    $returnValue.Id = $user.Id
    $returnValue.Type = $user.Type
    return $returnValue
  }
  $servicePrincipal = Get-AzADServicePrincipal -ApplicationId $account.Id
  $returnValue.Id = $servicePrincipal.Id  
  $returnValue.Type = $servicePrincipal.Type

  return $returnValue
}

function Get-CurrentUserAzureAdId() {
  $account = (Get-AzContext).Account
  return $account.Id
}

function Get-ObjectAzureAdSid(
  [Parameter(Mandatory = $true, ParameterSetName = "email")]
  [string] $name,
  [Parameter(Mandatory = $true, ParameterSetName = "email")]
  [string] $type
  
) {
  if ($type -eq 'User') {
    $account = Get-AzADUser -Mail $name
    return $account.Id
  }
  if ($type -eq 'ServicePrincipal') {
    $account = Get-AzADServicePrincipal -DisplayName $name
    return $account.Id
  }
  # Support more types
  return $null
} 

function Get-RoleDefinitions(
  [Parameter(Mandatory = $false, ParameterSetName = "filterByName")]
  [string[]] $filterByName
) {
  $rolesDefinitionIds = @{}

  # get only filtered names
  if ($filterByName.Count -gt 0 ) {
    foreach ($roleName in $filterByName) {
      $roleDefinition = (Get-AzRoleDefinition $roleName)
      $rolesDefinitionIds[$roleDefinition.Name] = $roleDefinition.Id
    }
  }
  # get all
  else {
    $rolesDefinitionsNative = (Get-AzRoleDefinition)
    foreach ($roleDefinition in $rolesDefinitionsNative) {
      $rolesDefinitionIds[$roleDefinition.Name] = $roleDefinition.Id
    }
  }  
  return $rolesDefinitionIds
}

function Get-AzADGroupObjectOrDisplayName([string] $displayNameObjectId) {
  if (Assert-Guid $displayNameObjectId) {
    $group = Get-AzADGroup -ObjectId $displayNameObjectId -ErrorAction SilentlyContinue
  }
  else {
    $group = Get-AzADGroup -DisplayName $displayNameObjectId -ErrorAction SilentlyContinue
  }
  return $group
}

function Get-OrAddAzureADRoleAssignment {
  param(
    [Parameter(Mandatory)]
    [string] $azureGraphApiAadToken,

    [Parameter(Mandatory)]
    [string]
    $principalId,

    [Parameter(Mandatory)]
    [string]
    $roledisplayName
  )
  $headers = @{
    "Authorization" = "Bearer $azureGraphApiAadToken";
    "Content-Type"  = "application/json";
  }

  $getUri = "https://graph.microsoft.com/beta/roleManagement/directory/roleDefinitions?`$filter=displayName eq '$roledisplayName'"
  $getId = Invoke-RestMethod -Uri $getUri -Method "GET" -Headers $headers -Verbose:$false

  if ($getId.value.Length -eq 1) {
    $roleDefinitionId = $getId.value[0].id

    $getUri2 = "https://graph.microsoft.com/beta/roleManagement/directory/roleAssignments?`$filter=roleDefinitionId eq '$roleDefinitionId' and principalId eq '$principalId'&`$expand=principal"
    $getRoleId = Invoke-RestMethod -Uri  $getUri2 -Method "GET" -Headers $headers -Verbose:$false

    if ($getRoleId.value.Length -eq 1) {
      return $true
    }
    else {
      $postUri = "https://graph.microsoft.com/beta/roleManagement/directory/roleAssignments"

      $bodyObject = @{
        "principalId"      = $principalId;
        "roleDefinitionId" = $roleDefinitionId;
        "directoryScopeId" = "/";
      }
      $bodyJSON = $bodyObject | ConvertTo-Json -Depth 10
      try {
        Invoke-RestMethod -Uri $postUri -Method "POST" -Body $bodyJSON -Headers $headers -Verbose:$false
        return $true
      }
      catch {
        return $false
      }
    }
  }
  else {
    return $false
  }
}


Export-ModuleMember -Function * -Verbose:$false