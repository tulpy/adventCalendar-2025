Document Scripts {

  $help = Get-Help $InputObject.FullName

  Title $InputObject.Name # Use file name

  if ($help) {

    if ($help.Synopsis) {
      $help.Synopsis
    }

    Section 'Script' {
      Resolve-Path -Relative $InputObject | Code 'powershell'

      if ($help.alertSet) {
        '### Notes'
        foreach ($alert in $help.alertSet.alert) {
          $alert.Text
        }
      }
    }

    if ($help.PSObject.Properties.Name -contains 'description') {
      $description = $help.description.Text.ToString()
      if (![string]::IsNullOrEmpty($description)) {
        Section 'Description' {
          $description
        }
      }
    }

    if ($help.PSObject.Properties.Name -contains 'parameters') {
      $parameters = $help.parameters.parameter
      Section 'Parameters' {
        $parameters | Table -Property Name, @{Name = "Default Value"; Expression = { if ($_.defaultValue) { $_.defaultValue } else { '_null_' } } }, @{Name = "Description"; Expression = { if ($_.Description.Text) { $_.Description.Text } else { '_Not provided_' } } }
      }
    }

    if ($help.PSObject.Properties.Name -contains 'examples') {
      $i = 1
      Section 'Examples' {
        foreach ($example in $help.examples.example) {
          Section ('Example ' + $i++) {
            $example.code | Code 'powershell'
            foreach ($textItem in $example.remarks.Text) {
              if (![string]::IsNullOrEmpty($textItem)) {
                $textItem.ToString()
              }
            }
          }
        }
      }
    }
  }
}
