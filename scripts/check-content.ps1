[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'
. (Join-Path $PSScriptRoot 'lib\validation.ps1')

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing managed assets manifest: $ManifestPath"
}

$Manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath
$CanonicalRoot = Join-Path $Root 'skills\shared'
$ExpectedSkillNames = @($Manifest.Skills.Names | ForEach-Object { [string]$_ })

function Invoke-ContentCheck {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptName,
        [hashtable]$Arguments = @{}
    )

    $path = Join-Path $PSScriptRoot $ScriptName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing content check script: $path"
    }

    Write-Output "Running $ScriptName"
    & $path @Arguments
    $commandSucceeded = $?
    if (-not $commandSucceeded) {
        throw "$ScriptName failed"
    }
}

function Test-CanonicalSkillRegistry {
    if (-not (Test-Path -LiteralPath $CanonicalRoot -PathType Container)) {
        throw "Missing canonical skill source root: $CanonicalRoot"
    }

    $seenNames = @{}
    foreach ($skillName in $ExpectedSkillNames) {
        if ([string]::IsNullOrWhiteSpace($skillName) -or
            $skillName -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or
            $skillName.Length -gt 64 -or
            $seenNames.ContainsKey($skillName)) {
            throw "Managed skill names must be non-empty, unique, and portable: $skillName"
        }
        $seenNames[$skillName] = $true

        $packageRoot = Join-Path $CanonicalRoot $skillName
        if (-not (Test-Path -LiteralPath $packageRoot -PathType Container)) {
            throw "Missing canonical skill package: $packageRoot"
        }
        if (-not (Test-Path -LiteralPath (Join-Path $packageRoot 'SKILL.md') -PathType Leaf)) {
            throw "Missing canonical SKILL.md: $(Join-Path $packageRoot 'SKILL.md')"
        }
    }

    foreach ($package in Get-ChildItem -LiteralPath $CanonicalRoot -Directory -Force) {
        if (-not $seenNames.ContainsKey($package.Name)) {
            throw "Canonical skill package is not registered in config/managed-assets.psd1: $($package.FullName)"
        }
    }

    $renderedRoot = Join-Path $Root 'skills\rendered'
    if (-not (Test-Path -LiteralPath $renderedRoot -PathType Container)) {
        throw "Missing rendered skill root: $renderedRoot"
    }
    $activeRenderedRoots = @($Manifest.Skills.Targets | ForEach-Object {
        [System.IO.Path]::GetFileName(([string]$_.RenderedRoot).TrimEnd('\', '/'))
    })
    $retiredRenderedRoots = @($Manifest.Skills.RetiredRenderedRoots | ForEach-Object {
        [System.IO.Path]::GetFileName(([string]$_).TrimEnd('\', '/'))
    })
    $allowedRenderedRoots = @($activeRenderedRoots + $retiredRenderedRoots)
    foreach ($entry in Get-ChildItem -LiteralPath $renderedRoot -Force) {
        if ($entry.PSIsContainer -and $allowedRenderedRoots -notcontains $entry.Name) {
            throw "Unregistered rendered skill root: $($entry.FullName)"
        }
        if (-not $entry.PSIsContainer) {
            throw "Unexpected file directly under skills/rendered: $($entry.FullName)"
        }
    }
    foreach ($rootName in $activeRenderedRoots) {
        $activeRoot = Join-Path $renderedRoot $rootName
        if (-not (Test-Path -LiteralPath $activeRoot -PathType Container)) {
            throw "Missing active rendered skill root: $activeRoot"
        }
        foreach ($package in Get-ChildItem -LiteralPath $activeRoot -Directory -Force) {
            if (-not $seenNames.ContainsKey($package.Name)) {
                throw "Unregistered rendered skill package: $($package.FullName)"
            }
        }
    }
}

function Invoke-GitDiffCheck {
    # git may print autocrlf notices to stderr; preserve actual diff-check
    # diagnostics while allowing those warnings.
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & git -C $Root diff --check 2>&1 | ForEach-Object {
            $text = "$_"
            if ($text -match '^\s*warning:') {
                Write-Warning ($text -replace '^\s*warning:\s*', '')
                return
            }
            Write-Output $text
        }
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw "git diff --check failed with exit code $exitCode"
    }
}

Test-CanonicalSkillRegistry
Write-Output 'Verified canonical skill registry'

# These checks are deliberately limited to repository content and rendered
# content. They do not invoke MCP, runtime, hooks, user-sync, or doctor steps.
# check.ps1 and check-skills.ps1 own their corresponding render consistency
# checks. Calling the render scripts here as well would run the same work twice.
Invoke-ContentCheck 'check.ps1'
Invoke-ContentCheck 'check-rules-hygiene.ps1'
Invoke-ContentCheck 'check-skills.ps1'

$contentPaths = @(
    (Join-Path $Root 'rules\shared'),
    (Join-Path $Root 'rules\rendered'),
    (Join-Path $Root 'templates'),
    (Join-Path $Root 'skills\shared'),
    (Join-Path $Root 'skills\rendered'),
    (Join-Path $Root 'skills\evals')
)
$contentFiles = Get-AiConfigHubScanFiles -Paths $contentPaths -Root $Root
Test-AiConfigHubSensitiveContent -Files $contentFiles -Fail {
    param($Message)
    throw $Message
}
Write-Output 'Sensitive content check passed'

Invoke-GitDiffCheck
Write-Output 'Content check passed'
