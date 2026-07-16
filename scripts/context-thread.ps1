$ErrorActionPreference = 'Stop'

$ContextThreadArgs = $args

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'
. (Join-Path $PSScriptRoot 'lib\deploy.ps1')

$Manifest = Import-AiConfigHubManagedAssetsManifest $ManifestPath
$Runtime = $Manifest.Runtimes | Where-Object { $_.Name -eq 'context-thread' } | Select-Object -First 1
if ($null -eq $Runtime) {
    throw 'context-thread runtime is not registered in config/managed-assets.psd1.'
}
$UserHome = Resolve-AiConfigHubUserHome
$RuntimeRoot = Join-Path $UserHome ([string]$Runtime.UserRelativeRoot)
$RuntimeEntry = Join-Path $RuntimeRoot ([string]$Runtime.EntryRelativePath)

function Write-Usage() {
    Write-Error @"
No context-thread command was provided.

Use one of:
  .\scripts\context-thread.ps1 bootstrap
  .\scripts\context-thread.ps1 serve --mcp
  .\scripts\context-thread.ps1 init <project-path> --index
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

$node = Assert-AiConfigHubNodeVersion
& $node.Source $RuntimeEntry @ContextThreadArgs
exit $LASTEXITCODE
