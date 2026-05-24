[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$SourceRoot = Join-Path $Root 'tools\context-thread-engine'
$UserHome = [Environment]::GetFolderPath('UserProfile')
$RuntimeRoot = Join-Path $UserHome '.ai-config-hub\mcp\context-thread'
$RuntimeEntry = Join-Path $RuntimeRoot 'dist\bin\context-thread.js'

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
    throw "Missing context-thread engine source: $SourceRoot"
}

$packageJson = Join-Path $SourceRoot 'package.json'
$packageLock = Join-Path $SourceRoot 'package-lock.json'
foreach ($path in @($packageJson, $packageLock)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing runtime package file: $path"
    }
}

Assert-PathInside $RuntimeRoot (Join-Path $UserHome '.ai-config-hub') 'Runtime root'

if (-not $Apply) {
    Write-Output 'Dry run only. Re-run with -Apply to sync the context-thread runtime.'
    Write-Output "source`t$SourceRoot"
    Write-Output "target`t$RuntimeRoot"
    Write-Output "entry`t$RuntimeEntry"
    if (Test-Path -LiteralPath $RuntimeEntry) {
        Write-Output "status`tinstalled runtime entry exists"
    }
    else {
        Write-Output "status`truntime entry is missing"
    }
    if ($SkipBuild) {
        Write-Output 'would copy existing dist without rebuilding because -SkipBuild was provided'
    }
    else {
        Write-Output 'would build source with npm run build before copying'
    }
    Write-Output 'would install production dependencies in the runtime with npm ci --omit=dev'
    exit 0
}

$npm = Require-Command 'npm'
$node = Require-Command 'node'

if (-not $SkipBuild) {
    Push-Location -LiteralPath $SourceRoot
    try {
        if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot 'node_modules'))) {
            & $npm.Source ci
            if ($LASTEXITCODE -ne 0) {
                exit $LASTEXITCODE
            }
        }

        & $npm.Source run build
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
    }
}

$sourceDist = Join-Path $SourceRoot 'dist'
$sourceEntry = Join-Path $sourceDist 'bin\context-thread.js'
if (-not (Test-Path -LiteralPath $sourceEntry)) {
    throw "Missing built context-thread entry: $sourceEntry. Run without -SkipBuild or build the engine first."
}

New-Item -ItemType Directory -Force -Path $RuntimeRoot | Out-Null

foreach ($fileName in @('package.json', 'package-lock.json', 'README.md', 'LICENSE')) {
    $sourceFile = Join-Path $SourceRoot $fileName
    if (Test-Path -LiteralPath $sourceFile) {
        Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $RuntimeRoot $fileName) -Force
    }
}

$runtimeDist = Join-Path $RuntimeRoot 'dist'
Assert-PathInside $runtimeDist $RuntimeRoot 'Runtime dist'
if (Test-Path -LiteralPath $runtimeDist) {
    Remove-Item -LiteralPath $runtimeDist -Recurse -Force
}
Copy-Item -LiteralPath $sourceDist -Destination $RuntimeRoot -Recurse -Force

$runtimeWrapper = Join-Path $RuntimeRoot 'context-thread.ps1'
$wrapperContent = @'
$ErrorActionPreference = 'Stop'

$RuntimeRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Entry = Join-Path $RuntimeRoot 'dist\bin\context-thread.js'

if (-not (Test-Path -LiteralPath $Entry)) {
    throw "ContextThread runtime entry was not found: $Entry"
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    throw "Required command 'node' was not found on PATH."
}

& $node.Source $Entry @args
exit $LASTEXITCODE
'@
Set-Content -Encoding UTF8 -LiteralPath $runtimeWrapper -Value $wrapperContent -NoNewline

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

if (-not (Test-Path -LiteralPath $RuntimeEntry)) {
    throw "Runtime sync completed but entry is missing: $RuntimeEntry"
}

& $node.Source $RuntimeEntry --help | Out-Null
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Output "Synced context-thread runtime: $RuntimeRoot"
Write-Output "Runtime entry: $RuntimeEntry"
