
function Get-FlattenHashtable {
  param (
    [System.Collections.Hashtable]$Hashtable
  )

  # This list will hold all the flattened entries
  $flattenedEntries = New-Object System.Collections.Generic.List[System.String]

  # Inner function to recursively flatten the hashtable
  function Get-NestedHashtable {
    param (
      [System.Collections.Hashtable]$ht,
      [string]$prefix = ''  # This helps to maintain the nested context
    )
    foreach ($key in $ht.Keys) {
      $value = $ht[$key]
      if ($value -is [System.Collections.Hashtable]) {
        # Recursive call for nested hashtables
        Get-NestedHashtable -ht $value -prefix "$prefix$key."
      }
      else {
        # Add flattened key=value pair to the list
        $flattenedEntries.Add("$prefix$key=$value")
      }
    }
  }

  # Start recursion with the input hashtable
  Get-NestedHashtable -ht $Hashtable

  # Return the list joined as a single string with semicolons as separators
  return $flattenedEntries -join ";`n"
}

function Get-PoliciestoExport {
  param (
    [object] $Object,
    [string] $Type
  )

  switch ($Type) {
    "Assignment" {
      $data = $Object | ForEach-Object {
        if ($_.Contains('properties')) {
          if ($_.properties.Contains('parameters')) {
            $parametersString = Get-FlattenHashtable -Hashtable $_.properties.parameters
          }
          else {
            $parametersString = "None"
          }

          [PSCustomObject]@{
            Name               = if ($_.Contains('name')) { $_.name } else { "Not Specified" }
            DisplayName        = $_.properties.displayName
            Description        = $_.properties.description
            PolicyDefinitionId = if ($_.properties.Contains('policyDefinitionId')) { $_.properties.policyDefinitionId } else { "Not Specified" }
            EnforcementMode    = $_.properties.enforcementMode
            AssignedBy         = if ($_.properties.Contains('metadata')) {
              if ($_.properties.metadata.Contains('assignedBy')) { $_.properties.metadata.assignedBy } else { "Not Specified" }
            }
            Scope              = if ($_.properties.Contains('scope')) {
              if (-not [string]::IsNullOrWhiteSpace($_.properties.scope)) { $_.properties.scope -join ", " } else { "*" }
            }
            NotScopes          = if ($_.properties.Contains('notScopes')) {
              if (-not [string]::IsNullOrWhiteSpace($_.properties.notScopes)) { $_.properties.notScopes -join ", " } else { " " }
            }
            Parameters         = $parametersString
          }
        }
      }
    }
    "Definition" {
      $data = $Object | ForEach-Object {

        if ($_.Contains('properties')) {
          # Flattening the policyRule into a readable format
          $policyRuleStringIf = "None"
          $policyRuleStringThen = "None"
          if ($_.properties.Contains('policyRule')) {
            if ($_.properties.policyRule.Contains('if')) {
              $policyRuleStringIf = Get-FlattenHashtable -Hashtable $_.properties.policyRule.if
            }

            if ($_.properties.policyRule.Contains('then')) {
              $policyRuleStringThen = Get-FlattenHashtable -Hashtable $_.properties.policyRule.if
            }
          }

          if ($_.properties.Contains('parameters')) {
            $parametersString = Get-FlattenHashtable -Hashtable $_.properties.parameters
          }
          else {
            $parametersString = "None"
          }

          [PSCustomObject]@{
            Name           = if ($_.Contains('name')) { $_.name } else { "Not Specified" }
            PolicyType     = $_.properties.policyType
            Mode           = if ($_.properties.Contains('mode')) { $_.properties.mode } else { "Not Specified" }
            DisplayName    = $_.properties.displayName
            Description    = $_.properties.description
            Parameters     = $parametersString
            PolicyRuleIf   = $policyRuleStringIf
            PolicyRuleThen = $policyRuleStringThen
          }
        }
      }
    }
    "Exemption" {
      $data = $Object | ForEach-Object {

        if ($_.Contains('properties')) {
          [PSCustomObject]@{
            Name                         = $_.name
            DisplayName                  = $_.properties.displayName
            Description                  = $_.properties.description
            Metadata                     = if ($_.properties.contains('metadata')) { Get-FlattenHashtable -Hashtable $_.properties.metadata } else { "None" }
            ExemptionCategory            = $_.properties.exemptionCategory
            ExpiresOn                    = $_.properties.expiresOn
            AssignmentScopeValidation    = $_.properties.assignmentScopeValidation
            PolicyAssignmentId           = $_.properties.policyAssignmentId
            PolicyDefinitionReferenceIds = $_.properties.policyDefinitionReferenceIds
          }
        }
      }
    }
    Default { throw "Invalid Type" }
  }

  return $data
}

Export-ModuleMember -Function * -Verbose:$false
