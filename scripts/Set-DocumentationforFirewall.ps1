<#
.SYNOPSIS
Generates firewall rule documentation and exports data from Bicep templates to CSV and Markdown files using PSDocs.

.DESCRIPTION
This script processes firewall rules, rule collection groups, and IP groups defined in Bicep templates.
It converts these Bicep files into JSON, extracts relevant data, and exports it to CSV files.
It also generates Markdown documentation for the firewall rules using PSDocs.

.PARAMETER firewallRules
Specifies the path to the file containing firewall rule Bicep definitions.
Default is 'src/modules/azFirewallRules/azFirewallRules.bicep'.

.PARAMETER OutputPath
Specifies the output path where the CSV files and firewall rule documentation will be saved.
Default is 'docs/wiki/Firewall'.

.PARAMETER GitHub
Indicates whether to update _Sidebar.md with the generated policy documentation.

.PARAMETER diagrams
Indicates whether to generate diagrams for the firewall rules.

.EXAMPLE
.\Get-DocumentationforFirewall.ps1

Executes the script using the default paths for firewall rules and the documentation output.

.EXAMPLE
.\Get-DocumentationforFirewall.ps1 -firewallRules 'src/firewall/rules.bicep' -OutputPath 'output/docs'

Executes the script with custom paths for the firewall rules and the documentation output.

.NOTES
Requires PowerShell 7.0.0 or higher.
Requires the module: PSDocs.
Ensure the Bicep files are structured correctly for processing.

.LINK
[About_Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
[About_PSDocs](https://github.com/Microsoft/PSDocs)
#>

[CmdletBinding(SupportsShouldProcess = $true)]
Param (
  [string] $firewallRules = 'src/modules/azFirewallRules/azFirewallRules.bicep',
  [string] $OutputPath = 'docs/wiki/Firewall',
  [switch] $GitHub,
  [switch] $diagrams
)

#Requires -Version 7.0.0
#Requires -module psdocs

Set-StrictMode -Version "Latest"
$ErrorActionPreference = "Stop"

$RootPath = Resolve-Path -Path (Join-Path $PSScriptRoot "..")
Import-Module (Join-Path $PSScriptRoot "functions/utilities.psm1") -Force -Verbose:$false

if ($diagrams) {
  $diagrams = $true
  $pythonPath = Get-Command python -ErrorAction SilentlyContinue
  if (-not $pythonPath) {
    Write-Host -ForegroundColor Red "❌ Python is not installed or not in the system PATH.`r`n"
    Write-Warning "Python is required to generate diagrams. Please install Python, ensure it is in the system PATH and https://diagrams.mingrammer.com/ is installed."
    $diagrams = $false
  }
  else {
    Write-Host -ForegroundColor Green "✅ Python is installed: $($pythonPath.Path)`r`n"
    $diagrams = $true
  }
}

$AllNodes = @{}
function Get-PythonNodeName {
  param(
    [string]$Label
  )

  if ($Label -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}.*$') {
    # IP addresses (string)
    $varName = "ips_" + ($Label -replace '[|*,-./\s]+', '_').Trim()
  }
  else {
    $varName = ($Label -replace '\((.*?)\)', '' -replace '[(\\n|*,-./\s)\]\[]+', '_').Trim()
  }
  return $varName.ToLower()
}

function Get-OrCreatePythonNode {
  param(
    [string]$NodeLabel
  )

  if (-not $AllNodes.ContainsKey($NodeLabel)) {
    # Create a python-safe name
    $nodeName = Get-PythonNodeName -Label $NodeLabel
    $AllNodes[$NodeLabel] = $nodeName
  }
  return $AllNodes[$NodeLabel]
}

# Function to extract the last segment from a path-like string
function Get-LastSegment {
  param (
    [string[]]$paths, # Array of paths to process
    [PSCustomObject]$ipGroupsLookupTable  # Lookup table for ipGroups (optional use)
  )
  if ($paths -like "*/*") {
    # Split the path by '/' and return the last segment as its the resourceId
    return $paths | ForEach-Object { ($_ -split '/')[-1] }
  }
  elseif ($paths -like "*variables*") {
    # If variables is found, we need to return the actual ipGroup name from the variables
    $matchesPaths = ($paths | Select-String -Pattern '\.(\w+)]').Matches
    $matchesPaths
    if ($matchesPaths.Count -eq 0) {
      return $null
    }
    $ipGroups = @()
    foreach ($match in $matchesPaths) {
      $value = $match.Groups[1].Value
      $value
      $ipGroups += ($ipGroupsLookupTable | Where-Object { $_.FriendlyName -eq $value }).GroupName
    }
    return $ipGroups
  }
  else {
    return $paths
  }
}

# Function to process protocols array and join the information in a readable way
function Get-Protocols {
  param ([System.Collections.IEnumerable]$protocols)
  $protocols = $protocols | ForEach-Object { "$($_.protocolType):$($_.port)" }
  return $protocols -join ', '
}

function Get-IpGroupAddress {
  param (
    [object]$ipGroup,
    [object]$ipGroups
  )
  if ([string]::IsNullorEmpty($ipGroup)) {
    return $null
  }

  $ipGroupsReturned = @()
  foreach ($ipGroupToMatch in $ipGroup) {
    $ipGroup = $ipGroups | Where-Object { $_.name -eq $ipGroupToMatch }
    if ($ipGroup -and $ipGroup.PSObject.Properties.Value -contains 'ipAddresses') {
      $ips = $ipGroup.ipAddresses -join ', '
      $ipGroupsReturned += "$ipGroupToMatch ($ips)"
    }
  }
  return $ipGroupsReturned -join ', '
}

function Get-IPGroupsMappingTable {
  param (
    [Parameter(Mandatory = $true)]
    $FirewallObject,
    [Parameter(Mandatory = $true)]
    $IPGroupsArray
  )

  # Access variables from the firewall object
  $variables = $object_Firewall.resources.ruleCollectionGroups.properties.template.variables

  # Initialize an array to store the results
  $mappingResults = @()

  # Loop through each variable ending with '.ipGroups'
  foreach ($key in $variables.Keys) {
    if ($key -match '\w+\.ipGroups') {
      $ipGroupEntries = $variables[$key]

      # Loop through the friendly names within each ipGroups object
      foreach ($entry in $ipGroupEntries.Keys) {
        # Extract the group name from the format string
        $groupNameMatch = ($ipGroupEntries[$entry] -replace ".*\{0}([^']+)',.*", '$1')

        # Find the matching IP group from the IPGroupsArray
        $matchedGroup = $IPGroupsArray | Where-Object { $_.name -eq $groupNameMatch }

        if ($matchedGroup) {
          # Create a custom object with the results
          $mappingResults += [PSCustomObject]@{
            FriendlyName = $entry
            GroupName    = $matchedGroup.name
            IPAddresses  = ($matchedGroup.ipAddresses -join ", ")
          }
        }
      }
    }
  }

  # Output the results as a table
  $mappingResults
}


try {

  Write-Host "📁 Confirming directory $OutputPath exists`r`n"
  New-Directory -Path $OutputPath

  # OutFiles
  $outFile_Firewall = (Split-Path $firewallRules -Leaf).Replace(".bicep", ".csv")
  $outFile_FirewallIpGroups = 'ipGroups.csv'
  $outFile_FirewallCollectionGroups = 'collectionGroups.csv'

  # Firewall PSDocs File
  $firewallPSDocsFile = (Join-Path $RootPath '.ps-docs\firewall.ps1')

  if (Test-Path $firewallRules) {
    $object_Firewall = Build-BicepFiletoJson -File $firewallRules

    $ruleCollectionGroups = $object_Firewall.resources.ruleCollectionGroups.properties.template.resources.GetEnumerator() |  Where-Object { $_.Value.type -eq "Microsoft.Network/firewallPolicies/ruleCollectionGroups" }
    $ruleCollectionGroups_withRules = $ruleCollectionGroups | ForEach-Object {
      $currentGroup = $_.Value
      $nameValue = ($currentGroup['name'] -replace ".*'(.*)'\)", '$1').TrimEnd(']')
      $ruleCollections = $currentGroup['properties']['ruleCollections'] | ForEach-Object {
        ($_ -replace ".*\('(.*)'\)", '$1').TrimEnd(']')
      }
      [PSCustomObject]@{
        DeploymentName  = $_.Key
        Name            = $nameValue
        Priority        = $currentGroup['properties']['priority']
        RuleCollections = $ruleCollections
      }
    }


    $collectionsKeys = $object_Firewall.resources.ruleCollectionGroups.properties.template.variables.keys | Where-Object { $_ -notlike '_*' }

    $ipGroupsHash = $object_Firewall.variables.ipGroupArray

    $ipGroupsLookupTable = Get-IPGroupsMappingTable -FirewallObject $object_Firewall -IPGroupsArray $ipGroupsHash | Select-Object * -Unique

    $firewallRulesClean = @()
    $collectionsClean = @()
    $collectionsKeys | ForEach-Object {

      $collectionName = $_
      $ruleCollectionGroupKey = ($ruleCollectionGroups_withRules | Where-Object { $_.RuleCollections -contains $collectionName }).DeploymentName
      $collectionsClean += [pscustomobject]@{
        ruleCollectionName          = $collectionName
        ruleCollectionPriority      = $object_Firewall.resources.ruleCollectionGroups.properties.template.variables[$_].priority
        ruleCollectionGroup         = ($ruleCollectionGroups_withRules | Where-Object { $_.RuleCollections -contains $collectionName }).Name
        ruleCollectionGroupKey      = $ruleCollectionGroupKey
        ruleCollectionGroupPriority = ($ruleCollectionGroups_withRules | Where-Object { $_.RuleCollections -contains $collectionName }).Priority
      }

      Write-Host "`r`n🔍  Processing Firewall Rules for $collectionName"

      $firewallRulesObj = $object_Firewall.resources.ruleCollectionGroups.properties.template.variables[$_].rules
      if ([string]::IsNullorEmpty($firewallRulesObj) -or $firewallRulesObj.Count -eq 0) {
        Write-Host -ForegroundColor Yellow "⚠️  No firewall rules found for $collectionName."
        return
      }
      else {
        Write-Host "➡️  Found $($firewallRulesObj.Count) firewall rules for $collectionName."
        $firewallRulesClean += $firewallRulesObj | ForEach-Object {
          $rule = [pscustomobject]@{
            ruleCollectionGroup         = ($ruleCollectionGroups_withRules | Where-Object { $_.RuleCollections -contains $collectionName }).Name
            ruleCollectionGroupPriority = ($ruleCollectionGroups_withRules | Where-Object { $_.RuleCollections -contains $collectionName }).Priority
            ruleCollection              = $collectionName
            ruleType                    = $_['ruleType']
            name                        = $_['name']
            description                 = $_['description']
            protocols                   = if ($_.Keys -contains 'protocols') { (Get-Protocols $_['protocols']) } else { '' }
            sourceAddresses             = if ($_.Keys -contains 'sourceAddresses') { $_['sourceAddresses'] -join ', ' } else { '' }
            sourceIpGroups              = (Get-IpGroupAddress -ipGroup (Get-LastSegment $_['sourceIpGroups'] $ipGroupsLookupTable) -ipGroups $ipGroupsHash)
            fqdnTags                    = if ($_.Keys -contains 'fqdnTags') { $_['fqdnTags'] -join ', ' } else { '' }
            destinationAddresses        = if ($_.Keys -contains 'destinationAddresses') { $_['destinationAddresses'] -join ', ' } else { '' }
          }

          $value = if ($_.Keys -contains 'ruleType' -and $_['ruleType'] -eq "ApplicationRule") {
            if ($_.Keys -contains 'targetFqdns' -and $_['targetFqdns'] -like "*concat(*") {
              $object_Firewall.resources.ruleCollectionGroups.properties.template.variables[
              [regex]::match($_['targetFqdns'], "'([^']+)'").Groups[1].Value
              ] -join ', ' +
              [regex]::match($_['targetFqdns'], "'([^']+)'").Groups[2].Value -join ', '
            }
            else {
              $_['targetFqdns'] -join ', '
            }
          }
          else {
            ''
          }
          $rule | Add-Member -MemberType NoteProperty -Name 'targetFqdns' -Value $value

          # Handle webCategories and targetUrls separately
          $webCategories = if ($_.Keys -contains 'webCategories') { $_['webCategories'] -join ', ' } else { '' }
          $rule | Add-Member -MemberType NoteProperty -Name 'webCategories' -Value $webCategories

          $targetUrls = if ($_.Keys -contains 'targetUrls') { $_['targetUrls'] -join ', ' } else { '' }
          $rule | Add-Member -MemberType NoteProperty -Name 'targetUrls' -Value $targetUrls

          # NetworkRule properties
          $ipProtocols = if ($_.Keys -contains 'ipProtocols') { $_['ipProtocols'] -join ', ' } else { '' }
          $rule | Add-Member -MemberType NoteProperty -Name 'ipProtocols' -Value $ipProtocols

          $destinationIpGroups = if ($_.Keys -contains 'destinationIpGroups') { (Get-IpGroupAddress -ipGroup (Get-LastSegment $_['destinationIpGroups'] $ipGroupsLookupTable) -ipGroups $ipGroupsHash) } else { '' }
          $rule | Add-Member -MemberType NoteProperty -Name 'destinationIpGroups' -Value $destinationIpGroups

          $destinationFqdns = if ($_.Keys -contains 'destinationFqdns') { $_['destinationFqdns'] -join ', ' } else { '' }
          $rule | Add-Member -MemberType NoteProperty -Name 'destinationFqdns' -Value $destinationFqdns

          $destinationPorts = if ($_.Keys -contains 'destinationPorts') { $_['destinationPorts'] -join ', ' } else { '' }
          $rule | Add-Member -MemberType NoteProperty -Name 'destinationPorts' -Value $destinationPorts

          $rule
        }
      }
    }


    Write-Host "`r`n📝  Exporting Firewall Rules to CSV"
    $firewallRulesClean | Export-Csv -Path (Join-Path $OutputPath $outFile_Firewall) -NoTypeInformation -Force

    Write-Host "📝  Exporting IP Groups to CSV"
    $exportIPGroup = $ipGroupsHash | Select-Object `
    @{Name = 'name'; Expression = { $_.name } },
    @{Name = 'ipAddresses'; Expression = { ($_.ipAddresses -join ', ') } }
    $exportIPGroup | Export-Csv -Path (Join-Path $OutputPath $outFile_FirewallIpGroups) -NoTypeInformation -Force

    Write-Host "📝  Exporting Collection Groups to CSV"
    $collectionsClean | Export-Csv -Path (Join-Path $OutputPath $outFile_FirewallCollectionGroups) -NoTypeInformation -Force
  }


  Write-Host "`r`n➡️  Generating Firewall Documentation`r`n"
  $fileName = 'Firewall_AzureFirewall'
  $contentToAdd = "`n<!-- START Azure Firewall -->`n`n## Azure Firewall`n"

  $PSDocsCollectionGroup = $collectionsClean | Select-Object -Unique ruleCollectionGroup, ruleCollectionGroupPriority, ruleCollectionGroupKey | Sort-Object -Property ruleCollectionGroupPriority
  $PSDocsCollections = $collectionsClean | Sort-Object -Property ruleCollectionPriority

  if ($diagrams) {
    Write-Host "🔧  Generating Diagrams for Firewall Rules"

    foreach ($group in $PSDocsCollectionGroup) {
      # For each rule collection group,

      Write-Host "`n📈  Compiling diagram for $($group.ruleCollectionGroup)"

      $key = "with Diagram(`"" + $group.ruleCollectionGroup + "`", graph_attr=graph_attr, node_attr=node_attr, show=False, direction=`"TB`"):"
      $pythonLines = New-Object System.Collections.Generic.List[string]
      # 1) Start with the imports and basic diagram definition
      $pythonLines.Add('#! /usr/bin/env python3')
      $pythonLines.Add('from diagrams import Diagram, Edge, Cluster')
      $pythonLines.Add('from diagrams.azure.network import Firewall, Subnets, DNSZones, PublicIpAddresses, ServiceEndpointPolicies')
      $pythonLines.Add('from diagrams.azure.general import Resource, Tags')
      $pythonLines.Add('from diagrams.azure.web import AppServiceDomains')
      $pythonLines.Add('')
      $pythonLines.Add('graph_attr = {')
      $pythonLines.Add('    "splines": "curve",')
      $pythonLines.Add('    "concentrate": "true",')
      $pythonLines.Add('    "rankdir": "TB",')
      $pythonLines.Add('    "ranksep": "2",')
      $pythonLines.Add('    "label": "Automatically generated diagram: ' + (Get-Date).ToString() + '",')
      $pythonLines.Add('    "fontsize": "25",')
      $pythonLines.Add('          }')
      $pythonLines.Add('')
      $pythonLines.Add('node_attr = {')
      $pythonLines.Add('    "fontsize": "15",')
      $pythonLines.Add('    "imagepos": "tc",')
      $pythonLines.Add('    "labelloc": "b",')
      $pythonLines.Add('    "fixedsize": "shape",')
      $pythonLines.Add('          }')
      $pythonLines.Add($key)
      $pythonLines.Add('    afw = Firewall("\n\nAzure Firewall")')
      $pythonLines.Add('')
      $pythonLines.Add('')
      $pythonLines.Add('    with Cluster("' + $group.ruleCollectionGroup + ' - Rule Collection Group",  graph_attr={"bgcolor": "#e0effa", "fontsize": "50", "penwidth": "3", "style": "solid", "labeljust": "c"}):')

      $collections = $firewallRulesClean | Where-Object { $_.ruleCollectionGroup -eq $group.ruleCollectionGroup } | Group-Object ruleCollection
      foreach ($collection in $collections) {

        $pythonLines.Add('')
        $pythonLines.Add('        with Cluster("' + $collection.Name + ' - Rule Collection", graph_attr={"bgcolor": "#f2f8fc", "style": "dashed", "penwidth": "3", "fontsize": "30", "labeljust": "c"}):')

        foreach ($groupCollection in $collection) {
          $rows = $groupCollection.Group

          foreach ($row in $rows) {
            $sourceIconKey = "Subnets" # Default to Subnets
            $destIconKey = "Subnets" # Default to Subnets
            $indent = '            '  # 8 spaces for python indentation

            $sourceLabel = $row.sourceIpGroups
            if ([string]::IsNullOrEmpty($sourceLabel)) {
              $sourceLabel = $row.sourceAddresses
              $sourceIconKey = "PublicIpAddresses"
              if ([string]::IsNullOrEmpty($sourceLabel)) {
                $sourceLabel = "UnknownSource"
                $sourceIconKey = "Resource"
              }
              $isSourceIPGroup = $false
            }
            else {
              # IP Groups, so split into multiple lines to avoid long lines
              $sourceLabel = $sourceLabel.Replace('), ', '), \n') # Split into multiple lines foreach ipGroup
              $isSourceIPGroup = $true
            }

            $isDestIPGroup = $false # Default to false
            if ($row.ruleType -ne "ApplicationRule") {
              # Destination
              $destLabel = $row.destinationIpGroups
              if ([string]::IsNullOrEmpty($destLabel)) {
                $destLabel = $row.destinationAddresses
                if ([string]::IsNullOrEmpty($destLabel)) {
                  $destLabel = $row.destinationFqdns
                  $destIconKey = "DNSZones"
                  if ([string]::IsNullOrEmpty($destLabel)) {
                    $destLabel = "UnknownDestination"
                    $destIconKey = "Resource"
                  }
                }
                else {
                  if ($destLabel -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}.*$') {
                    $destIconKey = "PublicIpAddresses" # IP addresses
                  }
                  else {
                    $destIconKey = "ServiceEndpointPolicies" # Assume ServiceTag
                  }
                }
              }
              else {
                # IP Groups, so split into multiple lines to avoid long lines
                $destLabel = $destLabel.Replace('), ', '), \n') # Split into multiple lines foreach ipGroup
                $isDestIPGroup = $true
              }

              # Ports
              $portsLabel = $row.destinationPorts
              if ([string]::IsNullOrEmpty($portsLabel)) {
                $portsLabel = "*"
              }
              # ipProtocols
              $proto = $row.ipProtocols
              if ([string]::IsNullOrEmpty($proto)) {
                $proto = "*"
              }
              $edgeLabel = "$proto/$portsLabel"
            }
            else {
              $destLabel = ""

              if ($row.fqdnTags) {
                $destLabel += $row.fqdnTags
                $edgeLabelKey = "fqdnTags"
                $destIconKey = "ServiceEndpointPolicies"
              }
              if ($row.targetUrls) {
                if ($destLabel) { $destLabel += ", " }
                $destLabel += $row.targetUrls
                $edgeLabelKey = "URL"
                $destIconKey = "AppServiceDomains"
              }
              if ($row.webCategories) {
                if ($destLabel) { $destLabel += ", " }
                $destLabel += $row.webCategories
                $edgeLabelKey = "Web Category"
                $destIconKey = "Tags"
              }
              if ($row.targetFqdns) {
                if ($destLabel) { $destLabel += ", " }
                $destLabel += $row.targetFqdns
                $edgeLabelKey = "targetFqdns"
                $destIconKey = "DNSZones"
              }
              # Protocol
              $proto = $row.protocols
              $edgeLabel = "$edgeLabelKey/$proto"
            }

            # Create or retrieve a python node name
            $sourceNodeName = Get-OrCreatePythonNode -NodeLabel $sourceLabel
            $destNodeName = Get-OrCreatePythonNode -NodeLabel $destLabel

            if ($sourceLabel.Length -gt 50 -and (-not $isSourceIPGroup)) {
              $sourceLabelClean = $sourceLabel.Substring(0, 50) + "..."
            }
            else {
              $sourceLabelClean = $sourceLabel
            }
            $lines = $sourceLabelClean -split '\\n'
            if ($lines.Count -le 3) {
              $sourceLabelClean = "\n\n" + $sourceLabelClean
            }

            if ($destLabel.Length -gt 50 -and (-not $isDestIPGroup)) {
              if ($destLabel -like '*,*') {
                $destLabelClean = $destLabel.Replace(', ', ',\n')
                if ($destLabelClean.Length -gt 200) {
                  $destLabelClean = $destLabelClean.Substring(0, 200) + "..."
                }
              }
              else {
                $destLabelClean = $destLabel.Substring(0, 50) + "..."
              }
            }
            else {
              $destLabelClean = $destLabel
            }

            $lines = $destLabelClean -split '\\n'
            if ($lines.Count -le 3) {
              $destLabelClean = "\n\n" + $destLabelClean
            }

            # If we haven't declared this node before, let's add a line for it
            $sourceNodeLine = "$($indent)$sourceNodeName = $sourceIconKey(`"$sourceLabelClean`")"
            if (-not ($pythonLines -contains $sourceNodeLine)) {
              $pythonLines.Add($sourceNodeLine)
            }

            $destNodeLine = "$($indent)$destNodeName = $destIconKey(`"$destLabelClean`")"
            if (-not ($pythonLines -contains $destNodeLine)) {
              $pythonLines.Add($destNodeLine)
            }

            # Build the flow line:
            # Example: sourceNode >> Edge(label="TCP/443") >> afw >> Edge(label="Allow") >> destNode
            $pythonLines.Add("$($indent)$sourceNodeName >> Edge(label=`"$edgeLabel`", minlen=`"1`", tailport=`"s`", headport=`"n`") >> $destNodeName")
          }
        }
      }
      $pythonLines.Add('    afw >> Cluster("' + $group.ruleCollectionGroup + '")')
      $fileNameDiagram = (Join-Path $RootPath $OutputPath ($group.ruleCollectionGroup + ".py"))
      $originalFileContent = Get-Content -Path $fileNameDiagram -ErrorAction SilentlyContinue
      if (-not $originalFileContent) {
        $lines = 2 # No original file, so we assume all lines are new
      }
      else {
        $lines = Compare-Object -ReferenceObject $originalFileContent -DifferenceObject $pythonLines -IncludeEqual -PassThru | Where-Object { $_.SideIndicator -eq '=>' }
      }
      if ($lines -gt 1) {
        # "label": "Automatically generated diagram: DATE", will always change, hence why lines > 1
        Set-Content -Path $fileNameDiagram -Value $pythonLines

        # Change to the directory where the diagram will be generated
        $mediaPath = 'docs/wiki/.media'
        Set-Location (Join-Path $RootPath 'docs/wiki/.media')

        # Generate the diagram
        Write-Host "📈  Generating Diagram for $($group.ruleCollectionGroup) from .py file in $($mediaPath)"
        & $pythonPath.Path $fileNameDiagram

        # Change back to the root directory
        Set-Location $RootPath
      }
      else {
        Write-Host -ForegroundColor Yellow "⚠️  No detectable changes from the current diagram for $($group.ruleCollectionGroup). Skipping..."
      }
    }

  }

  $out = Invoke-PSDocument -Path $firewallPSDocsFile -InputObject @($ipGroupsHash, $firewallRulesClean, $PSDocsCollections, $PSDocsCollectionGroup, $diagrams) -InstanceName $fileName -OutputPath $OutputPath
  if ($out) {
    Write-Host -ForegroundColor Cyan "`r`n📃  $(($out.FullName).Replace($RootPath, '')) - Firewall documentation created."
    $contentToAdd += "`n- [Azure Firewall Configuration]($($out.BaseName))"
  }
  else {
    Write-Host -ForegroundColor Red "❌  $($fileName ).md - Firewall documentation creation failed."
  }
  $contentToAdd += "`n`n<!-- END Azure Firewall -->`n"

  if ($GitHub) {
    $sidebar = (Join-Path $RootPath 'docs\wiki\_Sidebar.md')
    $content = Get-Content $sidebar -Raw

    # Define a regex pattern to match the entire block of Azure Firewall links including preceding newlines
    $pattern = "(?ms)\n<!-- START Azure Firewall -->.*?<!-- END Azure Firewall -->"

    # Remove the existing block of links if it exists
    if ($content -match $pattern) {
      $content = $content -replace $pattern, ''
    }

    # Remove multiple preceding newlines before the content
    $content = $content.Trim()

    # Add the new content block
    $content += "`n$($contentToAdd.Trim())`n"

    # Write the updated content back to the file
    Set-Content -Path $sidebar -Value $content
    Write-Host -ForegroundColor Cyan "📃  $($sidebar.Replace($RootPath, '')) - Sidebar updated."
  }

}
catch {
  Write-Exception $_
  throw
}
