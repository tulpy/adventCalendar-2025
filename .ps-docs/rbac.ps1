Document RBAC {
  $fileProperties = $InputObject[0]
  $azureRolesObject = $InputObject[1]
  $file = Get-Content -Raw $fileProperties
  $object = ConvertFrom-Json $file -Depth 1000

  Title "Role-Based Access Control (RBAC)"

  # Table of Contents
  "- [Overview](#overview)"
  "- [Management Group Role Assignments](#management-group-role-assignments)"
  "- [Subscription Role Assignments](#subscription-role-assignments)"
  "- [Resource Group Role Assignments](#resource-group-role-assignments)"
  "- [Resource Role Assignments](#resource-role-assignments)"


  Section "Overview" {
    "This document is automatically generated from the ``src\configuration\platform\roleAssignments.bicepparam`` file."
    ""

    # Count role assignments by type
    $mgCount = if ($object.parameters.rolesManagementGroup.value) { $object.parameters.rolesManagementGroup.value.Count } else { 0 }
    $subCount = if ($object.parameters.roleSubscriptions.value) { $object.parameters.roleSubscriptions.value.Count } else { 0 }
    $rgCount = if ($object.parameters.roleResourceGroup.value) { $object.parameters.roleResourceGroup.value.Count } else { 0 }
    $resCount = if ($object.parameters.roleResource.value) { $object.parameters.roleResource.value.Count } else { 0 }
    $totalCount = $mgCount + $subCount + $rgCount + $resCount

    "**Total Role Assignments: $totalCount**"
    ""
    "- Management Group roles: $mgCount"
    "- Subscription roles: $subCount"
    "- Resource Group roles: $rgCount"
    "- Resource roles: $resCount"

    "> **Note**: Principal Ids listed in this document can be searched within the Entra Tenancy to identify the associated users, groups, or service principals."
  }

  Section "Management Group Role Assignments" {
    if ($object.parameters.rolesManagementGroup.value.Count -gt 0) {
      $mgRoles = @()
      foreach ($role in $object.parameters.rolesManagementGroup.value) {
        $searchedDefinition = $azureRolesObject | Where-Object { $_.Id -eq $role.roleDefinitionId }
        $mgRoles += [PSCustomObject]@{
          PrincipalId   = $role.assigneeObjectId
          Definition    = if ($searchedDefinition) { "$($searchedDefinition.Name) (``$($searchedDefinition.Id)``)" } else { $role.roleDefinitionId }
          PrincipalType = $role.assigneePrincipalType
          Scope         = "``$($role.managementGroupId)``"
          Condition     = if ($role.condition) { "``$($role.condition)``" } else { "``None``" }
        }
      }
      $mgRoles | Table -Property PrincipalId, Definition, PrincipalType, Scope, Condition
    }
    else {
      "No Management Group role assignments configured."
    }
  }

  Section "Subscription Role Assignments" {
    if ($object.parameters.roleSubscriptions.value.Count -gt 0) {
      $subRoles = @()
      foreach ($role in $object.parameters.roleSubscriptions.value) {
        $searchedDefinition = $azureRolesObject | Where-Object { $_.Id -eq $role.roleDefinitionId }
        $subRoles += [PSCustomObject]@{
          PrincipalId   = $role.assigneeObjectId
          Definition    = if ($searchedDefinition) { "$($searchedDefinition.Name) (``$($searchedDefinition.Id)``)" } else { $role.roleDefinitionId }
          PrincipalType = $role.assigneePrincipalType
          Scope         = "``$($role.subscriptionId)``"
          Condition     = if ($role.condition) { "``$($role.condition)``" } else { "``None``" }
        }
      }
      $subRoles | Table -Property PrincipalId, Definition, PrincipalType, Scope, Condition
    }
    else {
      "No Subscription role assignments configured."
    }
  }

  Section "Resource Group Role Assignments" {
    if ($object.parameters.roleResourceGroup.value.Count -gt 0) {
      $rgRoles = @()
      foreach ($role in $object.parameters.roleResourceGroup.value) {
        $searchedDefinition = $azureRolesObject | Where-Object { $_.Id -eq $role.roleDefinitionId }
        $rgRoles += [PSCustomObject]@{
          PrincipalId   = $role.assigneeObjectId
          Definition    = if ($searchedDefinition) { "$($searchedDefinition.Name) (``$($searchedDefinition.Id)``)" } else { $role.roleDefinitionId }
          PrincipalType = $role.assigneePrincipalType
          Scope         = "``$($role.resourceGroupName)``"
          Condition     = if ($role.condition) { "``$($role.condition)``" } else { "``None``" }
        }
      }
      $rgRoles | Table -Property PrincipalId, Definition, PrincipalType, Scope, Condition
    }
    else {
      "No Resource Group role assignments configured."
    }
  }

  Section "Resource Role Assignments" {
    if ($object.parameters.roleResource.value.Count -gt 0) {
      $resRoles = @()
      foreach ($role in $object.parameters.roleResource.value) {
        $resourceName = ($role.resourceId -split '/')[-1]
        $searchedDefinition = $azureRolesObject | Where-Object { $_.Id -eq $role.roleDefinitionId }
        $resRoles += [PSCustomObject]@{
          PrincipalId   = $role.assigneeObjectId
          Definition    = if ($searchedDefinition) { "$($searchedDefinition.Name) (``$($searchedDefinition.Id)``)" } else { $role.roleDefinitionId }
          PrincipalType = $role.assigneePrincipalType
          Scope         = "``$resourceName``"
          Condition     = if ($role.condition) { "``$($role.condition)``" } else { "``None``" }
        }
      }
      $resRoles | Table -Property PrincipalId, Definition, PrincipalType, Scope, Condition
    }
    else {
      "No Resource role assignments configured."
    }
  }
}
