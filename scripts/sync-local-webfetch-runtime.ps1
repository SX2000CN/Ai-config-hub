[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$UserHome
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'
. (Join-Path $PSScriptRoot 'lib\deploy.ps1')

$Manifest = Import-AiConfigHubManagedAssetsManifest $ManifestPath
$Runtime = $Manifest.Runtimes | Where-Object { $_.Name -eq 'local-webfetch' } | Select-Object -First 1
if ($null -eq $Runtime) {
    throw 'local-webfetch runtime is not registered in config/managed-assets.psd1.'
}

$ResolvedUserHome = Resolve-AiConfigHubUserHome $UserHome
$SourceRoot = Join-Path $Root ([string]$Runtime.SourceRoot)
$RuntimeRoot = Join-Path $ResolvedUserHome ([string]$Runtime.UserRelativeRoot)
$RuntimeEntry = Join-Path $RuntimeRoot ([string]$Runtime.EntryRelativePath)
Assert-AiConfigHubPathInside $RuntimeRoot $ResolvedUserHome 'local-webfetch runtime' | Out-Null

foreach ($fileName in @('package.json', 'package-lock.json', 'index.js', 'fetch-core.js')) {
    $path = Join-Path $SourceRoot $fileName
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing local-webfetch runtime source: $path"
    }
}

$node = Assert-AiConfigHubNodeVersion

if (-not $Apply) {
    Write-Output 'Dry run only. Re-run with -Apply after reviewing the full preflight output.'
    Write-Output "source`t$SourceRoot"
    Write-Output "target`t$RuntimeRoot"
    Write-Output "entry`t$RuntimeEntry"
    Write-Output $(if (Test-Path -LiteralPath $RuntimeEntry) { "status`tinstalled runtime entry exists" } else { "status`truntime entry is missing" })
    Write-Output 'would stage files and production dependencies, validate, then atomically swap the runtime'
    return
}

Invoke-AiConfigHubPreflight $Root $ResolvedUserHome
$RuntimeExpectedFingerprint = Get-AiConfigHubPathFingerprint $RuntimeRoot
if ((Test-Path -LiteralPath $RuntimeRoot) -and -not (Test-Path -LiteralPath $RuntimeRoot -PathType Container)) {
    throw "local-webfetch runtime target exists but is not a directory: $RuntimeRoot"
}
$npm = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npm) {
    throw "Required command 'npm' was not found on PATH."
}

$context = New-AiConfigHubOperationContext -UserHome $ResolvedUserHome -Pipeline 'runtime-local-webfetch' -StagingRelativeRoot $Manifest.UserPaths.StagingRoot -BackupRelativeRoot $Manifest.UserPaths.BackupRoot
try {
    $stagedRuntime = Join-Path $context.StagingRoot 'local-webfetch'
    New-Item -ItemType Directory -Force -Path $stagedRuntime | Out-Null
    foreach ($fileName in @('package.json', 'package-lock.json', 'index.js', 'fetch-core.js', 'README.md')) {
        $sourceFile = Join-Path $SourceRoot $fileName
        if (Test-Path -LiteralPath $sourceFile) {
            Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $stagedRuntime $fileName) -Force
        }
    }

    Push-Location -LiteralPath $stagedRuntime
    try {
        & $npm.Source ci --omit=dev
        if ($LASTEXITCODE -ne 0) { throw "runtime npm ci failed with exit code $LASTEXITCODE" }
    }
    finally {
        Pop-Location
    }

    $stagedEntry = Join-Path $stagedRuntime ([string]$Runtime.EntryRelativePath)
    foreach ($scriptPath in @($stagedEntry, (Join-Path $stagedRuntime 'fetch-core.js'))) {
        & $node.Source --check $scriptPath
        if ($LASTEXITCODE -ne 0) { throw "local-webfetch staged syntax check failed for $scriptPath with exit code $LASTEXITCODE" }
    }
    Push-Location -LiteralPath $stagedRuntime
    try {
        & $node.Source -e "import('./fetch-core.js').then((module) => { if (typeof module.fetchUrlBytes !== 'function') process.exit(1) })"
        if ($LASTEXITCODE -ne 0) { throw "local-webfetch staged module smoke check failed with exit code $LASTEXITCODE" }
    }
    finally {
        Pop-Location
    }

    Install-AiConfigHubStagedDirectory $context 'local-webfetch' $stagedRuntime $RuntimeRoot -ExpectedFingerprint $RuntimeExpectedFingerprint | Out-Null
    Complete-AiConfigHubOperation $context
    Write-Output "Synced local-webfetch runtime: $RuntimeRoot"
}
catch {
    Throw-AiConfigHubOperationFailure $context $_
}
