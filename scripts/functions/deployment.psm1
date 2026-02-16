Import-Module Az.Accounts -Verbose:$false
Import-Module (Join-Path $PSScriptRoot "utilities.psm1") -Force -Verbose:$false
Import-Module (Join-Path $PSScriptRoot "core.psm1") -Force -Verbose:$false
Import-Module (Join-Path $PSScriptRoot "azuread.psm1") -Force -Verbose:$false

function Publish-Variables(
  [Parameter(Mandatory = $true)]
  [Hashtable] $values,

  [Parameter(Mandatory = $false)]
  [switch] $isSecret = $false
) {
  $isLocal = $env:LOCAL_DEPLOYMENT -eq "True"
  $isAzureDevOps = $env:TF_BUILD -eq "True"
  $isGithubActions = $env:GITHUB_ACTIONS -eq "true"

  $localValues = @{}

  $values.Keys | ForEach-Object {
    $value = $values[$_]

    # Handle secure string
    if ($value -is [securestring]) {
      if (-not $isSecret) {
        throw "Attempted to publish SecureString $_ without -isSecret"
      }

      # Convert to plain text so we can interact with it
      $value = ConvertFrom-SecureString -SecureString $value -AsPlainText
    }

    # Convert non-strings to JSON so it can be stored as a string
    if ($value -isnot [string]) {
      $value = ConvertTo-Json $value -Compress
    }

    # Always store in an environment variable so that it can be retrieved again
    [System.Environment]::SetEnvironmentVariable($_, $value, [System.EnvironmentVariableTarget]::Process)

    # If we are running locally then stash the value (with encryption for secrets)
    if ($isLocal) {
      if (-not $isSecret) {
        $localValues[$_] = $value
      }
      else {
        $localValues[$_] = "encrypted:" + (New-LocalEncryptedSecret (ConvertTo-SecureString -AsPlainText $value -Force))
      }
    }

    # If we are running in Azure DevOps then we need to output the value as a variable
    if ($isAzureDevOps) {

      $output = @("task.setvariable variable=$_", "isOutput=true")

      if ($isSecret) {
        $output += "isSecret=true"
      }

      Write-Output "##vso[$($output -join ";");]$value"
    }

    # If we are running on GitHub Actions, we need to output the values as variable using Github Action syntax
    if ($isGithubActions) {
      if ($isSecret) {
        Write-Output "::add-mask::$($_)"
      }

      # source: https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/
      Write-Output "$($_)=$($value)" >> $env:GITHUB_OUTPUT
    }
  }

  # If we are running locally then we need to stash the new values into the local json file
  if ($isLocal) {
    $localVariablesFile = $env:LOCAL_DEPLOYMENT_PUBLISHED_VARIABLES_FILE

    $existingAsJson = Get-Content -Path $localVariablesFile -Raw -ErrorAction SilentlyContinue
    if (-not $existingAsJson) {
      $existingAsJson = "{}"
    }

    $existingAsHash = ConvertFrom-Json ($existingAsJson) -AsHashtable
    $existingAsHash.Keys | ForEach-Object {
      if (-not ($localValues[$_])) {
        $localValues[$_] = $existingAsHash[$_]
      }
    }

    Set-Content -Path $localVariablesFile -Value (ConvertTo-Json $localValues) -Force
  }
}

function Initialize-DeploymentContext(
  [Parameter(Mandatory = $true)]
  [Hashtable] $parameters,

  [Parameter(Mandatory = $true)]
  [string] $configurationFilePath
) {

  switch -Wildcard ($configurationFilePath) {
    # JSON ARM Template File
    '*.json' {
      $configuration = ConvertFrom-Json (Get-Content -Path $configurationFilePath -Raw) -AsHashtable
      break
    }
    # Bicep Param File
    '*.bicepparam' {
      # Build parameters from the bicep file and resolve its full path
      bicep build-params $configurationFilePath
      $resolvedPath = Resolve-Path $configurationFilePath

      # Determine the new file path within the 'temp' directory
      $newPath = Join-Path -Path (Split-Path -Path $resolvedPath -Parent) -ChildPath "temp"
      $newFilePath = Join-Path -Path $newPath -ChildPath ((Split-Path -Path $resolvedPath -Leaf).Replace('.bicepparam', '.json'))

      # Create the 'temp' directory if it doesn't exist
      if (-not (Test-Path -Path $newPath)) {
        New-Item -Path $newPath -ItemType Directory -Force -WhatIf:$false
      }

      # Determine expected source JSON next to the .bicepparam
      $sourceJson = Join-Path -Path (Split-Path -Path $resolvedPath -Parent) -ChildPath ((Split-Path -Path $resolvedPath -Leaf).Replace('.bicepparam', '.json'))

      # If the source JSON exists, move it into temp; if it doesn't but the temp file already exists, use it; otherwise fail with guidance
      if (Test-Path -Path $sourceJson) {
        Move-Item -Path $sourceJson -Destination $newFilePath -Force -WhatIf:$false
      }
      elseif (-not (Test-Path -Path $newFilePath)) {
        throw "Unable to locate built parameters JSON. Expected at '$sourceJson'. Ensure Bicep CLI is installed and accessible, or run via .local/Deploy-Local.ps1 which sets it up."
      }

      # Convert the json file content to a hashtable
      $configuration = ConvertFrom-Json (Get-Content -Path $newFilePath -Raw) -AsHashtable
      break
    }
    default {
      throw "Unsupported file type for deployment context initialization"
    }
  }


  # If ARM Parameter file then convert the config value to be a hashtable for object passing
  if ($configuration["`$schema"] -like "*schema.management.azure.com/schemas*") {
    $tempStoreParameterKeys = $configuration.parameters.Keys | ForEach-Object { $_ }

    # Iterate over the temporary keys and update the original collection
    foreach ($key in $tempStoreParameterKeys) {
      $configuration.parameters[$key] = $configuration.parameters[$key].value
    }
  }

  $context = Join-HashTables -hashtable1 $parameters -hashtable2 $configuration

  # Remove any ARM Parameter file Keys that really aren't needed
  $context.Remove("`$schema")
  $context.Remove("contentVersion")

  # Local deployment parameter overrides
  if ($env:LOCAL_DEPLOYMENT -eq "True") {
    $ParameterOverrides = ConvertFrom-Json $env:LOCAL_DEPLOYMENT_CONFIGURATION_OVERRIDES -AsHashtable
    $ParameterOverrides.Keys | ForEach-Object { $context.parameters[$_] = $ParameterOverrides[$_] }
  }

  # Set up Azure context
  $azureContext = Get-AzContext
  if (-not $azureContext) {
    throw "Execute Connect-AzAccount to establish your Azure connection"
  }
  if ($azureContext.Subscription.Id -ne $context.SubscriptionId) {
    Write-Verbose "Ensuring Azure context is set to specified Azure subscription $($context.SubscriptionId)"
    Set-AzContext -Tenant $context.TenantId -SubscriptionId $context.SubscriptionId -WhatIf:$false
  }
  if ($azureContext.Subscription.Id -ne $context.SubscriptionId) {
    throw "Error trying to set Azure context to specified Azure subscription $($context.SubscriptionId)"
  }

  # get currentUserObjectId
  $currentUser = Get-CurrentUserAzureAdObject
  $context.currentUserObjectId = $currentUser.Id
  $context.currentUserType = $currentUser.Type

  # In dev environments allow developer Azure AD ids to read deployment KeyVault
  if ($env:LOCAL_DEPLOYMENT -ne "True" -and $context.developersObjectIds.length -gt 0) {
    throw "Trying to add developers to read KeyVault secrets insecurely in a non-local environment. Please remove these devs from developersObjectIds from your .local config files."
  }

  # set Azure Authorization Roles definition ids
  $context.rolesDefinitionIds = Get-RoleDefinitions -filterByName $context.requiredRoleDefinitions

  return $context
}

Export-ModuleMember -Function * -Verbose:$false
