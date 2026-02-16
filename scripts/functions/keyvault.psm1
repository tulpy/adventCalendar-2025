Import-Module Az.KeyVault -Verbose:$false

function Invoke-WithTemporaryKeyVaultFirewallBypass (
  [Parameter(Mandatory = $true)]
  [string] $ipAddressToAllow,

  [Parameter(Mandatory = $true)]
  [string] $keyVaultName,

  [Parameter(Mandatory = $true)]
  [string] $resourceGroupName,

  [Parameter(Mandatory = $true)]
  [ValidateScript({ $_.Ast.ParamBlock.Parameters.Count -eq 0 })]
  [scriptblock] $codeToExecute,

  [switch] $skipBypass = $false
) {
  if ($skipBypass) {
    & $codeToExecute
    return
  }
  
  Write-Host "Temporarily granting '$ipAddressToAllow' to the '$keyVaultName' KeyVault firewall"
  Add-AzKeyVaultNetworkRule -ResourceGroupName $resourceGroupName -VaultName $keyVaultName -IpAddressRange "$ipAddressToAllow/32" -ErrorAction SilentlyContinue
  $ipRanges = (Get-AzKeyVault -ResourceGroupName $resourceGroupName -VaultName $keyVaultName -ErrorAction SilentlyContinue).NetworkAcls.IpAddressRanges | Out-String
  if ($ipRanges -notmatch "$ipAddressToAllow/32") {
    throw "Adding IP '$ipAddressToAllow' to KeyVault '$keyVaultName' wasn't successful; aborting"
  }

  try {
    & $codeToExecute
  }
  finally {
    Write-Host "Removing '$ipAddressToAllow' from the '$keyVaultName' KeyVault firewall"
    Remove-AzKeyVaultNetworkRule -ResourceGroupName $resourceGroupName -VaultName $keyVaultName -IpAddressRange "$ipAddressToAllow/32" -ErrorAction SilentlyContinue
    $ipRanges = (Get-AzKeyVault -ResourceGroupName $resourceGroupName -VaultName $keyVaultName -ErrorAction SilentlyContinue).NetworkAcls.IpAddressRanges | Out-String
    if ($ipRanges -match "$ipAddressToAllow/32") {
      throw "Removing IP '$ipAddressToAllow' from KeyVault '$keyVaultName' wasn't successful; aborting"
    }
  }
}

function Get-OrSetKeyVaultGeneratedSecret {
  param(
    [Parameter(Mandatory = $true)]
    [string]
    $keyVaultName, 

    [Parameter(Mandatory = $true)]
    [string] 
    $secretName,

    [Parameter(Mandatory = $true)]
    [ValidateScript({ $_.Ast.ParamBlock.Parameters.Count -eq 0 })]
    [Scriptblock]
    $generator
  )

  $secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -ErrorAction SilentlyContinue
  if (-not $secret) {
    Write-Host "No existing value for secret '$secretName' in KeyVault '$keyVaultName' so generating and persisting instead"

    # Generate value
    $secretValue = & $generator

    # Convert to SecureString
    if ($secretValue -isnot [SecureString]) {
      $secretValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
    }

    # Set the value
    Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -SecretValue $secretValue -ErrorAction Stop | Out-Null

    # Get it back out so the value is the same as when this if statement isn't triggered
    $secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -ErrorAction SilentlyContinue
  }
  else {
    Write-Host "Found existing value for secret '$secretName' in KeyVault '$keyVaultName'"
  }
  
  $value = $secret.SecretValue
  $value.MakeReadOnly()

  return $value
}


function Get-Password {
  # https://gist.github.com/onlyann/00d9bb09d4b1338ffc88a213509a6caf
  param(
    [Parameter(Mandatory = $false)]
    [ValidateRange(12, 256)]
    [int] 
    $length = 20
  )

  $symbols = '!@#$%^&*'.ToCharArray()
  $characterList = 'a'..'z' + 'A'..'Z' + '0'..'9' + $symbols
    
  do {
    $password = ""
    for ($i = 0; $i -lt $length; $i++) {
      $randomIndex = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(0, $characterList.Length)
      $password += $characterList[$randomIndex]
    }

    [int]$hasLowerChar = $password -cmatch '[a-z]'
    [int]$hasUpperChar = $password -cmatch '[A-Z]'
    [int]$hasDigit = $password -match '[0-9]'
    [int]$hasSymbol = $password.IndexOfAny($symbols) -ne -1

  }
  until (($hasLowerChar + $hasUpperChar + $hasDigit + $hasSymbol) -ge 3)
    
  $password | ConvertTo-SecureString -AsPlainText
}

function Set-KeyVaultSecretValue {
  param(
    [Parameter(Mandatory = $true)]
    [string]
    $keyVaultName, 

    [Parameter(Mandatory = $true)]
    [string] 
    $secretName,

    [Parameter(Mandatory = $true)]
    [SecureString]
    $secretValue
  )

  $secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -ErrorAction SilentlyContinue
  if (-not $secret) {
    Write-Host "No existing value for secret '$secretName' in KeyVault '$keyVaultName' so generating and persisting instead"

    # Convert to SecureString
    if ($secretValue -isnot [SecureString]) {
      $secretValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
    }

    # Set the value
    Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -SecretValue $secretValue -ErrorAction Stop | Out-Null

    # Get it back out so the value is the same as when this if statement isn't triggered
    $secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -ErrorAction SilentlyContinue
  }
  else {
    Write-Host "Found existing value for secret '$secretName' in KeyVault '$keyVaultName'"
  }
  
  $value = $secret.SecretValue
  $value.MakeReadOnly()

  return $value
}

function Get-AzKeyVaultAccessPolicies (
  [Parameter(Mandatory = $true)]
  [string] $keyVaultName,

  [Parameter(Mandatory = $true)]
  [string] $resourceGroupName
) {
  $keyVault = Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

  if ($keyVault) {
    if ($keyVault.AccessPolicies) {
      $keyVaultPolicies = $keyVault.AccessPolicies
      $keyVaultAccessPoliciesFormatted = @()
      $keyVaultAccessPoliciesFormatted += $keyVaultPolicies | ForEach-Object { 
        [ordered]@{
          tenantId    = $_.TenantId
          objectId    = if ($null -ne $_.ObjectId) { $_.ObjectId } else { $_.ApplicationId }
          permissions = [ordered]@{
            keys         = @($_.PermissionsToKeys)
            secrets      = @($_.PermissionsToSecrets)
            certificates = @($_.PermissionsToCertificates)
          }
        } 
      }
      return $keyVaultAccessPoliciesFormatted
    }
    else {
      Write-Warning "No access policies found in KeyVault $keyVaultName"
      return $null
    }
  }
  else {
    Write-Warning "No KeyVault $keyVaultName found in Resouce Group $resourceGroupName"
    return $null
  }
}

Export-ModuleMember -Function * -Verbose:$false
