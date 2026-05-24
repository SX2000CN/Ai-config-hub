$ErrorActionPreference = 'Stop'

$ContextThreadArgs = $args

$Root = Split-Path -Parent $PSScriptRoot
$UserHome = [Environment]::GetFolderPath('UserProfile')
$RuntimeRoot = Join-Path $UserHome '.ai-config-hub\mcp\context-thread'
$RuntimeEntry = Join-Path $RuntimeRoot 'dist\bin\context-thread.js'

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

if ($null -eq $ContextThreadArgs -or $ContextThreadArgs.Count -eq 0) {
    Write-Usage
    exit 64
}

if ($ContextThreadArgs[0] -eq 'bootstrap') {
    & (Join-Path $Root 'scripts\sync-context-thread-runtime.ps1') -Apply
    exit $LASTEXITCODE
}

if (-not (Test-Path -LiteralPath $RuntimeEntry)) {
    throw "ContextThread runtime was not found: $RuntimeEntry. Run '.\scripts\sync-context-thread-runtime.ps1 -Apply' first."
}

$node = Require-Command 'node'
& $node.Source $RuntimeEntry @ContextThreadArgs
exit $LASTEXITCODE
