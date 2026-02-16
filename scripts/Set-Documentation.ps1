<#
  .SYNOPSIS
    Generates documentation for Bicep modules, PSRule custom rules, RBAC configurations, PIM configurations, scripts, and pricing data.

  .DESCRIPTION
    This script uses PSDocs to generate documentation for Bicep modules, PSRule custom rules, RBAC configurations, PIM configurations, PowerShell scripts, and pricing CSV files. It uses a combination of Bicep and ARM templates to create detailed documentation for each resource. By default, the script looks for Bicep files in 'src/orchestration' and 'src/modules' directories, PSRule files in '.ps-rule' directory, scripts in 'scripts' directory, and pricing CSV files in 'docs/wiki/Pricing' directory. The script also processes RBAC and PIM Bicep parameter files to generate role-based access control and privileged identity management documentation. If the Bicep modules change frequently, set the SkipBicepBuild switch to false to rebuild the Bicep files into ARM templates and ensure the documentation is up-to-date. The script also creates necessary directories for storing the built templates and documentation.

  .PARAMETER BicepDirectoryPaths
    An array of directories to scan for Bicep files. Defaults to 'src/orchestration' and 'src/modules'.

  .PARAMETER PSRuleDirectoryPaths
    An array of directories to scan for PSRule files. Defaults to '.ps-rule'.

  .PARAMETER ScriptsDirectoryPaths
    An array of directories to scan for custom scripts. Defaults to 'scripts'.

  .PARAMETER PricingCSVFilePaths
    An array of directories to scan for pricing CSV files. Defaults to 'docs/wiki/Pricing'.

  .PARAMETER RBACBicepParameterFile
    Path to the RBAC Bicep parameter file. Defaults to 'src/configuration/platform/roleAssignments.bicepparam'.

  .PARAMETER PIMBicepParameterFile
    Path to the PIM Bicep parameter file. Defaults to 'src/configuration/platform/privilegedIdentityManagement.bicepparam'.

  .PARAMETER SkipBicepBuild
    A switch to skip the building of Bicep files into ARM templates. When set, the script uses the existing ARM templates.

  .PARAMETER GitHub
    Indicates whether to update _Sidebar.md with the generated documentation links.

  .PARAMETER AzureRolesDisplayName
    A switch to use Azure role definitions from the signed-in Azure context instead of local source data.

  .EXAMPLE
    .\Set-Documentation.ps1 -SkipBicepBuild:$false

    Scans the default directories for Bicep, PSRule, scripts, and pricing files, builds the Bicep files into ARM templates, and generates the documentation.

  .EXAMPLE
    .\Set-Documentation.ps1 -GitHub -AzureRolesDisplayName

    Generates documentation and updates the GitHub sidebar with links, using Azure role definitions from the current Azure context.

  .NOTES
    This script requires PowerShell version 7.0.0 or later.
    This script requires the Bicep CLI if the SkipBicepBuild switch is not set.
    This script requires powershell-yaml, psdocs, and psdocs.azure modules installed.
    When using AzureRolesDisplayName, ensure you are signed in to Azure with appropriate permissions.
#>


[CmdletBinding(SupportsShouldProcess = $true)]
param (
  [Parameter(HelpMessage = "Array of directories to scan for Bicep files")]
  [ValidateNotNullOrEmpty()]
  [string[]] $BicepDirectoryPaths = @('src/orchestration', 'src/modules'),

  [Parameter(HelpMessage = "Array of directories to scan for PSRule files")]
  [ValidateNotNullOrEmpty()]
  [string[]] $PSRuleDirectoryPaths = @('.ps-rule'),

  [Parameter(HelpMessage = "Array of directories to scan for PowerShell scripts")]
  [ValidateNotNullOrEmpty()]
  [string[]] $ScriptsDirectoryPaths = @('scripts'),

  [Parameter(HelpMessage = "Array of directories to scan for pricing CSV files")]
  [ValidateNotNullOrEmpty()]
  [string[]] $PricingCSVFilePaths = @('docs/wiki/Pricing'),

  [Parameter(HelpMessage = "Path to the RBAC Bicep parameter file")]
  [ValidateNotNullOrEmpty()]
  [string] $RBACBicepParameterFile = 'src/configuration/platform/roleAssignments.bicepparam',

  [Parameter(HelpMessage = "Path to the PIM Bicep parameter file")]
  [ValidateNotNullOrEmpty()]
  [string] $PIMBicepParameterFile = 'src/configuration/platform/privilegedIdentityManagement.bicepparam',

  [Parameter(HelpMessage = "Skip building Bicep files into ARM templates")]
  [switch] $SkipBicepBuild,

  [Parameter(HelpMessage = "Update GitHub _Sidebar.md with generated documentation links")]
  [switch] $GitHub,

  [Parameter(HelpMessage = "Use Azure role definitions from signed-in Azure context")]
  [switch] $AzureRolesDisplayName
)

#Requires -Version 7.0.0
#Requires -module powershell-yaml,psdocs,psdocs.azure

Set-StrictMode -Version "Latest"
$ErrorActionPreference = "Stop"

$RootPath = Resolve-Path -Path (Join-Path $PSScriptRoot "..")
Import-Module (Join-Path $PSScriptRoot "functions/utilities.psm1") -Force -Verbose:$false
Import-Module (Join-Path $PSScriptRoot "functions/roles.psm1") -Force -Verbose:$false
try {

  #####################################################################################
  # Build Bicep Files into parameters files and ARM templates to generate documentation
  #####################################################################################

  $psDocsFile = (Join-Path $RootPath 'ps-docs.yaml')

  # Initialize content accumulator for GitHub sidebar
  $allContentToAdd = ""

  $roles = @()
  if ($AzureRolesDisplayName.IsPresent) {
    if (Get-AzContext) {
      $roles = Get-AzRoleDefinition | Select-Object Name, Id, Description
      Write-Host -ForegroundColor Cyan "🔍 Azure roles collected from signed in Azure context."
    }
    else {
      Write-Host -ForegroundColor Yellow "⚠️ No Azure context found. Roles will use local source."
      $roles = Get-AzureRolesLocal
    }
  }
  else {
    Write-Host -ForegroundColor Cyan "🔍 Azure Roles from local source."
    $roles = Get-AzureRolesLocal
  }

  if ($null -ne $RBACBicepParameterFile) {
    $rbacBicepFile = (Join-Path $RootPath $RBACBicepParameterFile)
    if (Test-Path -Path $rbacBicepFile) {
      Write-Host "`r`nBuilding RBAC Bicep file: $($rbacBicepFile)"
      $rbacBicepFile = Get-Item -Path $rbacBicepFile
      $outFile = Join-Path $rbacBicepFile.DirectoryName "temp/$($rbacBicepFile.BaseName).json"
      bicep build-params ($rbacBicepFile.FullName) --outfile $outFile 2>$null | Out-Null
      if ($LASTEXITCODE -ne 0) {
        Write-Host -ForegroundColor Red "❌ RBAC Bicep file invalid.`r`n"
        throw
      }
      else {
        Write-Host -ForegroundColor Green "✅ RBAC Bicep file built: $outFile"

        $customRBACDocsFolder = Join-Path $RootPath 'docs\wiki\RBAC'
        if (-not (Test-Path -Path $customRBACDocsFolder)) {
          New-Directory -Path $customRBACDocsFolder | Out-Null
        }

        $psDocsCustomRBACFile = (Join-Path $RootPath '.ps-docs\rbac.ps1')
        $fileNameCalc = ("RBAC_" + $rbacBicepFile.BaseName)
        $out = Invoke-PSDocument -Path $psDocsCustomRBACFile -InputObject @($outFile, $roles) -InstanceName $fileNameCalc -OutputPath $customRBACDocsFolder

        if ($out) {
          Write-Host -ForegroundColor Cyan "📃  $(($out.FullName).Replace($RootPath,'')) - Script documentation created."
          if ($GitHub) {
            $allContentToAdd += "`n## Azure Role-Based Access Control (RBAC)`n"
            $allContentToAdd += "`n- [Role Based Access Controls (RBAC)]($($out.BaseName))`n"
          }
        }
        else {
          Write-Host -ForegroundColor Red "❌  $($rbacBicepFile.Name) - Script documentation creation failed."
        }
      }
    }
    else {
      Write-Host -ForegroundColor Yellow "⚠️ RBAC Bicep file not found: $rbacBicepFile"
    }
  }

  if ($null -ne $PIMBicepParameterFile) {
    $pimBicepFile = (Join-Path $RootPath $PIMBicepParameterFile)
    if (Test-Path -Path $pimBicepFile) {
      Write-Host "`r`nBuilding PIM Bicep file: $($pimBicepFile)"
      $pimBicepFile = Get-Item -Path $pimBicepFile
      $outFile = Join-Path $pimBicepFile.DirectoryName "temp/$($pimBicepFile.BaseName).json"
      bicep build-params ($pimBicepFile.FullName) --outfile $outFile 2>$null | Out-Null
      if ($LASTEXITCODE -ne 0) {
        Write-Host -ForegroundColor Red "❌ PIM Bicep file invalid.`r`n"
        throw
      }
      else {
        Write-Host -ForegroundColor Green "✅ PIM Bicep file built: $outFile"

        $customPIMDocsFolder = Join-Path $RootPath 'docs\wiki\PIM'
        if (-not (Test-Path -Path $customPIMDocsFolder)) {
          New-Directory -Path $customPIMDocsFolder | Out-Null
        }

        $psDocsCustomPIMFile = (Join-Path $RootPath '.ps-docs\pim.ps1')
        $fileNameCalc = ("PIM_" + $pimBicepFile.BaseName)
        $out = Invoke-PSDocument -Path $psDocsCustomPIMFile -InputObject @($outFile, $roles) -InstanceName $fileNameCalc -OutputPath $customPIMDocsFolder

        if ($out) {
          Write-Host -ForegroundColor Cyan "📃  $(($out.FullName).Replace($RootPath,'')) - PIM documentation created."
          if ($GitHub) {
            $allContentToAdd += "`n## Azure Privileged Identity Management (PIM)`n"
            $allContentToAdd += "`n- [Privileged Identity Management (PIM)]($($out.BaseName))`n"
          }
        }
        else {
          Write-Host -ForegroundColor Red "❌  $($pimBicepFile.Name) - PIM documentation creation failed."
        }
      }
    }
    else {
      Write-Host -ForegroundColor Yellow "⚠️ PIM Bicep file not found: $pimBicepFile"
    }
  }

  if ($null -ne $BicepDirectoryPaths) {
    # Hardcoded variable to speed up script when debugging. Always should be set to true to build the latest Bicep files.
    $buildBicep = $true
    if ($SkipBicepBuild.IsPresent) {
      $buildBicep = $false
    }

    $bicepFilePaths = $BicepDirectoryPaths | ForEach-Object { (Join-Path $RootPath $_) }
    $bicepFiles = $bicepFilePaths | ForEach-Object { Get-ChildItem ($_) -File -Filter *.bicep -Recurse }
    $bicepDirectories = ($bicepFiles | Select-Object -Unique DirectoryName).DirectoryName
    $bicepDirectoriesHash = $bicepDirectories | ForEach-Object {
      @{
        $_ = @{
          build = Join-Path $_ 'temp'
          docs  = Join-Path $RootPath "docs/wiki/Bicep" ($_).Replace((Join-Path $RootPath "src").ToString(), "")
        }
      }
    }

    # Paths and Locations
    $allDirectories = $bicepDirectoriesHash.Values.Values
    foreach ($directory in $allDirectories) {
      New-Directory -Path $directory
    }

    if ($buildBicep) {
      $fileCount = $bicepFiles.Count
      Write-Host -ForegroundColor Cyan ("`r`n🔍 Building {0} Bicep file{1} into ARM templates for documentation generation." -f $fileCount, $(if ($fileCount -eq 1) { "" } else { "s" }))
      if ($fileCount -gt 0) {
        Write-Host "This may take a few moments depending on the number and complexity of Bicep files."
        Write-Host "Validating and compiling Bicep files to ensure they are current, accurate, and error-free for documentation and deployment purposes.`r`n"
      }
      else {
        Write-Host -ForegroundColor Yellow "⚠️ No Bicep files found to build."
      }
      foreach ($bicepFile in $bicepFiles) {
        # Create ARM templates for PSRule to read with correct parameters
        $outFile = Join-Path $bicepFile.DirectoryName "temp/$($bicepFile.BaseName).json"
        bicep build ($bicepFile.FullName) --outfile $outFile 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
          Write-Host -ForegroundColor Red "❌ $($bicepFile.FullName) invalid.`r`n"
          throw
        }
        else {
          $ARM = Get-Content $outFile | ConvertFrom-Json -Depth 100
          $newMetadata = @{}

          $existingMetadata = $ARM.PSObject.Properties["metadata"]
          if ($existingMetadata) {
            $newMetadata += $existingMetadata.Value | ConvertTo-Json | ConvertFrom-Json -AsHashtable
          }
          else {
            Write-Host "-- Autogenerating metadata into ARM Template for documentation support"
            $newMetadata += @{
              name        = $bicepFile.BaseName
              description = "(Autogenerated) Creates and sets up the $($bicepFile.BaseName) resource."
            }

          }
          $ARM.metadata = $newMetadata
          Set-Content -Value (ConvertTo-Json $ARM -Depth 100) -Path $outFile

          Write-Host -ForegroundColor Green "✅ $($bicepFile.FullName) successfully built into ARM template."
        }
      }
    }

    else {
      Write-Host -ForegroundColor Cyan "`r`n🔍 Using existing Bicep files for documentation generation."
    }
    foreach ($directory in $bicepDirectoriesHash) {
      Get-AzDocTemplateFile -Path $directory.Values.build | ForEach-Object {
        $template = Get-Item -Path $_.TemplateFile;
        $templateName = $template.BaseName
        $out = Invoke-PSDocument -Option $psDocsFile -Module PSDocs.Azure -InputObject $template -InstanceName $templateName -OutputPath $directory.Values.docs
        if ($out) {
          Write-Host -ForegroundColor Cyan "📃 $(($out.FullName).Replace($RootPath,'')) - Bicep file documentation created."
        }
        else {
          Write-Host -ForegroundColor Red "❌ $($template.Name) - Bicep file documentation creation failed."
        }
      }
    }
  }

  if ($null -ne $PSRuleDirectoryPaths) {
    $psRulesCustomRulesFolder = $PSRuleDirectoryPaths | ForEach-Object { (Join-Path $RootPath $_) }
    $psRulesCustomRules = $psRulesCustomRulesFolder | ForEach-Object { Get-ChildItem ($_) -File -Filter *.yaml }
    $psRuleCustomRulesDocsFolder = Join-Path $RootPath 'docs\wiki\PS-Rule'

    # Paths and Locations
    $allDirectories = $psRuleCustomRulesDocsFolder
    foreach ($directory in $allDirectories) {
      New-Directory -Path $directory
    }

    $psDocsCustomPSRuleFile = (Join-Path $RootPath '.ps-docs\ps-rule.ps1')
    foreach ($file in $psRulesCustomRules) {
      $template = $file;
      $templateName = $file.BaseName
      $out = Invoke-PSDocument -Path $psDocsCustomPSRuleFile -InputObject $file -InstanceName $templateName -OutputPath $psRuleCustomRulesDocsFolder
      if ($out) {
        Write-Host -ForegroundColor Cyan "📃 $(($out.FullName).Replace($RootPath,'')) - PS Rule documentation created."
      }
      else {
        Write-Host -ForegroundColor Red "❌ $($template.Name) - PS Rule documentation creation failed."
      }
    }
  }

  if ($null -ne $ScriptsDirectoryPaths) {
    $scriptsCustomRulesFolder = $ScriptsDirectoryPaths | ForEach-Object { (Join-Path $RootPath $_) }
    $scriptsCustomRules = $scriptsCustomRulesFolder | ForEach-Object { Get-ChildItem ($_) -File -Filter *.ps1 }
    $scriptsCustomRulesDocsFolder = Join-Path $RootPath 'docs\wiki\Scripts'

    # Paths and Locations
    $allDirectories = $scriptsCustomRulesDocsFolder
    foreach ($directory in $allDirectories) {
      New-Directory -Path $directory
    }

    $psDocsCustomScriptsFile = (Join-Path $RootPath '.ps-docs\scripts.ps1')
    foreach ($file in $scriptsCustomRules) {
      $template = $file;
      $templateName = $file.BaseName

      # Get-Help Test before invoking the PSDocs
      $help = Get-Help $file.FullName
      if ($help.PSObject.Properties.Name -contains 'xmlns:dev') {
        $out = Invoke-PSDocument -Path $psDocsCustomScriptsFile -InputObject $file -InstanceName $templateName -OutputPath $scriptsCustomRulesDocsFolder
        if ($out) {
          Write-Host -ForegroundColor Cyan "📃  $(($out.FullName).Replace($RootPath,'')) - Script documentation created."
        }
        else {
          Write-Host -ForegroundColor Red "❌  $($template.Name) - Script documentation creation failed."
        }
      }
      else {
        Write-Host -ForegroundColor Yellow "⚠️  $($template.Name) - Script Command Help format is invalid. See https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_comment_based_help?#comment-based-help-keywords"
      }
    }
  }

  if ($null -ne $PricingCSVFilePaths) {
    $pricingFolder = $PricingCSVFilePaths | ForEach-Object { (Join-Path $RootPath $_) }
    $pricings = $pricingFolder | ForEach-Object { Get-ChildItem ($_) -File -Filter *.csv }
    $pricingDocsFolder = Join-Path $RootPath 'docs\wiki\Pricing'
    $pricingPSDocsFile = (Join-Path $RootPath '.ps-docs\pricing.ps1')
    $fileName = 'AzurePricing'

    # Group files by the part of the filename before the first underscore
    $groupedFiles = $pricings | Group-Object { $_.Name.Split('_')[0] }

    if ($GitHub -and $groupedFiles.Count -gt 0) {
      $allContentToAdd += "`n## Azure Pricing`n"
    }

    $groupedFiles | ForEach-Object {
      $fileNameCalc = ("Pricing_" + $_.Name + "_" + $fileName)
      $out = Invoke-PSDocument -Path $pricingPSDocsFile -InputObject $_.Group -InstanceName $fileNameCalc -OutputPath $pricingDocsFolder
      if ($out) {
        Write-Host -ForegroundColor Cyan "📃 $(($out.FullName).Replace($RootPath,'')) - Pricing documentation created."
        if ($GitHub) {
          $allContentToAdd += "`n- [Azure Pricing ($($_.Name))]($($out.BaseName))"
        }
      }
      else {
        Write-Host -ForegroundColor Red "❌ $fileNameCalc.md - Pricing documentation creation failed."
      }
    }

    if ($GitHub -and $groupedFiles.Count -gt 0) {
      $allContentToAdd += "`n"
    }
  }

  # Update GitHub sidebar once at the end
  if ($GitHub -and $allContentToAdd) {
    $sidebar = (Join-Path $RootPath 'docs\wiki\_Sidebar.md')
    $content = Get-Content $sidebar -Raw

    # Strip everything from '# Automated Documentation' down
    $marker = "# Automated Documentation"
    $lines = $content -split "`n"
    $index = [Array]::FindIndex($lines, [Predicate[string]] { $args[0] -match "^$([regex]::Escape($marker))$" })

    if ($index -ge 0) {
      $lines = $lines[0..$index]
    }

    # Append the new auto-generated documentation content
    $lines += ""
    $lines += $allContentToAdd.Trim() -split "`n"
    $content = $lines -join "`n"

    Set-Content -Path $sidebar -Value $content
    Write-Host -ForegroundColor Cyan "📃  $($sidebar.Replace($RootPath,'')) - Sidebar updated."
  }

}
catch {
  Write-Exception $_
  throw
}
