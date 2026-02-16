function Get-AzurePricingPerTiering (
  [Parameter(Mandatory = $true)]
  [object[]]$pricingObject
) {
  $pricingTiers = @()

  # Filter out the first tier that has a minimum unit and a unit price
  $filteredDataMeterId = $pricingObject | Where-Object { $_.tierMinimumUnits -ne 0 -and $_.unitPrice -ne 0 } | Sort-Object { [int]$_.tierMinimumUnits } | Select-Object -Property meterId -First 1

  # Filter out now of the tiers based on the meterId
  $filteredData = $pricingObject | Where-Object { $_.meterId -eq $filteredDataMeterId.meterId } | Sort-Object { [int]$_.tierMinimumUnits }

  for ($i = 0; $i -lt $filteredData.Count; $i++) {
    $entry = $filteredData[$i]
    $nextEntry = if ($i -lt $filteredData.Count - 1) { $filteredData[$i + 1] } else { $null }

    $currentTierLimit = [int]$entry.tierMinimumUnits
    $nextTierLimit = if ($nextEntry) { [int]$nextEntry.tierMinimumUnits } else { $null }

    # Determine and format the tier limit based on the unit of measure
    # Extract the unit part from the string using regex and adjust the tier limits based on the unit of measure
    if ($entry.unitOfMeasure -match '\b(\d+(?:/\d+)?)(?:\s*([GMT]?i?B))?\b') {
      $unit = $matches[2]
    }
    else {
      $unit = $null
    }

    if ($currentTierLimit -ne 0) {
      # If the current tier limit is not 0, then it is not the first tier and therefor we need to use the current tier limit
      $formattedCurrentLimit = "{0} $unit" -f $currentTierLimit
    }
    else {
      # If the current tier limit is 0, then it is the first tier and therefor we need the next level to be the limit
      $formattedCurrentLimit = "{0} $unit" -f $nextTierLimit
    }
    $formattedNextLimit = "{0} $unit" -f $nextTierLimit

    $tierLabel = if ($i -eq 0) {
      "First $formattedCurrentLimit"
    }
    elseif ($null -eq $nextTierLimit) {
      "Over $formattedCurrentLimit"
    }
    else {
      "$formattedCurrentLimit to $formattedNextLimit"
    }

    $pricingTiers += [PSCustomObject]@{
      'Tiering'          = $tierLabel
      'unitPrice'        = [decimal]$entry.unitPrice
      'meterId'          = $entry.meterId
      'tierMinimumUnits' = $entry.tierMinimumUnits
    }

  }
  return $pricingTiers
}

function Get-AzurePricingPerUnit(
  [Parameter(Mandatory = $true)]
  [decimal] $price,
  [Parameter(Mandatory = $true)]
  [string] $unitMeasurement,
  [Parameter(Mandatory = $false)]
  [decimal] $tierMinimumUnits

) {
  $regex1 = '^\d+\s*((Second|Hour|Month|Year)s?)?(/\s*(Month|Year|Day|Hour))?$'
  $regex2 = '^\d+\s*(GB|MB|GiB)/?(Month|Day|Hour)?$'
  if ($unitMeasurement -match $regex1) {
    # Extract the number and the base unit from the unit measurement
    $number = [int]($unitMeasurement -replace '\D', '')
    $baseUnit = ($unitMeasurement -replace '^\d+\s*', '') -replace '^\s*/\s*', '' -replace '\s*/.*$', ''

    $secondCost = $null
    $hourlyCost = $null
    $dailyCost = $null
    $monthlyCost = $null
    $yearlyCost = $null

    switch ($baseUnit) {
      'Second' {
        $hourlyCost = $secondCost * 3600
        $dailyCost = $hourlyCost * 24
        $monthlyCost = $dailyCost * 30
        $yearlyCost = $dailyCost * 365
      }
      'Hour' {
        $hourlyCost = $price / $number
        $dailyCost = $hourlyCost * 24
        $monthlyCost = $dailyCost * 30
        $yearlyCost = $dailyCost * 365
      }
      'Month' {
        $monthlyCost = $price / $number
        $dailyCost = $monthlyCost / 30
        $hourlyCost = $dailyCost / 24
        $yearlyCost = $dailyCost * 365
      }
      'Year' {
        $yearlyCost = $price / $number
        $dailyCost = $yearlyCost / 365
        $hourlyCost = $dailyCost / 24
        $monthlyCost = $dailyCost * 30
      }
    }

    return [pscustomobject]@{
      HourlyCost  = $hourlyCost
      DailyCost   = $dailyCost
      MonthlyCost = $monthlyCost
      YearlyCost  = $yearlyCost
    }

  }
  elseif ($unitMeasurement -match $regex2) {
    # Extract the number and the base unit from the unit measurement
    $number = [int]($unitMeasurement -replace '\D', '')
    $baseUnit = ($unitMeasurement -replace '^\d+\s*', '') -replace '/.*$'

    $GBCost = $null
    $MBCost = $null
    $TBCost = $null

    if ($tierMinimumUnits -eq 0) {
      switch ($baseUnit) {
        { $_ -match 'GB' -or $_ -match 'GiB' } {
          $GBCost = $number * $price
          $MBCost = $GBCost / 1024
          $TBCost = $GBCost * 1024
        }
        'MB' {
          $MBCost = $number * $price
          $GBCost = $MBCost * 1024
          $TBCost = $GBCost * 1024
        }
        { $_ -match 'TB' -or $_ -match 'TiB' } {
          $TBCost = $number * $price
          $GBCost = $TBCost / 1024
          $MBCost = $GBCost / 1024
        }

      }
      return [pscustomobject]@{
        GBCost = $GBCost
        MBCost = $MBCost
        TBCost = $TBCost
      }
    }
    else {
      # Tiered pricing so must be calculated in entirety, not per unit
      return $null
    }
  }
  else {
    # Not a measurement of time, so return nothing
    return $null
  }

}

Export-ModuleMember -Function * -Verbose:$false
