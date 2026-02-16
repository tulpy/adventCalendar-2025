Document Pricing {

  Title "Azure Pricing ($($InputObject[0].Name.Split('_')[0]))"

  "The following is an indicative representation of the Azure Pricing for this solution if deployed."

  "These prices have been generated automatically using the Bicep templates in this repository."

  $location = (Import-Csv $InputObject[0])[0].location
  $azurelocation = (Import-Csv $InputObject[0])[0].ArmRegionName
  $currencyCode = (Import-Csv $InputObject[0])[0].currencyCode


  $note = @'
  > Note:
  > All prices are based off Azure Region, [[location]] ([[azurelocation]]) at [retail pricing](https://learn.microsoft.com/rest/api/cost-management/retail-prices/azure-retail-prices). Your organisations prices may be different based on subscription sku and other discounts.
'@
  $note.Replace("[[location]]", $location).Replace("[[azurelocation]]", $azurelocation)

  Section "Total cost" {

    "The total cost to run this solution is the following:"

    [decimal]$totalSumHour = 0.00
    [decimal]$totalSumDaily = 0.00
    [decimal]$totalSumMonthly = 0.00
    [decimal]$totalSumYearly = 0.00
    foreach ($file in $InputObject) {
      $CSV = Import-Csv $file
      $totalSumHour += ($CSV | Measure-Object -Sum HourlyCost).Sum
      $totalSumDaily += ($CSV | Measure-Object -Sum DailyCost).Sum
      $totalSumMonthly += ($CSV | Measure-Object -Sum MonthlyCost).Sum
      $totalSumYearly += ($CSV | Measure-Object -Sum YearlyCost).Sum
    }
    $hashObject = [PSCustomObject]@{
      'Hourly'  = "$totalSumHour $currencyCode"
      'Daily'   = "$totalSumDaily $currencyCode"
      'Monthly' = "$totalSumMonthly $currencyCode"
      'Yearly'  = "$totalSumYearly $currencyCode"
    }
    $hashObject | Table

    Section "Currency" {
      "All prices are in [$currencyCode](https://www.iso.org/iso-4217-currency-codes.html) and are subject to Microsoft's retail pricing schedule."
    }
    
  }

  Section "Azure Resources" {
    "The following provides a breakdown per each Azure resource discovered in the automation process."

    foreach ($file in $InputObject) {
      $CSV = Import-Csv $file
      $product = $CSV[0].productName
      $serviceFamily = $CSV[0].serviceFamily
      $label = $CSV[0].Label
      Section ($product + ' (' + $serviceFamily + ')') {
        if ($label) {
          "> **Note**: $label" 
        }
        $CSV | Where-Object { $_.HourlyCost } | Table -Property serviceName, type, meterName, @{Name = "Hourly ($currencyCode)"; Expression = { $_.HourlyCost } }, @{Name = "Price ($currencyCode)"; Expression = { $_.DailyCost } }, @{Name = "Monthly ($currencyCode)"; Expression = { $_.MonthlyCost } }, @{Name = "Yearly ($currencyCode)"; Expression = { $_.YearlyCost } } }
      if ($CSV | Where-Object { -not $_.HourlyCost }) {
        Section "Additional pricing on $product" {
          "The following prices are associated with the $product service but not are not a deployment cost. I.e. These may be tiering charges for ingress/egress traffic that needs to be considered in your solutions usage."
          $CSV | Where-Object { -not $_.HourlyCost } | Sort-Object { [int]$_.tierMinimumUnits } | Table -Property type, meterName, @{Name = "Price ($currencyCode)"; Expression = { $_.unitPrice } }, @{Name = "Tiering"; Expression = { if ($_.Tiering) { $_.Tiering } else { '_NA_' } } }
        }
      }
    }
  }

  Section "Further Additional Charges" {
    "Further additional charges to this solution such as data ingress/egress and other Azure resources may not be captured in this file. Please review your Azure Portal and Azure Budgets for final pricing."
  }

}
