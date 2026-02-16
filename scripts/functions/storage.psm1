function Get-StorageContext([string] $Name, [string] $ResourceGroupName) {
  $storageContext = New-AzStorageContext -StorageAccountName $Name -UseConnectedAccount 
  return $storageContext
}

function Set-StorageContainer(
  [Parameter(Mandatory)]
  [Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext] $Context,
  [Parameter(Mandatory)]
  [string] $Name
) {

  if (-not (Get-AzStorageContainer -Name $Name -Context $Context -ErrorAction SilentlyContinue)) {
    Write-Host "$(Get-Date -Format FileDateTimeUniversal) Creating '$Name' storage container in $($Context.StorageAccountName)"
    New-AzStorageContainer -Name $Name -Context $Context -Permission Off | Out-Null
  }
  else {
    Write-Host "$(Get-Date -Format FileDateTimeUniversal) '$Name' storage container exists in $($Context.StorageAccountName)."
  }
}

function Set-StorageBlobContents(
  [Parameter(Mandatory)]
  [string] $StorageResourceGroupName,
  [Parameter(Mandatory)]
  [string] $StorageAccountName,
  [Parameter(Mandatory)]
  [string] $StorageContainerName,
  [Parameter(Mandatory)]
  [string] $Path
  
) {
  $storageContext = Get-StorageContext -Name $StorageAccountName -ResourceGroupName $StorageResourceGroupName
  Get-ChildItem (Join-Path $PSScriptRoot $Path) | ForEach-Object {
    Write-Host "Uploading $($_.Name) to $StorageAccountName/$StorageContainerName"
    Set-AzStorageBlobContent -File $_.FullName -Container $StorageContainerName -Blob $_.Name -Context $storageContext `
      -Force -Properties @{"ContentType" = "text/plain" } -Verbose:$false -Confirm:$false | Out-Null
  }
}
function Invoke-WithTemporaryStorageFirewallBypass (
  [Parameter(Mandatory = $true)]
  [string] $ipAddressToAllow,

  [Parameter(Mandatory = $true)]
  [string] $storageAccountName,

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
  
  Write-Host "Temporarily granting '$ipAddressToAllow' to the '$storageAccountName' Storage account"
  Add-AzStorageAccountNetworkRule -ResourceGroupName $resourceGroupName -Name $storageAccountName -IPAddressOrRange "$ipAddressToAllow" -ErrorAction SilentlyContinue
  $ipRanges = (Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -ErrorAction SilentlyContinue).NetworkRuleSet.IpRules | Out-String
  if ($ipRanges -notmatch $ipAddressToAllow) {
    throw "Adding IP '$ipAddressToAllow' to Storage account '$storageAccountName' wasn't successful; aborting"
  }

  try {
    & $codeToExecute
  }
  finally {
    Write-Host "Removing '$ipAddressToAllow' from the '$storageAccountName' Storage account"
    Remove-AzStorageAccountNetworkRule -ResourceGroupName $resourceGroupName -Name $storageAccountName -IPAddressOrRange "$ipAddressToAllow" -ErrorAction SilentlyContinue
    $ipRanges = (Get-AzStorageAccount  -ResourceGroupName $resourceGroupName -Name $storageAccountName -ErrorAction SilentlyContinue).NetworkRuleSet.IpRules | Out-String
    if ($ipRanges -match $ipAddressToAllow) {
      throw "Removing IP '$ipAddressToAllow' from Storage account '$storageAccountName' wasn't successful; aborting"
    }
  }
}

Export-ModuleMember -Function * -Verbose:$false
