<#
.SYNOPSIS
Runs all Pester test files in the 'tests' directory of the project.

.DESCRIPTION
This script locates and executes all PowerShell Pester test files (*.tests.ps1) found recursively under the 'tests' directory relative to the script's location. It ensures the Pester module is installed and imported before running tests. Each test file is executed individually, and detailed output is provided. If no test files are found, the script exits gracefully.

.NOTES
- Requires PowerShell 7.0.0 or later.
- Expects the Pester module to be available.
- Set-StrictMode is enabled for robust error handling.
- Stops execution on errors.

.EXAMPLE
.\Test-AzPester.ps1
Runs all Pester tests in the 'tests' directory.

#>
#Requires -Version 7.0.0

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootPath = Resolve-Path -Path (Join-Path $PSScriptRoot "..")

if (-not (Get-Module -ListAvailable -Name Pester)) {
  Write-Error "The 'Pester' module is not installed. Please install it using 'Install-Module Pester'."
  exit 1
}

if (-not (Get-Module -Name Pester)) {
  Import-Module Pester -ErrorAction Stop
}

$testFiles = Get-ChildItem -Path "$RootPath/tests/" -Filter *.tests.ps1 -Recurse

if (($testFiles | Measure-Object).Count -eq 0) {
  Write-Host "No test files found in '$RootPath/tests/'."
  exit 0
}

$failedTests = 0
foreach ($testFile in $testFiles) {
  Write-Host "Running tests in: $($testFile.FullName)"
  try {
    $result = Invoke-Pester -Path $testFile.FullName -Output Detailed -PassThru
    if ($result.FailedCount -gt 0) {
      $failedTests += $result.FailedCount
      Write-Error "Tests failed in: $($testFile.FullName) - Failed: $($result.FailedCount)"
    }
  }
  catch {
    Write-Host "Tests failed in: $($testFile.FullName)" -ForegroundColor Red
    Write-Host $_ -ForegroundColor Red
    $failedTests++
  }
}

if ($failedTests -gt 0) {
  Write-Error "Total failed tests: $failedTests"
  exit 1
}
