[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ContextThreadArgs
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ContextThreadRoot = Join-Path $Root 'tools\context-thread-engine'
$ContextThreadEntry = Join-Path $ContextThreadRoot 'dist\bin\context-thread.js'

function Write-Usage() {
    Write-Error @"
No context-thread command was provided.

Use one of:
  .\scripts\context-thread.ps1 bootstrap
  .\scripts\context-thread.ps1 serve --mcp
  .\scripts\context-thread.ps1 init -i <project-path>
  .\scripts\context-thread.ps1 sync <project-path>
"@
}

function Require-Command($Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command '$Name' was not found on PATH."
    }
    return $command
}

if (-not (Test-Path -LiteralPath $ContextThreadRoot)) {
    throw "Local context-thread engine source was not found: $ContextThreadRoot"
}

if ($null -eq $ContextThreadArgs -or $ContextThreadArgs.Count -eq 0) {
    Write-Usage
    exit 64
}

if ($ContextThreadArgs[0] -eq 'bootstrap') {
    $npm = Require-Command 'npm'

    Push-Location -LiteralPath $ContextThreadRoot
    try {
        & $npm.Source ci
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }

        & $npm.Source run build
        exit $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path -LiteralPath $ContextThreadEntry)) {
    throw "Local context-thread engine build was not found: $ContextThreadEntry. Run '.\scripts\context-thread.ps1 bootstrap' first."
}

$node = Require-Command 'node'
& $node.Source $ContextThreadEntry @ContextThreadArgs
exit $LASTEXITCODE
