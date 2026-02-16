<#
.SYNOPSIS
PowerShell module for Git operations used by sync scripts.

.DESCRIPTION
Provides functions for common Git operations including repository validation, file tracking, branching, and staging.

#>

# Define colors for output
$script:colors = @{
    'Success' = @{ ForegroundColor = 'Green' }
    'Warning' = @{ ForegroundColor = 'Yellow' }
    'Error'   = @{ ForegroundColor = 'Red' }
    'Info'    = @{ ForegroundColor = 'Cyan' }
}

function Write-Log {
    <#
    .SYNOPSIS
    Writes a formatted log message with timestamp and color coding.

    .PARAMETER Message
    The message to write.

    .PARAMETER Level
    The log level: Success, Warning, Error, or Info.
    #>
    param(
        [string]$Message,
        [ValidateSet('Success', 'Warning', 'Error', 'Info')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] " -NoNewline
    $colorParams = $script:colors[$Level]
    Write-Host $Message @colorParams
}

function Test-GitInstalled {
    <#
    .SYNOPSIS
    Tests if git is installed and available in PATH.

    .OUTPUTS
    [bool] True if git is installed and available, false otherwise.
    #>
    try {
        $gitVersion = git --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitVersion) {
            Write-Log "Git is installed: $gitVersion" -Level 'Success'
            return $true
        }
        Write-Log "Git not found or not in PATH" -Level 'Error'
        return $false
    }
    catch {
        Write-Log "Error checking git installation: $_" -Level 'Error'
        return $false
    }
}

function Test-RepositoryExists {
    <#
    .SYNOPSIS
    Tests if a directory is a valid git repository.

    .PARAMETER RepoPath
    The path to test.

    .OUTPUTS
    [bool] True if valid git repository, false otherwise.
    #>
    param([string]$RepoPath)

    if (-not (Test-Path -Path $RepoPath -PathType Container)) {
        Write-Log "Repository not found: $RepoPath" -Level 'Error'
        return $false
    }

    if (-not (Test-Path -Path "$RepoPath\.git" -PathType Container)) {
        Write-Log "Not a git repository: $RepoPath" -Level 'Error'
        return $false
    }

    return $true
}

function Get-ChangedFiles {
    <#
    .SYNOPSIS
    Gets the list of files changed between two branches.

    .PARAMETER RepoPath
    The repository path.

    .PARAMETER SourceBranch
    The source branch.

    .PARAMETER BaseBranch
    The base branch to compare against.

    .OUTPUTS
    [string[]] Array of changed file paths.
    #>
    param(
        [string]$RepoPath,
        [string]$SourceBranch,
        [string]$BaseBranch
    )

    Write-Log "Getting changed files from $RepoPath" -Level 'Info'

    try {
        Push-Location -Path $RepoPath
        $files = @(git diff --name-only "$BaseBranch..$SourceBranch" 2>$null)
        Pop-Location

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to get changed files. Ensure branches exist." -Level 'Warning'
            return @()
        }

        return $files
    }
    catch {
        Write-Log "Error getting changed files: $_" -Level 'Error'
        return @()
    }
}

function Initialize-TargetRepo {
    <#
    .SYNOPSIS
    Initializes a target repository by fetching latest changes and checking out the base branch.

    .PARAMETER RepoPath
    The repository path.

    .PARAMETER BaseBranch
    The base branch to checkout.

    .OUTPUTS
    [bool] True on success, false on failure.
    #>
    param(
        [string]$RepoPath,
        [string]$BaseBranch
    )

    Write-Log "Initializing repository: $RepoPath" -Level 'Info'

    try {
        Push-Location -Path $RepoPath

        # Fetch latest changes
        Write-Log "Fetching latest changes..." -Level 'Info'
        git fetch origin 2>&1 | Out-Null

        # Checkout main branch
        Write-Log "Checking out $BaseBranch branch..." -Level 'Info'
        git checkout $BaseBranch 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to checkout $BaseBranch" -Level 'Error'
            Pop-Location
            return $false
        }

        # Pull latest changes
        Write-Log "Pulling latest changes..." -Level 'Info'
        git pull origin $BaseBranch 2>&1 | Out-Null

        Pop-Location
        return $true
    }
    catch {
        Write-Log "Error initializing repository: $_" -Level 'Error'
        Pop-Location
        return $false
    }
}

function New-FeatureBranch {
    <#
    .SYNOPSIS
    Creates a new feature branch or checks out existing one.

    .PARAMETER RepoPath
    The repository path.

    .PARAMETER BranchName
    The name of the feature branch.

    .OUTPUTS
    [bool] True on success, false on failure.
    #>
    param(
        [string]$RepoPath,
        [string]$BranchName
    )

    Write-Log "Creating feature branch: $BranchName" -Level 'Info'

    try {
        Push-Location -Path $RepoPath

        # Check if branch already exists
        $branchExists = git branch -a | Select-String $BranchName | Measure-Object | Select-Object -ExpandProperty Count
        if ($branchExists -gt 0) {
            Write-Log "Branch $BranchName already exists, checking out..." -Level 'Warning'
            git checkout $BranchName 2>&1 | Out-Null
        }
        else {
            git checkout -b $BranchName 2>&1 | Out-Null
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to create/checkout branch" -Level 'Error'
            Pop-Location
            return $false
        }

        Write-Log "Successfully created/checked out $BranchName" -Level 'Success'
        Pop-Location
        return $true
    }
    catch {
        Write-Log "Error creating feature branch: $_" -Level 'Error'
        Pop-Location
        return $false
    }
}

function Invoke-GitStaging {
    <#
    .SYNOPSIS
    Stages all changes in a repository.

    .PARAMETER RepoPath
    The repository path.

    .OUTPUTS
    [bool] True on success, false on failure.
    #>
    param([string]$RepoPath)

    Write-Log "Staging changes in repository..." -Level 'Info'

    try {
        Push-Location -Path $RepoPath

        git add -A 2>&1 | Out-Null

        # Get status
        $status = git status --porcelain
        if ($status) {
            Write-Log "Changes staged:" -Level 'Success'
            Write-Host $status
        }
        else {
            Write-Log "No changes to stage" -Level 'Warning'
        }

        Pop-Location
        return $true
    }
    catch {
        Write-Log "Error staging changes: $_" -Level 'Error'
        Pop-Location
        return $false
    }
}

function Invoke-GitCommit {
    <#
    .SYNOPSIS
    Commits staged changes with a provided message.

    .PARAMETER RepoPath
    The repository path.

    .PARAMETER Message
    The commit message.

    .OUTPUTS
    [bool] True on success, false on failure.
    #>
    param(
        [string]$RepoPath,
        [string]$Message
    )

    Write-Log "Committing changes: $Message" -Level 'Info'

    try {
        Push-Location -Path $RepoPath

        git commit -m $Message 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to commit changes" -Level 'Error'
            Pop-Location
            return $false
        }

        Write-Log "Successfully committed changes" -Level 'Success'
        Pop-Location
        return $true
    }
    catch {
        Write-Log "Error committing changes: $_" -Level 'Error'
        Pop-Location
        return $false
    }
}

function Push-FeatureBranch {
    <#
    .SYNOPSIS
    Pushes a feature branch to remote.

    .PARAMETER RepoPath
    The repository path.

    .PARAMETER BranchName
    The name of the branch to push.

    .OUTPUTS
    [bool] True on success, false on failure.
    #>
    param(
        [string]$RepoPath,
        [string]$BranchName
    )

    Write-Log "Pushing feature branch: $BranchName" -Level 'Info'

    try {
        Push-Location -Path $RepoPath

        git push origin $BranchName 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to push branch" -Level 'Error'
            Pop-Location
            return $false
        }

        Write-Log "Successfully pushed $BranchName to remote" -Level 'Success'
        Pop-Location
        return $true
    }
    catch {
        Write-Log "Error pushing branch: $_" -Level 'Error'
        Pop-Location
        return $false
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Write-Log',
    'Test-GitInstalled',
    'Test-RepositoryExists',
    'Get-ChangedFiles',
    'Initialize-TargetRepo',
    'New-FeatureBranch',
    'Invoke-GitStaging',
    'Invoke-GitCommit',
    'Push-FeatureBranch'
)
