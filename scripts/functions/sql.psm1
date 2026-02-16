function Add-TemporarySqlServerFirewallAllowance (
  [Parameter(Mandatory = $true)] [string] $ipToAllow,
  [Parameter(Mandatory = $true)] [string] $serverName,
  [Parameter(Mandatory = $true)] [string] $resourceGroupName,
  [Parameter(Mandatory = $true)] [string] $temporaryFirewallName
) {

  Write-Host "Adding temporary firewall rule '$temporaryFirewallName' to SQL server '$serverName' for '$ipToAllow'"
  if (Get-AzSqlServerFirewallRule -FirewallRuleName $temporaryFirewallName -ResourceGroupName $resourceGroupName -ServerName $serverName -ErrorAction SilentlyContinue) {
    Set-AzSqlServerFirewallRule -FirewallRuleName $temporaryFirewallName -ResourceGroupName $resourceGroupName -ServerName $serverName `
      -StartIpAddress $ipToAllow -EndIpAddress $ipToAllow | Out-Null
  }
  else {
    New-AzSqlServerFirewallRule -FirewallRuleName $temporaryFirewallName -ResourceGroupName $resourceGroupName -ServerName $serverName `
      -StartIpAddress $ipToAllow -EndIpAddress $ipToAllow | Out-Null
  }
}

function Remove-TemporarySqlServerFirewallAllowance (
  [Parameter(Mandatory = $true)] [string] $ipToAllow,
  [Parameter(Mandatory = $true)] [string] $serverName,
  [Parameter(Mandatory = $true)] [string] $resourceGroupName,
  [Parameter(Mandatory = $true)] [string] $temporaryFirewallName
) {

  $existingLocks = Get-AzResourceLock -ResourceGroupName $resourceGroupName -AtScope
  $existingLocks | ForEach-Object {
    Write-Host "Temporarily removing resource lock '$($_.Name)' on resource group '$resourceGroupName'"
    Remove-AzResourceLock -LockId $_.LockId -Confirm:$false -Force | Out-Null
  }
  do {
    Start-Sleep 5
  } until ($null -eq (Get-AzResourceLock -ResourceGroupName $resourceGroupName -AtScope))
  try {
    Write-Host "Removing temporary firewall rule '$temporaryFirewallName' from SQL server '$serverName'"
    Remove-AzSqlServerFirewallRule -FirewallRuleName $temporaryFirewallName -ResourceGroupName $resourceGroupName -ServerName $serverName -Confirm:$false -Force | Out-Null
  }
  finally {
    $existingLocks | ForEach-Object {
      Write-Host "Adding back resource lock '$($_.Name)' on resource group '$resourceGroupName'"
      if ($_.Properties.notes) {
        New-AzResourceLock -ResourceGroupName $resourceGroupName -LockName $_.Name -LockLevel $_.Properties.level -LockNotes $_.Properties.notes -Confirm:$false -Force | Out-Null
      }
      else {
        New-AzResourceLock -ResourceGroupName $resourceGroupName -LockName $_.Name -LockLevel $_.Properties.level -Confirm:$false -Force | Out-Null
      }
    }
  }
    
}


function Invoke-WithTemporarySqlServerFirewallAllowance (
  [Parameter(Mandatory = $true)] [string] $ipToAllow,
  [Parameter(Mandatory = $true)] [string] $serverName,
  [Parameter(Mandatory = $true)] [string] $resourceGroupName,
  [Parameter(Mandatory = $true)] [string] $temporaryFirewallName,
  [Parameter(Mandatory = $true)] [scriptblock] $codeToExecute
) {

  Write-Host "Adding temporary firewall rule '$temporaryFirewallName' to SQL server '$serverName' for '$ipToAllow'"
  if (Get-AzSqlServerFirewallRule -FirewallRuleName $temporaryFirewallName -ResourceGroupName $resourceGroupName -ServerName $serverName -ErrorAction SilentlyContinue) {
    Set-AzSqlServerFirewallRule -FirewallRuleName $temporaryFirewallName -ResourceGroupName $resourceGroupName -ServerName $serverName `
      -StartIpAddress $ipToAllow -EndIpAddress $ipToAllow | Out-Null
  }
  else {
    New-AzSqlServerFirewallRule -FirewallRuleName $temporaryFirewallName -ResourceGroupName $resourceGroupName -ServerName $serverName `
      -StartIpAddress $ipToAllow -EndIpAddress $ipToAllow | Out-Null
  }


  try {
    & $codeToExecute
  }
  finally {
    $existingLocks = Get-AzResourceLock -ResourceGroupName $resourceGroupName -AtScope
    $existingLocks | ForEach-Object {
      Write-Host "Temporarily removing resource lock '$($_.Name)' on resource group '$resourceGroupName'"
      Remove-AzResourceLock -LockId $_.LockId -Confirm:$false -Force | Out-Null
    }
    do {
      Start-Sleep 5
    } until ($null -eq (Get-AzResourceLock -ResourceGroupName $resourceGroupName -AtScope))
    try {
      Write-Host "Removing temporary firewall rule '$temporaryFirewallName' from SQL server '$serverName'"
      Remove-AzSqlServerFirewallRule -FirewallRuleName $temporaryFirewallName -ResourceGroupName $resourceGroupName -ServerName $serverName -Confirm:$false -Force | Out-Null
    }
    finally {
      $existingLocks | ForEach-Object {
        Write-Host "Adding back resource lock '$($_.Name)' on resource group '$resourceGroupName'"
        if ($_.Properties.notes) {
          New-AzResourceLock -ResourceGroupName $resourceGroupName -LockName $_.Name -LockLevel $_.Properties.level -LockNotes $_.Properties.notes -Confirm:$false -Force | Out-Null
        }
        else {
          New-AzResourceLock -ResourceGroupName $resourceGroupName -LockName $_.Name -LockLevel $_.Properties.level -Confirm:$false -Force | Out-Null
        }
      }
    }
  }
}

Export-ModuleMember -Function * -Verbose:$false