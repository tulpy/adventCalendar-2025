Document PSRule {

  $yamlRaw = (Get-Content -Raw $InputObject.FullName)
  $object = ConvertFrom-Yaml -Yaml $yamlRaw -AllDocuments -Ordered

  $title = [regex]::Match($yamlRaw, '(?<=Name:\s)(.+)').Groups[1].Value.Trim()
  $description = [regex]::Match($yamlRaw, '(?<=Description:\s)(.+)').Groups[1].Value.Trim()

  if ($title) {
    Title $title # Use title from comment in YAML file
  }
  else {
    Title $InputObject.Name # Use file name
  }

  if ($description) {
    $description # # Use description from comment in YAML file
  }

  foreach ($rule in $object) {
    # Add an introduction section
    Section $rule.metadata.name {

      if ($rule.spec.expiresOn) {
                ('This rule will expire on ' + (Get-Date $rule.spec.expiresOn -Format 'yyyy-MM-dd' ) + '. This rule must be re-evaluated, with human intervention, for suitability in this solution as the rule has likely been superseded. Refer to any Azure and PSRule.Rules.Azure documentation for any changes that may have occurred.') | Warning
      }

      $rule.metadata.description

      $properties = @(
        @{
          Name       = 'Rule Name';
          Expression = { $rule.metadata.name }
        },
        @{
          Name       = 'Kind';
          Expression = { $rule.kind }
        })

      if ($rule.kind -eq 'SuppressionGroup') {
                ('This custom rule suppresses default rules from PSRule.Rules.Azure.') | Note

        $properties += @{
          Name       = 'Rules';
          Expression = { $rule.spec.rule -join "<br>" }
        }
      }
      else {
                ('This is a custom rule creates a new rule to validate against.') | Note
        $properties += @{
          Name       = 'Recommendation';
          Expression = { $rule.spec.recommend }
        }
      }

      if ($rule.metadata["link"]) {
        $properties += @{
          Name       = 'Link';
          Expression = { $rule.metadata.link }
        }
      }
      $rule | Table -Property $properties

      Section ($rule.metadata.name + ' Code Snippet') {
        'The following is the extracted rule from the YAML file:'

        $rule | ConvertTo-Yaml | Code 'yaml'
      }
    }
  }
}
