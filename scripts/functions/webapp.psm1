Import-Module Az.Websites -Verbose:$false
function Invoke-WithTemporaryWebAppFirewallBypass (
  [Parameter(Mandatory = $true)]
  [string] $ipAddressToAllow,

  [Parameter(Mandatory = $true)]
  [string] $webAppName,

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

  Write-Host "Temporarily granting '$ipAddressToAllow' to the '$webAppName' WebApp firewall"

  Add-AzWebAppAccessRestrictionRule -ResourceGroupName  $resourceGroupName -WebAppName $webAppName -Name deploymentIP -Priority 200 -Action Allow -IpAddress "$ipAddressToAllow/32" -ErrorAction SilentlyContinue
  $ipRanges = (Get-AzWebAppAccessRestrictionConfig -ResourceGroupName $resourceGroupName -Name $webAppName).MainSiteAccessRestrictions | Where-Object { $_.RuleName -eq 'deploymentIP' } | Select-Object -ExpandProperty IpAddress  | Out-String
  if ($ipRanges -notmatch "$ipAddressToAllow/32") {
    throw "Adding IP '$ipAddressToAllow' to WebApp '$webAppName' wasn't successful; aborting"
  }

  $codeToExecuteError = $null
  try {
    & $codeToExecute
  }
  catch {
    $codeToExecuteError = $_
  }
  finally {
    Write-Host "Removing '$ipAddressToAllow' from the '$webAppName' WebApp firewall"
    Remove-AzWebAppAccessRestrictionRule -ResourceGroupName  $resourceGroupName -WebAppName $webAppName -Name deploymentIP -ErrorAction SilentlyContinue
    $ipRanges = (Get-AzWebAppAccessRestrictionConfig -ResourceGroupName $resourceGroupName -Name $webAppName).MainSiteAccessRestrictions | Where-Object { $_.RuleName -eq 'deploymentIP' } | Select-Object -ExpandProperty IpAddress  | Out-String
    if ($ipRanges -match "$ipAddressToAllow/32") {
      throw "Removing IP '$ipAddressToAllow' from WebApp '$webAppName' wasn't successful; aborting"
    }
  }

  if ($null -ne $codeToExecuteError) {
    throw $codeToExecuteError
  }
}

Export-ModuleMember -Function * -Verbose:$false
