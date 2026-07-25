[CmdletBinding()]
param(
    [string]$UserHome,
    [switch]$IncludeCodexLegacy
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib\deploy.ps1')
. (Join-Path $PSScriptRoot 'lib\validation.ps1')
$ResolvedUserHome = Resolve-AiConfigHubUserHome $UserHome
Assert-AiConfigHubNodeVersion | Out-Null
Import-AiConfigHubManagedAssetsManifest (Join-Path $Root 'config\managed-assets.psd1') | Out-Null

function Invoke-CheckedScript {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [hashtable]$Parameters = @{}
    )

    & $Path @Parameters
    if ($LASTEXITCODE -ne 0) {
        throw "$Path failed with exit code $LASTEXITCODE"
    }
}

Invoke-CheckedScript (Join-Path $PSScriptRoot 'check.ps1')
Invoke-CheckedScript (Join-Path $PSScriptRoot 'check-skills.ps1')
Invoke-CheckedScript (Join-Path $PSScriptRoot 'check-mcp.ps1')

$engineRoot = Join-Path $Root 'tools\context-thread-engine'
if (-not (Test-Path -LiteralPath (Join-Path $engineRoot 'node_modules'))) {
    throw 'context-thread dependencies are missing. Run npm ci in tools/context-thread-engine first.'
}
Push-Location -LiteralPath $engineRoot
try {
    & npm test
    if ($LASTEXITCODE -ne 0) { throw "context-thread tests failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}

$webfetchRoot = Join-Path $Root 'tools\local-webfetch'
if (-not (Test-Path -LiteralPath (Join-Path $webfetchRoot 'node_modules'))) {
    throw 'local-webfetch dependencies are missing. Run npm ci in tools/local-webfetch first.'
}
foreach ($scriptPath in @((Join-Path $webfetchRoot 'index.js'), (Join-Path $webfetchRoot 'fetch-core.js'))) {
    & node --check $scriptPath
    if ($LASTEXITCODE -ne 0) { throw "local-webfetch syntax check failed for $scriptPath with exit code $LASTEXITCODE" }
}
Push-Location -LiteralPath $webfetchRoot
try {
    & npm test
    if ($LASTEXITCODE -ne 0) { throw "local-webfetch tests failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}

$browserRuntimeRoot = Join-Path $Root 'tools\browser-mcp-runtime'
if (-not (Test-Path -LiteralPath (Join-Path $browserRuntimeRoot 'node_modules'))) {
    throw 'browser MCP runtime dependencies are missing. Run npm ci in tools/browser-mcp-runtime first.'
}
& node --check (Join-Path $browserRuntimeRoot 'bin\browser-mcp-runtime.js')
if ($LASTEXITCODE -ne 0) { throw "browser MCP runtime syntax check failed with exit code $LASTEXITCODE" }
Push-Location -LiteralPath $browserRuntimeRoot
try {
    & npm test
    if ($LASTEXITCODE -ne 0) { throw "browser MCP runtime tests failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}

Invoke-CheckedScript (Join-Path $PSScriptRoot 'tests\sync-safety.ps1')
Invoke-CheckedScript (Join-Path $PSScriptRoot 'tests\mcp-profiles.ps1')
Invoke-CheckedScript (Join-Path $PSScriptRoot 'tests\mcp-doctor.ps1')
Invoke-CheckedScript (Join-Path $PSScriptRoot 'sync-context-thread-runtime.ps1') @{ UserHome = $ResolvedUserHome }
Invoke-CheckedScript (Join-Path $PSScriptRoot 'sync-local-webfetch-runtime.ps1') @{ UserHome = $ResolvedUserHome }
Invoke-CheckedScript (Join-Path $PSScriptRoot 'sync-browser-mcp-runtime.ps1') @{ UserHome = $ResolvedUserHome }
Invoke-CheckedScript (Join-Path $PSScriptRoot 'sync.ps1') @{ UserHome = $ResolvedUserHome }

$skillParameters = @{ UserHome = $ResolvedUserHome }
if ($IncludeCodexLegacy) { $skillParameters.IncludeCodexLegacy = $true }
Invoke-CheckedScript (Join-Path $PSScriptRoot 'sync-skills.ps1') $skillParameters
foreach ($profileName in Get-AiConfigHubMcpProfileNames (Import-AiConfigHubManagedAssetsManifest (Join-Path $Root 'config\managed-assets.psd1'))) {
    Invoke-CheckedScript (Join-Path $PSScriptRoot 'sync-mcp.ps1') @{ UserHome = $ResolvedUserHome; Profile = $profileName }
}
Invoke-CheckedScript (Join-Path $PSScriptRoot 'mcp-doctor.ps1') @{ UserHome = $ResolvedUserHome; Profile = 'full'; Mode = 'Source'; AllowDegraded = $true }

$repositoryScanFiles = Get-AiConfigHubScanFiles -Paths @($Root) -Root $Root
Test-AiConfigHubSensitiveContent -Files $repositoryScanFiles -Fail {
    param($Message)
    throw $Message
}

# git may write autocrlf LF/CRLF notices to stderr; do not treat those as terminating errors under Stop.
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
    $gitDiffCheckExit = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
if ($gitDiffCheckExit -ne 0) { throw "git diff --check failed with exit code $gitDiffCheckExit" }

Write-Output 'All non-mutating render checks, tests, validation, and dry-run steps passed'
