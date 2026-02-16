function Set-DocumentationLocally (
  [Parameter(Mandatory = $true)]
  [string] $MetadataFile
) {
  # Get Metadata
  Write-Host "📑 Metadata file: $MetadataFile"

  $metadata = Get-Content -Raw -Path $MetadataFile | ConvertFrom-Json
  $metadataFolder = $MetadataFile | Split-Path -Parent

  $json = (Get-Content $MetadataFile -Raw)
  $json = $json -replace '//.*', ''
  if (Test-Json -Json $json -Schema (Get-Content (Join-Path $metadataFolder "config.schema.json") -Raw)) {
    Write-Host "✅ Metadata config file is valid."
  }
  else {
    throw "Metadata config file is not valid. Please ensure the metadata file is in the correct format."
  }

  # Check if local deployment
  $localConfigFile = ".local\config\deploy-local.private.jsonc"
  if (Test-Path $localConfigFile) {
    $isLocalDeployment = $false
    $localConfig = Get-Content $localConfigFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($localConfig.Me) {
      Write-Host "✅ Local dev config file found. Using local author name."
      $localConfigPath = Join-Path $metadataFolder "config.private.jsonc"
      $MetadataFile = $localConfigPath
      foreach ($documentToCreate in $metadata.WordDocumentation) {
        $documentToCreate.author = $localConfig.Me.Name
      }
      $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $localConfigPath -Force
    }
  }
  else {
    $isLocalDeployment = $false
  }

  return $isLocalDeployment, $metadata, $metadataFolder
}

Export-ModuleMember -Function * -Verbose:$false
