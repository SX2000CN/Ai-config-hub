$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'managed-assets.ps1')

function Resolve-AiConfigHubUserHome {
    param([string]$UserHome)

    $profileHome = [Environment]::GetFolderPath('UserProfile')
    $resolved = if ([string]::IsNullOrWhiteSpace($UserHome)) {
        $profileHome
    }
    elseif ($UserHome -eq '~') {
        $profileHome
    }
    elseif ($UserHome.StartsWith('~\') -or $UserHome.StartsWith('~/')) {
        Join-Path $profileHome $UserHome.Substring(2)
    }
    elseif (-not [System.IO.Path]::IsPathRooted($UserHome)) {
        throw "UserHome must be an absolute path or start with '~': $UserHome"
    }
    else {
        $UserHome
    }

    $fullPath = [System.IO.Path]::GetFullPath($resolved)
    $pathRoot = [System.IO.Path]::GetPathRoot($fullPath)
    if ($fullPath.TrimEnd('\', '/') -eq $pathRoot.TrimEnd('\', '/')) {
        throw "UserHome must not be a drive or filesystem root: $fullPath"
    }

    return $fullPath.TrimEnd('\', '/')
}

function Assert-AiConfigHubPathInside {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Parent,
        [string]$Label = 'Target'
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullParent = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($fullParent, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label path is outside expected parent: $fullPath"
    }

    return $fullPath
}

function Get-AiConfigHubPathFingerprint {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return '<missing>'
    }
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return 'file:' + (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
    }

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $parts = foreach ($entry in Get-ChildItem -LiteralPath $Path -Recurse -Force | Sort-Object FullName) {
        $relative = $entry.FullName.Substring($resolved.Length).TrimStart('\')
        if ($entry.PSIsContainer) {
            "directory`t$relative"
        }
        else {
            $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $entry.FullName).Hash
            "file`t$relative`t$hash"
        }
    }
    $payload = [Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return 'dir:' + ([BitConverter]::ToString($sha.ComputeHash($payload)).Replace('-', ''))
    }
    finally {
        $sha.Dispose()
    }
}

function Assert-AiConfigHubTargetUnchanged {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedFingerprint,
        [string]$Label = 'Target'
    )

    $actual = Get-AiConfigHubPathFingerprint $Path
    if ($actual -ne $ExpectedFingerprint) {
        throw "$Label changed after planning; refusing to overwrite concurrent updates: $Path"
    }
}

function New-AiConfigHubOperationContext {
    param(
        [Parameter(Mandatory = $true)][string]$UserHome,
        [Parameter(Mandatory = $true)][string]$Pipeline,
        [string]$StagingRelativeRoot = '.ai-config-hub\staging',
        [string]$BackupRelativeRoot = '.ai-config-hub\backups'
    )

    $resolvedHome = Resolve-AiConfigHubUserHome $UserHome
    $operationId = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), ([Guid]::NewGuid().ToString('N'))
    $stagingRoot = Join-Path (Join-Path $resolvedHome $StagingRelativeRoot) (Join-Path $Pipeline $operationId)
    $backupRoot = Join-Path (Join-Path $resolvedHome $BackupRelativeRoot) (Join-Path $Pipeline $operationId)

    Assert-AiConfigHubPathInside $stagingRoot $resolvedHome 'Staging root' | Out-Null
    Assert-AiConfigHubPathInside $backupRoot $resolvedHome 'Backup root' | Out-Null
    New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

    return [pscustomobject]@{
        Id = $operationId
        UserHome = $resolvedHome
        Pipeline = $Pipeline
        StagingRoot = $stagingRoot
        BackupRoot = $backupRoot
        Changes = New-Object System.Collections.Generic.List[object]
    }
}

function New-AiConfigHubStagedFile {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $path = Join-Path $Context.StagingRoot $Name
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Set-Content -Encoding UTF8 -LiteralPath $path -Value $Content -NoNewline
    return $path
}

function Copy-AiConfigHubStagedFile {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Source
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Staging source file does not exist: $Source"
    }

    $path = Join-Path $Context.StagingRoot $Name
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $path -Force
    return $path
}

function Copy-AiConfigHubStagedDirectory {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Source
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Staging source directory does not exist: $Source"
    }

    $path = Join-Path $Context.StagingRoot $Name
    Copy-Item -LiteralPath $Source -Destination $path -Recurse -Force
    return $path
}

function Install-AiConfigHubStagedFile {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$StagedPath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [string]$ExpectedFingerprint
    )

    $target = Assert-AiConfigHubPathInside $TargetPath $Context.UserHome $Name
    if (-not [string]::IsNullOrWhiteSpace($ExpectedFingerprint)) {
        Assert-AiConfigHubTargetUnchanged $target $ExpectedFingerprint $Name
    }
    $targetExists = Test-Path -LiteralPath $target
    if ($targetExists -and -not (Test-Path -LiteralPath $target -PathType Leaf)) {
        throw "$Name target exists but is not a file: $target"
    }

    $targetParent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $targetParent)) {
        New-Item -ItemType Directory -Force -Path $targetParent | Out-Null
    }

    $backup = Join-Path $Context.BackupRoot ($Name + '.bak')
    $backupParent = Split-Path -Parent $backup
    if (-not (Test-Path -LiteralPath $backupParent)) {
        New-Item -ItemType Directory -Force -Path $backupParent | Out-Null
    }

    $existed = $targetExists
    if ($existed) {
        [System.IO.File]::Replace($StagedPath, $target, $backup, $true)
    }
    else {
        [System.IO.File]::Move($StagedPath, $target)
    }

    $record = [pscustomobject]@{
        Kind = 'File'
        Name = $Name
        Target = $target
        Backup = $backup
        Existed = $existed
    }
    $Context.Changes.Add($record) | Out-Null
    return $record
}

function Install-AiConfigHubStagedDirectory {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$StagedPath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [string]$ExpectedFingerprint
    )

    $target = Assert-AiConfigHubPathInside $TargetPath $Context.UserHome $Name
    if (-not [string]::IsNullOrWhiteSpace($ExpectedFingerprint)) {
        Assert-AiConfigHubTargetUnchanged $target $ExpectedFingerprint $Name
    }
    $targetExists = Test-Path -LiteralPath $target
    if ($targetExists -and -not (Test-Path -LiteralPath $target -PathType Container)) {
        throw "$Name target exists but is not a directory: $target"
    }

    $targetParent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $targetParent)) {
        New-Item -ItemType Directory -Force -Path $targetParent | Out-Null
    }

    $backup = Join-Path $Context.BackupRoot ($Name + '.bak')
    $existed = $targetExists
    if ($existed) {
        [System.IO.Directory]::Move($target, $backup)
    }

    try {
        [System.IO.Directory]::Move($StagedPath, $target)
    }
    catch {
        if ($existed -and (Test-Path -LiteralPath $backup)) {
            [System.IO.Directory]::Move($backup, $target)
        }
        throw
    }

    $record = [pscustomobject]@{
        Kind = 'Directory'
        Name = $Name
        Target = $target
        Backup = $backup
        Existed = $existed
    }
    $Context.Changes.Add($record) | Out-Null
    return $record
}

function Restore-AiConfigHubOperation {
    param([Parameter(Mandatory = $true)]$Context)

    $errors = New-Object System.Collections.Generic.List[string]
    for ($index = $Context.Changes.Count - 1; $index -ge 0; $index--) {
        $change = $Context.Changes[$index]
        try {
            if ($change.Existed -and -not (Test-Path -LiteralPath $change.Backup)) {
                throw "Backup is missing for $($change.Name): $($change.Backup)"
            }

            if (Test-Path -LiteralPath $change.Target) {
                Remove-Item -LiteralPath $change.Target -Recurse -Force
            }

            if ($change.Existed) {
                if ($change.Kind -eq 'File') {
                    $parent = Split-Path -Parent $change.Target
                    if (-not (Test-Path -LiteralPath $parent)) {
                        New-Item -ItemType Directory -Force -Path $parent | Out-Null
                    }
                    Copy-Item -LiteralPath $change.Backup -Destination $change.Target -Force
                }
                else {
                    [System.IO.Directory]::Move($change.Backup, $change.Target)
                }
            }
        }
        catch {
            $errors.Add("$($change.Name): $($_.Exception.Message)") | Out-Null
        }
    }

    if ($errors.Count -gt 0) {
        throw "Rollback was incomplete:`n$($errors -join "`n")"
    }
}

function Complete-AiConfigHubOperation {
    param([Parameter(Mandatory = $true)]$Context)

    if (Test-Path -LiteralPath $Context.StagingRoot) {
        Remove-Item -LiteralPath $Context.StagingRoot -Recurse -Force
    }
    Write-Output "Backup root: $($Context.BackupRoot)"
}

function Remove-AiConfigHubOperationStaging {
    param([Parameter(Mandatory = $true)]$Context)

    if (Test-Path -LiteralPath $Context.StagingRoot) {
        Remove-Item -LiteralPath $Context.StagingRoot -Recurse -Force
    }
}

function Throw-AiConfigHubOperationFailure {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)]$ErrorRecord
    )

    $followUpErrors = New-Object System.Collections.Generic.List[string]
    try {
        Restore-AiConfigHubOperation $Context
    }
    catch {
        $followUpErrors.Add("rollback: $($_.Exception.Message)") | Out-Null
    }
    finally {
        try {
            Remove-AiConfigHubOperationStaging $Context
        }
        catch {
            $followUpErrors.Add("staging cleanup: $($_.Exception.Message)") | Out-Null
        }
    }

    if ($followUpErrors.Count -gt 0) {
        $details = $followUpErrors -join "`n"
        throw "Operation failed: $($ErrorRecord.Exception.Message)`nRollback or cleanup also failed:`n$details"
    }

    throw $ErrorRecord
}

function Assert-AiConfigHubNodeVersion {
    param(
        [string]$MinimumVersion = '22.19.0',
        [int]$MaximumMajorExclusive = 25
    )

    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) {
        throw "Required command 'node' was not found on PATH."
    }

    $raw = (& $node.Source --version).Trim().TrimStart('v')
    $version = [Version]$raw
    $minimum = [Version]$MinimumVersion
    if ($version -lt $minimum -or $version.Major -ge $MaximumMajorExclusive) {
        throw "Unsupported Node.js version $version. ai-config-hub requires Node.js >=$MinimumVersion and <$MaximumMajorExclusive.0.0."
    }

    return $node
}

function Invoke-AiConfigHubPreflight {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$UserHome,
        [switch]$IncludeCodexLegacy
    )

    $checkAll = Join-Path $Root 'scripts\check-all.ps1'
    $parameters = @{ UserHome = $UserHome }
    if ($IncludeCodexLegacy) {
        $parameters.IncludeCodexLegacy = $true
    }
    & $checkAll @parameters
    if ($LASTEXITCODE -ne 0) {
        throw "Full preflight failed with exit code $LASTEXITCODE."
    }
}

function Test-AiConfigHubManagedSkillTarget {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$SkillName
    )

    $skillFile = Join-Path $Path 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillFile)) {
        return $false
    }

    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillFile
    if ($content.Contains("<!-- ai-config-hub-managed: $SkillName -->")) {
        return $true
    }

    return $false
}
