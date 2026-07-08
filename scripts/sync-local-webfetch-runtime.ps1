[CmdletBinding()]
param(
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$SourceRoot = Join-Path $Root 'tools\local-webfetch'
$UserHome = [Environment]::GetFolderPath('UserProfile')
$RuntimeRoot = Join-Path $UserHome '.ai-config-hub\mcp\local-webfetch'
$RuntimeEntry = Join-Path $RuntimeRoot 'index.js'

function Get-FullPath($Path) {
    return [System.IO.Path]::GetFullPath($Path)
}

function Assert-PathInside($Path, $Parent, $Label) {
    $fullPath = Get-FullPath $Path
    $fullParent = (Get-FullPath $Parent).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($fullParent, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label path is outside expected parent: $fullPath"
    }
}

function Require-Command($Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command '$Name' was not found on PATH."
    }
    return $command
}

if (-not (Test-Path -LiteralPath $SourceRoot)) {
    throw "Missing local-webfetch source: $SourceRoot"
}

foreach ($fileName in @('package.json', 'package-lock.json', 'index.js')) {
    $filePath = Join-Path $SourceRoot $fileName
    if (-not (Test-Path -LiteralPath $filePath)) {
        throw "Missing source file: $filePath"
    }
}

Assert-PathInside $RuntimeRoot (Join-Path $UserHome '.ai-config-hub') 'Runtime root'

if (-not $Apply) {
    Write-Output 'Dry run only. Re-run with -Apply to sync the local-webfetch runtime.'
    Write-Output "source`t$SourceRoot"
    Write-Output "target`t$RuntimeRoot"
    Write-Output "entry`t$RuntimeEntry"
    if (Test-Path -LiteralPath $RuntimeEntry) {
        Write-Output "status`tinstalled runtime entry exists"
    }
    else {
        Write-Output "status`truntime entry is missing"
    }
    Write-Output 'would copy index.js, package.json, package-lock.json, README.md'
    Write-Output 'would install production dependencies with npm ci --omit=dev'
    Write-Output 'would verify entry with node --check'
    exit 0
}

$npm = Require-Command 'npm'
$node = Require-Command 'node'

New-Item -ItemType Directory -Force -Path $RuntimeRoot | Out-Null

foreach ($fileName in @('package.json', 'package-lock.json', 'index.js', 'README.md')) {
    $sourceFile = Join-Path $SourceRoot $fileName
    if (Test-Path -LiteralPath $sourceFile) {
        Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $RuntimeRoot $fileName) -Force
    }
}

Push-Location -LiteralPath $RuntimeRoot
try {
    & $npm.Source ci --omit=dev
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}

# Syntax check only — do NOT run the entry directly; it is a stdio MCP server
# that would hang waiting for JSON-RPC input if executed without a client.
& $node.Source --check $RuntimeEntry
if ($LASTEXITCODE -ne 0) {
    throw "Syntax check failed for runtime entry: $RuntimeEntry"
}

if (-not (Test-Path -LiteralPath $RuntimeEntry)) {
    throw "Runtime sync completed but entry is missing: $RuntimeEntry"
}

Write-Output "Synced local-webfetch runtime: $RuntimeRoot"
Write-Output "Runtime entry: $RuntimeEntry"
