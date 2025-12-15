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
    }
    elseif ($BicepParams -is [string]) {
        $BicepParams = @($BicepParams)
    }
  
    # Add explicitly provided bicep params (convert relative paths to absolute)
    foreach ($param in $BicepParams) {
        if ([System.IO.Path]::IsPathRooted($param)) {
            $allBicepParams += $param
        }
        else {
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
    }
    else {
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

        # Create a test case for this file if it contains budget configuration
        $fileTestCase = @{
            FileName                 = Split-Path -Leaf $BicepParam
            FileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($BicepParam)
            FilePath                 = $BicepParam
            SubscriptionId           = $parameterData.parameters.subscriptionId.value
            BudgetTestCases          = @()
        }

        # Look for budget configurations in various parameter structures
        $budgetConfigurations = @()
    
        # Check for direct budget parameter
        if ($parameterData.parameters.PSObject.Properties.Name -contains 'budgets') {
            $budgets = $parameterData.parameters.budgets.value
            if ($null -ne $budgets) {
                if ($budgets -is [array]) {
                    $budgetConfigurations += $budgets
                }
                else {
                    $budgetConfigurations += @($budgets)
                }
            }
        }
    
        # Check for budget within budgetConfiguration parameter
        if ($parameterData.parameters.PSObject.Properties.Name -contains 'budgetConfiguration') {
            $budgetConfig = $parameterData.parameters.budgetConfiguration.value
            if ($null -ne $budgetConfig -and $budgetConfig.PSObject.Properties.Name -contains 'budgets') {
                $budgets = $budgetConfig.budgets
                if ($null -ne $budgets) {
                    if ($budgets -is [array]) {
                        $budgetConfigurations += $budgets
                    }
                    else {
                        $budgetConfigurations += @($budgets)
                    }
                }
            }
        }
    
        # Check for budget within subscription configuration
        if ($parameterData.parameters.PSObject.Properties.Name -contains 'subscriptionConfiguration') {
            $subConfig = $parameterData.parameters.subscriptionConfiguration.value
            if ($null -ne $subConfig -and $subConfig.PSObject.Properties.Name -contains 'budgets') {
                $budgets = $subConfig.budgets
                if ($null -ne $budgets) {
                    if ($budgets -is [array]) {
                        $budgetConfigurations += $budgets
                    }
                    else {
                        $budgetConfigurations += @($budgets)
                    }
                }
            }
        }

        # Build test cases for all found budgets
        foreach ($budget in $budgetConfigurations) {
            if ($null -ne $budget) {
                # Safely extract notification configurations
                $notifications = @()
                if ($budget.PSObject.Properties.Name -contains 'notifications') {
                    if ($budget.notifications -is [array]) {
                        $notifications = $budget.notifications
                    }
                    else {
                        $notifications = @($budget.notifications)
                    }
                }
                
                # Also check for 'alerts' property as alternative to notifications
                if ($notifications.Count -eq 0 -and $budget.PSObject.Properties.Name -contains 'alerts') {
                    if ($budget.alerts -is [array]) {
                        $notifications = $budget.alerts
                    }
                    else {
                        $notifications = @($budget.alerts)
                    }
                }
        
                # Extract threshold values from notifications
                $thresholds = @()
                foreach ($notification in $notifications) {
                    if ($null -ne $notification) {
                        # Check for threshold property
                        if ($notification.PSObject.Properties.Name -contains 'threshold') {
                            $thresholds += $notification.threshold
                        }
                        # Check for thresholdValue property as alternative
                        elseif ($notification.PSObject.Properties.Name -contains 'thresholdValue') {
                            $thresholds += $notification.thresholdValue
                        }
                        # Check for percentage property as alternative
                        elseif ($notification.PSObject.Properties.Name -contains 'percentage') {
                            $thresholds += $notification.percentage
                        }
                    }
                }
                
                # Also check for direct threshold properties on the budget itself
                if ($thresholds.Count -eq 0) {
                    if ($budget.PSObject.Properties.Name -contains 'threshold') {
                        if ($budget.threshold -is [array]) {
                            $thresholds += $budget.threshold
                        } else {
                            $thresholds += @($budget.threshold)
                        }
                    }
                    elseif ($budget.PSObject.Properties.Name -contains 'thresholds') {
                        if ($budget.thresholds -is [array]) {
                            $thresholds += $budget.thresholds
                        } else {
                            $thresholds += @($budget.thresholds)
                        }
                    }
                }
        
                # Extract contact emails from notifications
                $contactEmails = @()
                foreach ($notification in $notifications) {
                    if ($null -ne $notification) {
                        # Check for contactEmails property
                        if ($notification.PSObject.Properties.Name -contains 'contactEmails') {
                            if ($notification.contactEmails -is [array]) {
                                $contactEmails += $notification.contactEmails
                            }
                            else {
                                $contactEmails += @($notification.contactEmails)
                            }
                        }
                        # Check for emails property as alternative
                        elseif ($notification.PSObject.Properties.Name -contains 'emails') {
                            if ($notification.emails -is [array]) {
                                $contactEmails += $notification.emails
                            }
                            else {
                                $contactEmails += @($notification.emails)
                            }
                        }
                        # Check for email property as alternative
                        elseif ($notification.PSObject.Properties.Name -contains 'email') {
                            $contactEmails += @($notification.email)
                        }
                    }
                }
                
                # Also check for direct contact email properties on the budget itself
                if ($contactEmails.Count -eq 0) {
                    if ($budget.PSObject.Properties.Name -contains 'contactEmails') {
                        if ($budget.contactEmails -is [array]) {
                            $contactEmails += $budget.contactEmails
                        } else {
                            $contactEmails += @($budget.contactEmails)
                        }
                    }
                    elseif ($budget.PSObject.Properties.Name -contains 'emails') {
                        if ($budget.emails -is [array]) {
                            $contactEmails += $budget.emails
                        } else {
                            $contactEmails += @($budget.emails)
                        }
                    }
                }
                
                # Debug output if no thresholds or emails found
                if ($thresholds.Count -eq 0) {
                    Write-Host "DEBUG: No threshold values found for budget '$($budget.name)'. Available properties: $($budget.PSObject.Properties.Name -join ', ')"
                }
                if ($contactEmails.Count -eq 0) {
                    Write-Host "DEBUG: No contact emails found for budget '$($budget.name)'. Available properties: $($budget.PSObject.Properties.Name -join ', ')"
                }

                $fileTestCase.BudgetTestCases += @{
                    BudgetName          = $budget.PSObject.Properties.Name -contains 'name' ? $budget.name : 'Unknown'
                    BudgetAmount        = $budget.PSObject.Properties.Name -contains 'amount' ? $budget.amount : 0
                    BudgetThresholdType = $budget.PSObject.Properties.Name -contains 'thresholdType' ? $budget.thresholdType : 'Unknown'
                    BudgetCategory      = $budget.PSObject.Properties.Name -contains 'category' ? $budget.category : 'Cost'
                    BudgetTimeGrain     = $budget.PSObject.Properties.Name -contains 'timeGrain' ? $budget.timeGrain : 'Monthly'
                    BudgetStartDate     = $budget.PSObject.Properties.Name -contains 'startDate' ? $budget.startDate : $null
                    BudgetEndDate       = $budget.PSObject.Properties.Name -contains 'endDate' ? $budget.endDate : $null
                    Notifications       = $notifications
                    ThresholdValues     = $thresholds
                    ContactEmails       = $contactEmails
                }
            }
        }

        # Only add file test case if it has budget test cases
        $budgetTestCases = @($fileTestCase.BudgetTestCases)
        if ($budgetTestCases.Count -gt 0) {
            $script:fileTestCases += $fileTestCase
        }
    }

    # Ensure the variable is initialized even if no test cases were found
    if ($null -eq $script:fileTestCases) {
        $script:fileTestCases = @()
    }
}

Describe 'Budget Validation' {
    Context "Subscription: <SubscriptionId> (<FileNameWithoutExtension>)" -ForEach $fileTestCases {
        Context "Budget: <BudgetName>" -ForEach $BudgetTestCases {
            It 'should have a valid budget name' {
                $BudgetName | Should -Not -BeNullOrEmpty -Because "Budget name is null or empty in file '$FileNameWithoutExtension'."
                $BudgetName | Should -Not -Be 'Unknown' -Because "Budget name is not properly defined in file '$FileNameWithoutExtension'."
                $BudgetName.Length | Should -BeGreaterThan 1 -Because "Budget name '$BudgetName' in file '$FileNameWithoutExtension' is too short. Minimum length is 2 characters."
                $BudgetName.Length | Should -BeLessOrEqual 63 -Because "Budget name '$BudgetName' in file '$FileNameWithoutExtension' exceeds maximum length of 63 characters (current: $($BudgetName.Length))."
                $BudgetName | Should -Match '^[a-zA-Z0-9]([a-zA-Z0-9\-\._])*[a-zA-Z0-9]$' -Because "Budget name '$BudgetName' in file '$FileNameWithoutExtension' contains invalid characters. Must start and end with alphanumeric, can contain hyphens, underscores, and periods."
                $BudgetName | Should -Not -Match '\.$' -Because "Budget name '$BudgetName' in file '$FileNameWithoutExtension' cannot end with a period."
                $BudgetName | Should -Not -Match '\-$' -Because "Budget name '$BudgetName' in file '$FileNameWithoutExtension' cannot end with a hyphen."
            }

            It 'should have a valid budget amount' {
                $BudgetAmount | Should -Not -BeNullOrEmpty -Because "Budget amount is null or empty for budget '$BudgetName' in file '$FileNameWithoutExtension'."
                
                # Validate that budget amount is an integer (int or long from JSON deserialization)
                $isInteger = ($BudgetAmount -is [int]) -or ($BudgetAmount -is [long])
                $isInteger | Should -Be $true -Because "Budget amount '$BudgetAmount' for budget '$BudgetName' in file '$FileNameWithoutExtension' should be an integer value."
                
                $BudgetAmount | Should -BeGreaterThan 0 -Because "Budget amount '$BudgetAmount' for budget '$BudgetName' in file '$FileNameWithoutExtension' must be greater than 0."
                $BudgetAmount | Should -BeLessOrEqual 1000000000 -Because "Budget amount '$BudgetAmount' for budget '$BudgetName' in file '$FileNameWithoutExtension' exceeds reasonable maximum of 1 billion."
            }

            It 'should have valid threshold type' {
                $BudgetThresholdType | Should -Not -BeNullOrEmpty -Because "Budget threshold type is null or empty for budget '$BudgetName' in file '$FileNameWithoutExtension'."
                $BudgetThresholdType | Should -Not -Be 'Unknown' -Because "Budget threshold type is not properly defined for budget '$BudgetName' in file '$FileNameWithoutExtension'."
                $BudgetThresholdType | Should -BeIn @('Actual', 'Forecasted') -Because "Budget threshold type '$BudgetThresholdType' for budget '$BudgetName' in file '$FileNameWithoutExtension' must be either 'Actual' or 'Forecasted'."
            }

            It 'should have valid category' {
                $BudgetCategory | Should -BeIn @('Cost', 'Usage') -Because "Budget category '$BudgetCategory' for budget '$BudgetName' in file '$FileNameWithoutExtension' must be either 'Cost' or 'Usage'."
            }

            It 'should have valid time grain' {
                $BudgetTimeGrain | Should -BeIn @('Monthly', 'Quarterly', 'Annually') -Because "Budget time grain '$BudgetTimeGrain' for budget '$BudgetName' in file '$FileNameWithoutExtension' must be Monthly, Quarterly, or Annually."
            }

            It 'should have at least one defined threshold value' {
                # Ensure threshold values is treated as an array
                $thresholds = @()
                if ($null -ne $ThresholdValues) {
                    if ($ThresholdValues -is [array]) {
                        $thresholds = $ThresholdValues
                    }
                    else {
                        $thresholds = @($ThresholdValues)
                    }
                }
        
                $thresholds.Count | Should -BeGreaterThan 0 -Because "Budget '$BudgetName' in file '$FileNameWithoutExtension' must have at least one threshold value defined."
        
                # Validate each threshold value
                foreach ($threshold in $thresholds) {
                    # Validate that threshold is numeric (int, double, decimal, long, or numeric string)
                    $isThresholdNumeric = ($threshold -is [int]) -or ($threshold -is [double]) -or ($threshold -is [decimal]) -or ($threshold -is [long])
                    
                    # Also check if it's a string that can be converted to a number
                    if (-not $isThresholdNumeric -and $threshold -is [string]) {
                        $numericValue = 0.0
                        $isThresholdNumeric = [double]::TryParse($threshold, [ref]$numericValue)
                    }
                    
                    $isThresholdNumeric | Should -Be $true -Because "Threshold value '$threshold' for budget '$BudgetName' in file '$FileNameWithoutExtension' should be numeric."
                    
                    [double]$threshold | Should -BeGreaterThan 0 -Because "Threshold value '$threshold' for budget '$BudgetName' in file '$FileNameWithoutExtension' must be greater than 0."
                    [double]$threshold | Should -BeLessOrEqual 1000 -Because "Threshold value '$threshold' for budget '$BudgetName' in file '$FileNameWithoutExtension' must be 1000 or less (percentage)."
                }
            }

            It 'should have at least one contact email address' {
                # Ensure contact emails is treated as an array
                $emails = @()
                if ($null -ne $ContactEmails) {
                    if ($ContactEmails -is [array]) {
                        $emails = $ContactEmails
                    }
                    else {
                        $emails = @($ContactEmails)
                    }
                }
        
                $emails.Count | Should -BeGreaterThan 0 -Because "Budget '$BudgetName' in file '$FileNameWithoutExtension' must have at least one contact email address defined."
                $emails.Count | Should -BeLessOrEqual 50 -Because "Budget '$BudgetName' in file '$FileNameWithoutExtension' cannot have more than 50 contact email addresses (current: $($emails.Count))."
        
                # Validate each email address
                foreach ($email in $emails) {
                    $email | Should -Not -BeNullOrEmpty -Because "Contact email is null or empty for budget '$BudgetName' in file '$FileNameWithoutExtension'."
                    $email | Should -Match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' -Because "Contact email '$email' for budget '$BudgetName' in file '$FileNameWithoutExtension' is not a valid email address format."
                    $email.Length | Should -BeLessOrEqual 254 -Because "Contact email '$email' for budget '$BudgetName' in file '$FileNameWithoutExtension' exceeds maximum email length of 254 characters."
                }
            }

            It 'should have valid date range if specified' {
                if ($null -ne $BudgetStartDate -and $BudgetStartDate -ne '') {
                    # Validate start date format
                    try {
                        $startDate = [DateTime]::Parse($BudgetStartDate)
                        $startDate | Should -BeOfType [DateTime] -Because "Budget start date '$BudgetStartDate' for budget '$BudgetName' in file '$FileNameWithoutExtension' should be a valid date."
                    }
                    catch {
                        throw "Budget start date '$BudgetStartDate' for budget '$BudgetName' in file '$FileNameWithoutExtension' is not a valid date format."
                    }
                }
        
                if ($null -ne $BudgetEndDate -and $BudgetEndDate -ne '') {
                    # Validate end date format
                    try {
                        $endDate = [DateTime]::Parse($BudgetEndDate)
                        $endDate | Should -BeOfType [DateTime] -Because "Budget end date '$BudgetEndDate' for budget '$BudgetName' in file '$FileNameWithoutExtension' should be a valid date."
            
                        # If both dates are specified, end date should be after start date
                        if ($null -ne $BudgetStartDate -and $BudgetStartDate -ne '') {
                            $startDate = [DateTime]::Parse($BudgetStartDate)
                            $endDate | Should -BeGreaterThan $startDate -Because "Budget end date '$BudgetEndDate' for budget '$BudgetName' in file '$FileNameWithoutExtension' should be after start date '$BudgetStartDate'."
                        }
                    }
                    catch {
                        throw "Budget end date '$BudgetEndDate' for budget '$BudgetName' in file '$FileNameWithoutExtension' is not a valid date format."
                    }
                }
            }

            It 'should have valid notification configuration if present' {
                # Ensure notifications is treated as an array
                $notificationList = @()
                if ($null -ne $Notifications) {
                    if ($Notifications -is [array]) {
                        $notificationList = $Notifications
                    }
                    else {
                        $notificationList = @($Notifications)
                    }
                }
        
                # Notifications are optional, but if present, should not exceed maximum
                if ($notificationList.Count -gt 0) {
                    $notificationList.Count | Should -BeLessOrEqual 5 -Because "Budget '$BudgetName' in file '$FileNameWithoutExtension' cannot have more than 5 notification configurations (current: $($notificationList.Count))."
                    
                    # Validate each notification if they exist
                    foreach ($notification in $notificationList) {
                        if ($null -ne $notification) {
                            # Check if notification has threshold property (flexible property names)
                            $hasThreshold = ($notification.PSObject.Properties.Name -contains 'threshold') -or 
                                          ($notification.PSObject.Properties.Name -contains 'thresholdValue') -or 
                                          ($notification.PSObject.Properties.Name -contains 'percentage')
                            $hasThreshold | Should -Be $true -Because "Notification for budget '$BudgetName' in file '$FileNameWithoutExtension' must have a threshold property (threshold, thresholdValue, or percentage)."
                            
                            # Check if notification has contact email property (flexible property names)  
                            $hasContactEmails = ($notification.PSObject.Properties.Name -contains 'contactEmails') -or 
                                              ($notification.PSObject.Properties.Name -contains 'emails') -or 
                                              ($notification.PSObject.Properties.Name -contains 'email')
                            $hasContactEmails | Should -Be $true -Because "Notification for budget '$BudgetName' in file '$FileNameWithoutExtension' must have a contact email property (contactEmails, emails, or email)."
                
                            # Validate operator if present
                            if ($notification.PSObject.Properties.Name -contains 'operator') {
                                $notification.operator | Should -BeIn @('EqualTo', 'GreaterThan', 'GreaterThanOrEqualTo') -Because "Notification operator for budget '$BudgetName' in file '$FileNameWithoutExtension' must be EqualTo, GreaterThan, or GreaterThanOrEqualTo."
                            }
                        }
                    }
                } else {
                    # No notifications found - this is acceptable as long as threshold values and contact emails are defined elsewhere
                    Write-Host "INFO: Budget '$BudgetName' has no notification configurations. Threshold values and contact emails should be defined at the budget level."
                }
            }

            It 'should follow budget naming conventions' {
                # Check for common Azure budget naming patterns
                if ($BudgetName -notmatch '^(budget|bgt)-') {
                    Write-Host "INFO: Consider using 'budget-' or 'bgt-' prefix for budget '$BudgetName' to follow naming conventions."
                }
        
                # Check for environment or scope indicators
                $environmentIndicators = @('dev', 'test', 'staging', 'prod', 'production', 'shared', 'sandbox')
                $hasEnvironmentIndicator = $false
                foreach ($indicator in $environmentIndicators) {
                    if ($BudgetName -match $indicator) {
                        $hasEnvironmentIndicator = $true
                        break
                    }
                }
        
                if (-not $hasEnvironmentIndicator) {
                    Write-Host "INFO: Consider including environment indicator (dev, test, prod, etc.) in budget name '$BudgetName' for better identification."
                }
        
                # This test always passes but provides guidance
                $true | Should -Be $true -Because "Budget naming convention check completed."
            }
        }
    }
}