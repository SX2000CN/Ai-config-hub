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
$Runtime = Get-AiConfigHubRuntimeDefinition $Manifest 'browser-mcp'
if ($null -eq $Runtime) {
    throw 'browser-mcp runtime is not registered in config/managed-assets.psd1.'
}

$ResolvedUserHome = Resolve-AiConfigHubUserHome $UserHome
$SourceRoot = Join-Path $Root ([string]$Runtime.SourceRoot)
$RuntimeRoot = Join-Path $ResolvedUserHome ([string]$Runtime.UserRelativeRoot)
$RuntimeEntry = Join-Path $RuntimeRoot ([string]$Runtime.EntryRelativePath)
Assert-AiConfigHubPathInside $RuntimeRoot $ResolvedUserHome 'browser MCP runtime' | Out-Null

foreach ($path in @(
    $SourceRoot,
    (Join-Path $SourceRoot 'package.json'),
    (Join-Path $SourceRoot 'package-lock.json'),
    (Join-Path $SourceRoot ([string]$Runtime.EntryRelativePath))
)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing browser MCP runtime source: $path"
    }
}

$node = Assert-AiConfigHubNodeVersion
if (-not $Apply) {
    Write-Output 'Dry run only. Re-run with -Apply after reviewing the full preflight output.'
    Write-Output "source`t$SourceRoot"
    Write-Output "target`t$RuntimeRoot"
    Write-Output "entry`t$RuntimeEntry"
    Write-Output $(if (Test-Path -LiteralPath $RuntimeEntry) { "status`tinstalled runtime entry exists" } else { "status`truntime entry is missing" })
    Write-Output 'would stage the pinned Chrome DevTools production dependency, validate the server, then atomically swap the runtime'
    return
}

Invoke-AiConfigHubPreflight $Root $ResolvedUserHome
$RuntimeExpectedFingerprint = Get-AiConfigHubPathFingerprint $RuntimeRoot
if ((Test-Path -LiteralPath $RuntimeRoot) -and -not (Test-Path -LiteralPath $RuntimeRoot -PathType Container)) {
    throw "browser MCP runtime target exists but is not a directory: $RuntimeRoot"
}
$npm = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npm) {
    throw "Required command 'npm' was not found on PATH."
}

$context = New-AiConfigHubOperationContext -UserHome $ResolvedUserHome -Pipeline 'runtime-browser-mcp' -StagingRelativeRoot $Manifest.UserPaths.StagingRoot -BackupRelativeRoot $Manifest.UserPaths.BackupRoot
try {
    $stagedRuntime = Copy-AiConfigHubStagedDirectory $context 'browser-mcp' $SourceRoot
    $nodeModules = Join-Path $stagedRuntime 'node_modules'
    if (Test-Path -LiteralPath $nodeModules) {
        Remove-Item -LiteralPath $nodeModules -Recurse -Force
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
    & $node.Source --check $stagedEntry
    if ($LASTEXITCODE -ne 0) { throw "browser MCP staged syntax check failed with exit code $LASTEXITCODE" }
    & $node.Source $stagedEntry --doctor | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Chrome DevTools MCP staged doctor failed with exit code $LASTEXITCODE" }

    Install-AiConfigHubStagedDirectory $context 'browser-mcp' $stagedRuntime $RuntimeRoot -ExpectedFingerprint $RuntimeExpectedFingerprint | Out-Null
    Complete-AiConfigHubOperation $context
    Write-Output "Synced browser MCP runtime: $RuntimeRoot"
}
catch {
    Throw-AiConfigHubOperationFailure $context $_
}
