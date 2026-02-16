Document Firewall {

  $IgnoreColumnsNetworkRule = @('ruleCollectionGroupPriority', 'ruleCollection', 'ruleCollectionGroup', 'ruleCollectionGroupKey', 'ruleType', 'fqdnTags', 'httpHeadersToInsert', 'protocols', 'targetFqdns', 'targetUrls', 'terminateTLS', 'webCategories') # Columns to ignore if there is too much data to display
  $IgnoreColumnsApplicationRule = @('ruleCollectionGroupPriority', 'ruleCollection', 'ruleCollectionGroup', 'ruleCollectionGroupKey', 'ruleType', 'destinationFqdns', 'destinationIpGroups', 'destinationPorts', 'ipProtocols') # Columns to ignore if there is too much data to display
  $IgnoreColumnsNatRule = @('ruleCollectionGroupPriority', 'ruleCollection', 'ruleCollectionGroup', 'ruleCollectionGroupKey', 'fqdnTags', 'httpHeadersToInsert', 'protocols', 'targetFqdns', 'targetUrls', 'terminateTLS', 'webCategories', 'destinationFqdns', 'destinationIpGroups') # Columns to ignore if there is too much data to display

  $ipGroups = $InputObject[0]
  $Rules = $InputObject[1]
  $collections = $InputObject[2]
  $collectionGroups = $InputObject[3]
  $diagrams = $InputObject[4]

  Title 'Azure Firewall'

  Section "Rule Collection Groups" {
    "Rule Collection Groups are used to group multiple rules together. The rules collection groups and their priority order are:"
    $value = $collectionGroups | ForEach-Object {
      $toLower = $_.ruleCollectionGroup.ToLower()
      [PSCustomObject]@{
        Name       = "[" + $_.ruleCollectionGroup + "](#" + $toLower + ")"
        'Priority' = $_.ruleCollectionGroupPriority
      }
    }
    $value | Table -Property Name, Priority

  }

  Section "Rule Collections" {
    "Rule Collections group rules that live together. The rules collections and their priority order are:"
    $value = $collections | ForEach-Object {
      $toLower = $_.ruleCollectionName.ToLower()
      [PSCustomObject]@{
        Name                  = "[" + $_.ruleCollectionName + "](#" + $toLower + ")"
        'Priority'            = $_.ruleCollectionPriority
        'RuleCollectionGroup' = "[" + $_.ruleCollectionGroup + "](#" + $toLower + ")"
      }
    }
    $value | Table -Property Name, Priority, RuleCollectionGroup

  }


  Section "IP Groups" {
    "IP Groups are used to group multiple IP addresses together. The IP groups and their IP addresses are:"
    $value = $ipGroups | ForEach-Object {
      [PSCustomObject]@{
        Name           = $_.name
        'IP Addresses' = $_.ipAddresses -join ", "
      }
    }
    $value | Table -Property Name, 'IP Addresses'
  }

  Section "Firewall Rules" {
    "The following firewall rules are grouped by each rule collection group:"

    # Loop through each collection group and create separate tables for NetworkRules and ApplicationRules
    $collectionGroups | ForEach-Object { $groupName = $_.ruleCollectionGroup
      Section "$groupName" {
        if ($diagrams) {
          "[[/.media/$($groupName.ToLower()).png]]"
          "![$($groupName)](../.media/$($groupName.ToLower()).png)"
        }
        $collections | Where-Object { $_.ruleCollectionGroup -eq $groupName } | ForEach-Object {
          $collectionName = $_.ruleCollectionName
          Section $($_.ruleCollectionName) {

            $networkRules = @();
            $appRules = @();
            $natRules = @();
            $notfound = $null
            $networkRules = $Rules | Where-Object { $_.ruleCollection -eq $collectionName -and $_.ruleType -eq "NetworkRule" }
            $appRules = $Rules | Where-Object { $_.ruleCollection -eq $collectionName -and $_.ruleType -eq "ApplicationRule" }
            $natRules = $Rules | Where-Object { $_.ruleCollection -eq $collectionName -and $_.ruleType -eq "NatRule" }

            if ($networkRules.Count -gt 0) {
              $SelectNetwork = $networkRules[0].PSObject.Properties.Name | Where-Object { $IgnoreColumnsNetworkRule -notcontains $_ }
              $networkRules | Table -Property $SelectNetwork
            }
            else {
              $notfound += "- No Network Rules found`n"
            }

            if ($appRules.Count -gt 0) {
              $SelectApp = $appRules[0].PSObject.Properties.Name | Where-Object { $IgnoreColumnsApplicationRule -notcontains $_ }
              $appRules | Table -Property $SelectApp
            }
            else {
              $notfound += "- No Application Rules`n"
            }

            if ($natRules.Count -gt 0) {
              $SelectNat = $NatRules[0].PSObject.Properties.Name | Where-Object { $IgnoreColumnsNatRule -notcontains $_ }
              $natRules | Table -Property $SelectNat
            }
            else {
              $notfound += "- No NAT Rules found`n"
            }
            $notfound
          }
        }
      }
    }
  }
}
