[CmdletBinding(SupportsShouldProcess = $true)]
Param (
  [string[]] $BicepParams = @(""),
  [string] $FolderPath = ""
)

#Requires -Version 7.0.0

Set-StrictMode -Version "Latest"
$ErrorActionPreference = "Stop"

BeforeDiscovery {
  $RootPath = Resolve-Path -Path (Join-Path $PSScriptRoot "..")

  # Initialize script-level variable to store test cases per file
  $script:fileTestCases = @()

  # Combine explicitly provided BicepParams with files discovered from FolderPath
  $allBicepParams = @()
  
  # Ensure BicepParams is treated as an array
  if ($null -eq $BicepParams) {
    $BicepParams = @()
  } elseif ($BicepParams -is [string]) {
    $BicepParams = @($BicepParams)
  }
  
  # Add explicitly provided bicep params (convert relative paths to absolute)
  foreach ($param in $BicepParams) {
    if ([System.IO.Path]::IsPathRooted($param)) {
      $allBicepParams += $param
    } else {
      $allBicepParams += Join-Path $RootPath $param
    }
  }
  
  # Also discover all .bicepparam files in the specified folder
  $ConfigurationPath = Join-Path $RootPath $FolderPath
  if (Test-Path -Path $ConfigurationPath) {
    $discoveredParams = @(Get-ChildItem -Path $ConfigurationPath -Filter "*.bicepparam" | ForEach-Object { $_.FullName })
    if ($discoveredParams.Count -gt 0) {
      $allBicepParams += $discoveredParams
    }
    Write-Host "Found $($discoveredParams.Count) bicep parameter files in $FolderPath"
  } else {
    Write-Warning "Configuration directory not found: $ConfigurationPath"
  }
  
  # Remove duplicates and use the combined list
  $BicepParams = @($allBicepParams | Sort-Object -Unique)
  Write-Host "Total bicep parameter files to test: $($BicepParams.Count)"

  foreach ($BicepParam in $BicepParams) {
    $BicepParam = Resolve-Path -Path $BicepParam
    if (-not (Test-Path -Path $BicepParam)) {
      throw "Bicep parameter file not found: $BicepParam"
    }

    # Build bicep params to JSON
    Write-Host "Building bicep parameter file: $BicepParam"
    $jsonOutput = & bicep build-params $BicepParam --stdout 2>$null
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to build bicep parameter file: $BicepParam"
    }

    $parameterData = ($jsonOutput | ConvertFrom-Json).parametersJson | ConvertFrom-Json

    # Create a test case for this file
    $fileTestCase = @{
      FileName                 = Split-Path -Leaf $BicepParam
      FileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($BicepParam)
      FilePath                 = $BicepParam
      SubscriptionId           = $parameterData.parameters.subscriptionId.value
      SubnetTestCases          = @()
    }

    if ($parameterData.parameters.PSObject.Properties.Name -contains 'virtualNetworkConfiguration') {
      $subnets = $parameterData.parameters.virtualNetworkConfiguration.value.subnets
      # Build test cases for all subnets with security rules
      foreach ($subnet in $subnets) {
        # Ensure securityRules is treated as an array
        $securityRules = @()
        if ($null -ne $subnet.securityRules) {
          if ($subnet.securityRules -is [array]) {
            $securityRules = $subnet.securityRules
          } else {
            $securityRules = @($subnet.securityRules)
          }
        }
        
        if ($securityRules.Count -gt 0) {
          foreach ($rule in $securityRules) {
            $fileTestCase.SubnetTestCases += @{
              SubnetName = $subnet.name
              Rule       = $rule
              RuleName   = $rule.name
              Properties = $rule.properties
            }
          }
        }
      }
    }

    # Only add file test case if it has subnet test cases
    $subnetTestCases = @($fileTestCase.SubnetTestCases)
    if ($subnetTestCases.Count -gt 0) {
      $script:fileTestCases += $fileTestCase
    }
  }

  # Ensure the variable is initialized even if no test cases were found
  if ($null -eq $script:fileTestCases) {
    $script:fileTestCases = @()
  }
}

Describe 'NSG Rules Validation' {
  Context "Subscription: <SubscriptionId> (<FileNameWithoutExtension>)" -ForEach $fileTestCases {
    Context "Rule: <SubnetName>/<RuleName>" -ForEach $SubnetTestCases {
      It 'name should follow naming convention' {
        if ($RuleName -notlike "*Microsoft.Databricks-workspaces*") {
          $RuleName | Should -Match '^(INBOUND|OUTBOUND)-FROM-.+-TO-.+-PORT-.+-PROT-.+-\w+$' -Because "Rule does not follow naming convention: (INBOUND|OUTBOUND)-FROM-<source>-TO-<dest>-PORT-<port>-PROT-<protocol>-<action>"
        }
      }

      It 'name should not exceed maximum name length' {
        $RuleName.Length | Should -BeLessOrEqual 80 -Because "Rule name exceeds maximum length of 80 characters (current: $($RuleName.Length))"
      }

      It 'should have valid protocol' {
        $Properties.protocol | Should -BeIn @('Tcp', 'Udp', 'Icmp', '*') -Because "Invalid protocol '$($Properties.protocol)'. Must be Tcp, Udp, Icmp, or *"
      }

      It 'should have valid access type' {
        $Properties.access | Should -BeIn @('Allow', 'Deny') -Because "Invalid access '$($Properties.access)'. Must be Allow or Deny"
      }

      It 'should have valid direction' {
        $Properties.direction | Should -BeIn @('Inbound', 'Outbound') -Because "Invalid direction '$($Properties.direction)'. Must be Inbound or Outbound"
      }

      It 'should have valid priority range' {
        $Properties.priority | Should -BeGreaterOrEqual 100 -Because "Priority $($Properties.priority) is below minimum allowed value of 100"
        $Properties.priority | Should -BeLessOrEqual 4096 -Because "Priority $($Properties.priority) exceeds maximum allowed value of 4096"
      }

      It 'should have valid source address configuration' {
        $hasPrefix = ($Properties.PSObject.Properties.Name -contains 'sourceAddressPrefix') -and $null -ne $Properties.sourceAddressPrefix -and $Properties.sourceAddressPrefix -ne ''
        $hasPrefixes = ($Properties.PSObject.Properties.Name -contains 'sourceAddressPrefixes') -and $null -ne $Properties.sourceAddressPrefixes -and $Properties.sourceAddressPrefixes.Count -gt 0

        ($hasPrefix -xor $hasPrefixes) | Should -BeTrue -Because "Must have either sourceAddressPrefix OR sourceAddressPrefixes, not both or neither"

        if ($hasPrefix) {
          $Properties.sourceAddressPrefix | Should -Not -BeNullOrEmpty -Because "sourceAddressPrefix is empty"
        }
        elseif ($hasPrefixes) {
          $Properties.sourceAddressPrefixes.Count | Should -BeGreaterThan 0 -Because "sourceAddressPrefixes array is empty"
        }
      }

      It 'should have valid destination address configuration' {
        $hasDestPrefix = ($Properties.PSObject.Properties.Name -contains 'destinationAddressPrefix') -and $null -ne $Properties.destinationAddressPrefix -and $Properties.destinationAddressPrefix -ne ''
        $hasDestPrefixes = ($Properties.PSObject.Properties.Name -contains 'destinationAddressPrefixes') -and $null -ne $Properties.destinationAddressPrefixes -and $Properties.destinationAddressPrefixes.Count -gt 0

        ($hasDestPrefix -xor $hasDestPrefixes) | Should -BeTrue -Because "Must have either destinationAddressPrefix OR destinationAddressPrefixes, not both or neither"

        if ($hasDestPrefix) {
          $Properties.destinationAddressPrefix | Should -Not -BeNullOrEmpty -Because "destinationAddressPrefix is empty"
        }
        elseif ($hasDestPrefixes) {
          $Properties.destinationAddressPrefixes.Count | Should -BeGreaterThan 0 -Because "destinationAddressPrefixes array is empty"
        }
      }

      It 'should have valid port range configuration' {
        $hasPortRange = ($Properties.PSObject.Properties.Name -contains 'destinationPortRange') -and $null -ne $Properties.destinationPortRange -and $Properties.destinationPortRange -ne ''
        $hasPortRanges = ($Properties.PSObject.Properties.Name -contains 'destinationPortRanges') -and $null -ne $Properties.destinationPortRanges -and $Properties.destinationPortRanges.Count -gt 0

        ($hasPortRange -xor $hasPortRanges) | Should -BeTrue -Because "Must have either destinationPortRange OR destinationPortRanges, not both or neither"

        if ($hasPortRange) {
          $Properties.destinationPortRange | Should -Match '^\d+(-\d+)?$|^\*$' -Because "Invalid port range format '$($Properties.destinationPortRange)'. Must be a single port (80), range (80-443), or wildcard (*)"
        }
        elseif ($hasPortRanges) {
          $Properties.destinationPortRanges | ForEach-Object {
            $_ | Should -Match '^\d+(-\d+)?$|^\*$' -Because "Invalid port range format '$_' in destinationPortRanges. Must be a single port (80), range (80-443), or wildcard (*)"
          }
        }
      }

      It 'should not have conflicting priority values within the same subnet' {
        # Get all rules for the current subnet from the current file's test cases
        $currentSubnetRules = $SubnetTestCases | Where-Object { $_.SubnetName -eq $SubnetName }

        # Separate by direction
        $inboundRules = $currentSubnetRules | Where-Object { $_.Properties.direction -eq 'Inbound' }
        $outboundRules = $currentSubnetRules | Where-Object { $_.Properties.direction -eq 'Outbound' }

        # Check inbound duplicates
        $inboundPriorities = $inboundRules | Group-Object -Property { $_.Properties.priority }
        $inboundDuplicates = $inboundPriorities | Where-Object { $_.Count -gt 1 }

        $inboundDuplicates | ForEach-Object {
          $duplicateRuleNames = $_.Group.RuleName -join ', '
          $_.Name | Should -BeNullOrEmpty -Because "Found duplicate Inbound priority $($_.Name) used by rules: $duplicateRuleNames. Each rule must have unique priority within its direction"
        }

        # Check outbound duplicates
        $outboundPriorities = $outboundRules | Group-Object -Property { $_.Properties.priority }
        $outboundDuplicates = $outboundPriorities | Where-Object { $_.Count -gt 1 }

        $outboundDuplicates | ForEach-Object {
          $duplicateRuleNames = $_.Group.RuleName -join ', '
          $_.Name | Should -BeNullOrEmpty -Because "Found duplicate Outbound priority $($_.Name) used by rules: $duplicateRuleNames. Each rule must have unique priority within its direction"
        }
      }

      It 'should have proper description' {
        $Properties.description | Should -Not -BeNullOrEmpty -Because "Rule is missing a description. Descriptions are required for documentation and audit purposes"
        $Properties.description.Length | Should -BeGreaterThan 10 -Because "Rule has insufficient description (length: $($Properties.description.Length)). Provide meaningful context about the rule's purpose"
        $Properties.description.Length | Should -BeLessOrEqual 512 -Because "Rule description exceeds 512 character limit (length: $($Properties.description.Length))"
      }
    }
  }
}
