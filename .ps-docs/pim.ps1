Document PIM {
  $fileProperties = $InputObject[0]
  $pimAssignmentsObject = $InputObject[1]
  $file = Get-Content -Raw $fileProperties
  $object = ConvertFrom-Json $file -Depth 1000

  Title "Privileged Identity Management (PIM)"

  # Table of Contents
  "- [Overview](#overview)"
  "- [Tenant PIM Assignments](#tenant-pim-assignments)"
  "- [Management Group PIM Assignments](#management-group-pim-assignments)"
  "- [Subscription PIM Assignments](#subscription-pim-assignments)"
  "- [Resource Group PIM Assignments](#resource-group-pim-assignments)"

  Section "Overview" {
    "This document is automatically generated from the ``src\configuration\platform\privilegedIdentityManagement.bicepparam`` file."
    ""

    # Count PIM assignments by type
    $tenantCount = if ($object.parameters.pimAssignmentsTenant.value) { $object.parameters.pimAssignmentsTenant.value.Count } else { 0 }
    $mgCount = if ($object.parameters.pimAssignmentsManagementGroup.value) { $object.parameters.pimAssignmentsManagementGroup.value.Count } else { 0 }
    $subCount = if ($object.parameters.pimAssignmentsSubscription.value) { $object.parameters.pimAssignmentsSubscription.value.Count } else { 0 }
    $rgCount = if ($object.parameters.pimAssignmentsResourceGroup.value) { $object.parameters.pimAssignmentsResourceGroup.value.Count } else { 0 }
    $totalCount = $tenantCount + $mgCount + $subCount + $rgCount
    "**Total PIM Assignments: $totalCount**"
    ""
    "- Tenant assignments: $tenantCount"
    "- Management Group assignments: $mgCount"
    "- Subscription assignments: $subCount"
    "- Resource Group assignments: $rgCount"
  }

  Section "Tenant PIM Assignments" {
    if ($object.parameters.pimAssignmentsTenant.value.Count -gt 0) {
      $tenantPIMs = @()
      foreach ($assignment in $object.parameters.pimAssignmentsTenant.value) {
        $searchedDefinition = $pimAssignmentsObject | Where-Object { $_.Id -eq $assignment.roleDefinitionId }
        $tenantPIMs += [PSCustomObject]@{
          PrincipalId   = $assignment.principalId
          Definition    = if ($searchedDefinition) { "$($searchedDefinition.Name) (``$($searchedDefinition.Id)``)" } else { $assignment.roleDefinitionId }
          Scope         = "Tenant"
          Duration      = $assignment.duration
          Expiration    = $assignment.expirationType
          Justification = $assignment.justification
        }
      }
      $tenantPIMs | Table -Property PrincipalId, Definition, Scope, Duration, Expiration, Justification
    }
    else {
      "No Tenant PIM assignments configured."
    }
  }

  Section "Management Group PIM Assignments" {
    if ($object.parameters.pimAssignmentsManagementGroup.value.Count -gt 0) {
      $mgPIMs = @()
      foreach ($assignment in $object.parameters.pimAssignmentsManagementGroup.value) {
        $searchedDefinition = $pimAssignmentsObject | Where-Object { $_.Id -eq $assignment.roleDefinitionId }
        $mgPIMs += [PSCustomObject]@{
          PrincipalId   = $assignment.principalId
          Definition    = if ($searchedDefinition) { "$($searchedDefinition.Name) (``$($searchedDefinition.Id)``)" } else { $assignment.roleDefinitionId }
          Scope         = "``$($assignment.managementGroupId)``"
          Duration      = $assignment.duration
          Expiration    = $assignment.expirationType
          Justification = $assignment.justification
        }
      }
      $mgPIMs | Table -Property PrincipalId, Definition, Scope, Duration, Expiration, Justification
    }
    else {
      "No Management Group PIM assignments configured."
    }
  }

  Section "Subscription PIM Assignments" {
    if ($object.parameters.pimAssignmentsSubscription.value.Count -gt 0) {
      $subPIMs = @()
      foreach ($assignment in $object.parameters.pimAssignmentsSubscription.value) {
        $searchedDefinition = $pimAssignmentsObject | Where-Object { $_.Id -eq $assignment.roleDefinitionId }
        $subPIMs += [PSCustomObject]@{
          PrincipalId   = $assignment.principalId
          Definition    = if ($searchedDefinition) { "$($searchedDefinition.Name) (``$($searchedDefinition.Id)``)" } else { $assignment.roleDefinitionId }
          Scope         = "``$($assignment.subscriptionId)``"
          Duration      = $assignment.duration
          Expiration    = $assignment.expirationType
          Justification = $assignment.justification
        }
      }
      $subPIMs | Table -Property PrincipalId, Definition, Scope, Duration, Expiration, Justification
    }
    else {
      "No Subscription PIM assignments configured."
    }
  }

  Section "Resource Group PIM Assignments" {
    if ($object.parameters.pimAssignmentsResourceGroup.value.Count -gt 0) {
      $rgPIMs = @()
      foreach ($assignment in $object.parameters.pimAssignmentsResourceGroup.value) {
        $searchedDefinition = $pimAssignmentsObject | Where-Object { $_.Id -eq $assignment.roleDefinitionId }
        $rgPIMs += [PSCustomObject]@{
          PrincipalId   = $assignment.principalId
          Definition    = if ($searchedDefinition) { "$($searchedDefinition.Name) (``$($searchedDefinition.Id)``)" } else { $assignment.roleDefinitionId }
          Scope         = "``$($assignment.resourceGroup)``"
          Duration      = $assignment.duration
          Expiration    = $assignment.expirationType
          Justification = $assignment.justification
        }
      }
      $rgPIMs | Table -Property PrincipalId, Definition, Scope, Duration, Expiration, Justification
    }
    else {
      "No Resource Group PIM assignments configured."
    }
  }
}
