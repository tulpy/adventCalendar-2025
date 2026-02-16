Document Policies {

  $IgnoreColumns = @("Parameters", "PolicyRuleIf", "PolicyRuleThen", "EnforcementMode", "PolicyDefinitionId", "AssignedBy", "PolicyDefinitionReferenceIds") # Columns to ignore as they have too much data for markdown

  $Name = $InputObject[0]
  $InputObject = $InputObject[1]

  Title $Name

  if ($InputObject -is [System.Collections.Hashtable]) {
    $InputObject.Keys | Sort-Object | ForEach-Object {
      Section "Management Group ($_)" {

        $Data = $InputObject[$_]
        $Select = $Data[0].PSObject.Properties.Name | Where-Object { $IgnoreColumns -notcontains $_ }
        $Data | Table -Property $Select
      }
    }
  }
  else {
    $Data = $InputObject
    $Select = $Data[0].PSObject.Properties.Name | Where-Object { $IgnoreColumns -notcontains $_ }
    $InputObject | Table -Property $Select
  }
}
