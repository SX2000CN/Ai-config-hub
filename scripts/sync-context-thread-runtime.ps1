[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$SkipBuild,
    [string]$UserHome
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'
. (Join-Path $PSScriptRoot 'lib\deploy.ps1')

$Manifest = Import-AiConfigHubManagedAssetsManifest $ManifestPath
$Runtime = $Manifest.Runtimes | Where-Object { $_.Name -eq 'context-thread' } | Select-Object -First 1
if ($null -eq $Runtime) {
    throw 'context-thread runtime is not registered in config/managed-assets.psd1.'
}

$ResolvedUserHome = Resolve-AiConfigHubUserHome $UserHome
$SourceRoot = Join-Path $Root ([string]$Runtime.SourceRoot)
$RuntimeRoot = Join-Path $ResolvedUserHome ([string]$Runtime.UserRelativeRoot)
$RuntimeEntry = Join-Path $RuntimeRoot ([string]$Runtime.EntryRelativePath)
Assert-AiConfigHubPathInside $RuntimeRoot $ResolvedUserHome 'context-thread runtime' | Out-Null

foreach ($path in @(
    $SourceRoot,
    (Join-Path $SourceRoot 'package.json'),
    (Join-Path $SourceRoot 'package-lock.json')
)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing context-thread runtime source: $path"
    }
}

$node = Assert-AiConfigHubNodeVersion

if (-not $Apply) {
    Write-Output 'Dry run only. Re-run with -Apply after reviewing the full preflight output.'
    Write-Output "source`t$SourceRoot"
    Write-Output "target`t$RuntimeRoot"
    Write-Output "entry`t$RuntimeEntry"
    Write-Output $(if (Test-Path -LiteralPath $RuntimeEntry) { "status`tinstalled runtime entry exists" } else { "status`truntime entry is missing" })
    Write-Output $(if ($SkipBuild) { 'would copy existing dist without rebuilding' } else { 'would build source with npm run build' })
    Write-Output 'would stage production dependencies, validate, then atomically swap the runtime'
    return
}

Invoke-AiConfigHubPreflight $Root $ResolvedUserHome
$RuntimeExpectedFingerprint = Get-AiConfigHubPathFingerprint $RuntimeRoot
if ((Test-Path -LiteralPath $RuntimeRoot) -and -not (Test-Path -LiteralPath $RuntimeRoot -PathType Container)) {
    throw "context-thread runtime target exists but is not a directory: $RuntimeRoot"
}
$npm = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npm) {
    throw "Required command 'npm' was not found on PATH."
}

if (-not $SkipBuild) {
    Push-Location -LiteralPath $SourceRoot
    try {
        if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot 'node_modules'))) {
            & $npm.Source ci
            if ($LASTEXITCODE -ne 0) { throw "npm ci failed with exit code $LASTEXITCODE" }
        }
        & $npm.Source run build
        if ($LASTEXITCODE -ne 0) { throw "npm run build failed with exit code $LASTEXITCODE" }
    }
    finally {
        Pop-Location
    }
}

$sourceDist = Join-Path $SourceRoot 'dist'
$sourceEntry = Join-Path $sourceDist 'bin\context-thread.js'
if (-not (Test-Path -LiteralPath $sourceEntry)) {
    throw "Missing built context-thread entry: $sourceEntry"
}

$context = New-AiConfigHubOperationContext -UserHome $ResolvedUserHome -Pipeline 'runtime-context-thread' -StagingRelativeRoot $Manifest.UserPaths.StagingRoot -BackupRelativeRoot $Manifest.UserPaths.BackupRoot
try {
    $stagedRuntime = Join-Path $context.StagingRoot 'context-thread'
    New-Item -ItemType Directory -Force -Path $stagedRuntime | Out-Null
    foreach ($fileName in @('package.json', 'package-lock.json', 'README.md', 'LICENSE')) {
        $sourceFile = Join-Path $SourceRoot $fileName
        if (Test-Path -LiteralPath $sourceFile) {
            Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $stagedRuntime $fileName) -Force
        }
    }
    Copy-Item -LiteralPath $sourceDist -Destination $stagedRuntime -Recurse -Force

    $wrapperContent = @'
$ErrorActionPreference = 'Stop'
$RuntimeRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Entry = Join-Path $RuntimeRoot 'dist\bin\context-thread.js'
if (-not (Test-Path -LiteralPath $Entry)) { throw "ContextThread runtime entry was not found: $Entry" }
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { throw "Required command 'node' was not found on PATH." }
& $node.Source $Entry @args
exit $LASTEXITCODE
'@
    Set-Content -Encoding UTF8 -LiteralPath (Join-Path $stagedRuntime 'context-thread.ps1') -Value $wrapperContent -NoNewline

    Push-Location -LiteralPath $stagedRuntime
    try {
        & $npm.Source ci --omit=dev
        if ($LASTEXITCODE -ne 0) { throw "runtime npm ci failed with exit code $LASTEXITCODE" }
    }
    finally {
        Pop-Location
    }

    $stagedEntry = Join-Path $stagedRuntime ([string]$Runtime.EntryRelativePath)
    & $node.Source $stagedEntry --help | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "context-thread staged smoke check failed with exit code $LASTEXITCODE" }

    Install-AiConfigHubStagedDirectory $context 'context-thread' $stagedRuntime $RuntimeRoot -ExpectedFingerprint $RuntimeExpectedFingerprint | Out-Null
    Complete-AiConfigHubOperation $context
    Write-Output "Synced context-thread runtime: $RuntimeRoot"
}
catch {
    Throw-AiConfigHubOperationFailure $context $_
}
