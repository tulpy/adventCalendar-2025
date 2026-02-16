Import-Module Az.Automation -Verbose:$false


function Get-AzAutomationAccountModulePowerShell7 (
  [Parameter(Mandatory = $true)]
  [string] $ModuleName,
  
  [Parameter(Mandatory = $true)]
  [string] $automationAccount,

  [Parameter(Mandatory = $true)]
  [string] $resourceGroup,

  [Parameter(Mandatory = $true)]
  [string] $subscriptionId
) {
  $result = Invoke-AzRestMethod `
    -Method GET `
    -SubscriptionId $subscriptionId `
    -ResourceGroupName $resourceGroup `
    -ResourceProviderName Microsoft.Automation `
    -ResourceType automationAccounts `
    -Name $automationAccount/powershell7Modules/$ModuleName `
    -ApiVersion 2022-08-08

  return $result
}

function Install-AzAutomationAccountModulePowerShell7 (
  [Parameter(Mandatory = $true)]
  [string] $ModuleName,
  
  [Parameter(Mandatory = $true)]
  [string] $automationAccount,

  [Parameter(Mandatory = $true)]
  [string] $resourceGroup,

  [Parameter(Mandatory = $true)]
  [string] $subscriptionId,

  [Parameter(Mandatory = $true)]
  $Payload
) {
  Invoke-AzRestMethod `
    -Method PUT `
    -SubscriptionId $subscriptionId `
    -ResourceGroupName $resourceGroup `
    -ResourceProviderName Microsoft.Automation `
    -ResourceType automationAccounts `
    -Name $automationAccount/powershell7Modules/$ModuleName `
    -ApiVersion 2019-06-01 `
    -Payload $Payload
}


function Install-AzAutomationAccountRunbookPowerShell7 (
  [Parameter(Mandatory = $true)]
  [string] $RunbookName,
  
  [Parameter(Mandatory = $true)]
  [string] $automationAccount,

  [Parameter(Mandatory = $true)]
  [string] $resourceGroup,

  [Parameter(Mandatory = $true)]
  [string] $subscriptionId,

  [Parameter(Mandatory = $true)]
  [string] $location,

  [Parameter(Mandatory = $true)]
  $scriptContent
) {
  $emptyDraft = Invoke-AzRestMethod -Method "PUT" -ResourceGroupName $resourceGroup -ResourceProviderName "Microsoft.Automation" `
    -ResourceType "automationAccounts" `
    -Name "${automationAccount}/runbooks/${RunbookName}" `
    -ApiVersion "2017-05-15-preview" `
    -Payload "{`"properties`":{`"runbookType`":`"PowerShell7`", `"logProgress`":false, `"logVerbose`":false, `"draft`":{}}, `"location`":`"${location}`"}"

  $contentDraft = Invoke-AzRestMethod -Method "PUT" -ResourceGroupName $resourceGroup -ResourceProviderName "Microsoft.Automation" `
    -ResourceType automationAccounts `
    -Name "${automationAccount}/runbooks/${RunbookName}/draft/content" `
    -ApiVersion 2015-10-31 `
    -Payload "$scriptContent"

  if (($emptyDraft.StatusCode -eq 200 -or $emptyDraft.StatusCode -eq 201) -and $contentDraft.StatusCode -eq 202) {
    $result = Publish-AzAutomationRunbook -Name $RunbookName -AutomationAccountName $automationAccount -ResourceGroupName $resourceGroup
    return $result
  }
  else {
    return $false
  }
}

Export-ModuleMember -Function * -Verbose:$false
