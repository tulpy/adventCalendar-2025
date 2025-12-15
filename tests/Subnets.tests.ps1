[CmdletBinding(SupportsShouldProcess = $true)]
Param (
  [string[]] $BicepParams = @("src/configuration/platform/platformIdentity-per.bicepparam"),
  [string] $FolderPath = "src/configuration/lz"
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

    # Determine vNetAddressPrefix before constructing the hashtable
    $vNetAddressPrefix = $null
    if ($parameterData.parameters.PSObject.Properties.Name -contains 'virtualNetworkConfiguration') {
      $vNetAddressPrefix = $parameterData.parameters.virtualNetworkConfiguration.value.addressPrefixes
    }

    # Create a test case for this file
    $fileTestCase = @{
      FileName                 = Split-Path -Leaf $BicepParam
      FileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($BicepParam)
      FilePath                 = $BicepParam
      SubscriptionId           = $parameterData.parameters.subscriptionId.value
      vNetAddressPrefix        = $vNetAddressPrefix
      SubnetTestCases          = @()
    }

    if ($parameterData.parameters.PSObject.Properties.Name -contains 'virtualNetworkConfiguration') {
      $subnets = $parameterData.parameters.virtualNetworkConfiguration.value.subnets
      # Build test cases for all subnets with security rules
      foreach ($subnet in $subnets) {
        $fileTestCase.SubnetTestCases += @{
          SubnetName          = $subnet.name
          SubnetAddressPrefix = $subnet.addressPrefix
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

Describe 'Subnet Validation' {
  Context "Subscription: <SubscriptionId> (<FileNameWithoutExtension>)" -ForEach $fileTestCases {
    Context "Subnet: <SubnetName>" -ForEach $SubnetTestCases {
      It 'should have a valid address prefix' {
        $SubnetAddressPrefix | Should -Not -BeNullOrEmpty -Because "Address prefix for subnet '$SubnetName' in file '$FileNameWithoutExtension' is null or empty."
        $SubnetAddressPrefix | Should -Match '^\d{1,3}(\.\d{1,3}){3}(/\d{1,2})?$' -Because "Address prefix '$SubnetAddressPrefix' for subnet '$SubnetName' in file '$FileNameWithoutExtension' is not a valid CIDR notation."
      }
      It 'should have a valid name' {
        $SubnetName | Should -Not -BeNullOrEmpty -Because "Subnet name is null or empty in file '$FileNameWithoutExtension'."
        $SubnetName | Should -Match '^[a-zA-Z0-9-]+$' -Because "Subnet name '$SubnetName' in file '$FileNameWithoutExtension' contains invalid characters. Only alphanumeric and hyphens are allowed."
      }
      It 'subnet CIDR should be within vNet CIDR' {
        # Convert CIDR to IP range for comparison
        function Get-IPRange {
          param([string]$CIDR)
          $ip, $prefixLength = $CIDR -split '/'
          $ipBytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
          [Array]::Reverse($ipBytes)
          $ipInt = [System.BitConverter]::ToUInt32($ipBytes, 0)
          $maskInt = [uint32]::MaxValue -shl (32 - [int]$prefixLength)
          $startInt = $ipInt -band $maskInt
          $endInt = $startInt + (-bnot $maskInt)
          return @{Start = $startInt; End = $endInt }
        }

        $vNetRange = Get-IPRange -CIDR $vNetAddressPrefix
        $subnetRange = Get-IPRange -CIDR $SubnetAddressPrefix

        $subnetRange.Start | Should -BeGreaterOrEqual $vNetRange.Start -Because "Subnet '$SubnetName' ('$SubnetAddressPrefix') start address is outside vNet ('$vNetAddressPrefix') in file '$FileNameWithoutExtension'."
        $subnetRange.End | Should -BeLessOrEqual $vNetRange.End -Because "Subnet '$SubnetName' ('$SubnetAddressPrefix') end address is outside vNet ('$vNetAddressPrefix') in file '$FileNameWithoutExtension'."
      }
    }
  }
}
