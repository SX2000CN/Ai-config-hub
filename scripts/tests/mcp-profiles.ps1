$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $Root 'scripts\lib\deploy.ps1')

function Assert-True($Value, $Message) { if (-not $Value) { throw $Message } }
function Assert-Equal($Expected, $Actual, $Message) { if ($Expected -ne $Actual) { throw "$Message. Expected '$Expected', got '$Actual'." } }
function Write-Utf8NoBom($Path, $Content) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [IO.File]::WriteAllText($Path, [string]$Content, (New-Object Text.UTF8Encoding($false)))
}
function Copy-TestItem($TargetRoot, $RelativePath) {
    $source = Join-Path $Root $RelativePath
    $target = Join-Path $TargetRoot $RelativePath
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
}

$manifest = Import-AiConfigHubManagedAssetsManifest (Join-Path $Root 'config\managed-assets.psd1')
Assert-Equal 'core' $manifest.Mcp.DefaultProfile 'Default MCP profile changed'
Assert-Equal 'local-webfetch' ((Get-AiConfigHubMcpProfile $manifest 'core').Servers -join ',') 'core profile changed'
Assert-Equal 'local-webfetch,chrome-devtools' ((Get-AiConfigHubMcpProfile $manifest 'browser-debug').Servers -join ',') 'browser-debug must remain minimal'
Assert-Equal (Join-Path $Root 'tool-configs\mcp\rendered\claude-code.mcp.json') (Get-AiConfigHubMcpRenderedPath $Root $manifest 'ClaudeCode' 'core') 'core Claude rendered path changed'
Assert-Equal (Join-Path $Root 'tool-configs\mcp\rendered\codex.mcp.toml') (Get-AiConfigHubMcpRenderedPath $Root $manifest 'Codex' 'core') 'core Codex rendered path changed'

& (Join-Path $Root 'scripts\render-mcp.ps1') -Check | Out-Null
& (Join-Path $Root 'scripts\check-mcp.ps1') | Out-Null

$dryRunHome = Join-Path ([IO.Path]::GetTempPath()) ('ai-config-hub-mcp-dry-' + [Guid]::NewGuid().ToString('N'))
foreach ($profileName in Get-AiConfigHubMcpProfileNames $manifest) {
    $output = & (Join-Path $Root 'scripts\sync-mcp.ps1') -Profile $profileName -UserHome $dryRunHome 2>&1 | Out-String
    Assert-True $output.Contains("profile`t$profileName") "sync-mcp dry-run did not select profile $profileName"
    Assert-True $output.Contains('Dry run only') "sync-mcp profile $profileName unexpectedly attempted Apply"
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('ai-config-hub-mcp-v1-' + [Guid]::NewGuid().ToString('N'))
try {
    foreach ($relativePath in @(
        'scripts\render-mcp.ps1', 'scripts\check-mcp.ps1', 'scripts\sync-mcp.ps1', 'scripts\mcp-local.ps1',
        'scripts\lib\managed-assets.ps1', 'scripts\lib\deploy.ps1', 'scripts\lib\validation.ps1', 'scripts\lib\mcp-smoke.mjs'
    )) { Copy-TestItem $tempRoot $relativePath }

    $v1Manifest = @'
@{
    SchemaVersion = 1
    Skills = @{ Names = @('demo'); Definitions = @(@{ Name = 'demo'; Role = 'domain' }); Targets = @() }
    Mcp = @{
        Groups = @(@{ Name = 'legacy'; Source = 'tool-configs\mcp\shared\legacy.json'; Targets = @('ClaudeCode', 'Codex'); LegacyServers = @() })
        Targets = @(
            @{ Name = 'ClaudeCode'; Rendered = 'tool-configs\mcp\rendered\claude-code.mcp.json'; UserRelativePath = '.claude.json' }
            @{ Name = 'Codex'; Rendered = 'tool-configs\mcp\rendered\codex.mcp.toml'; UserRelativePath = '.codex\config.toml' }
        )
        LocalServers = @()
    }
    Runtimes = @()
    UserPaths = @{ StagingRoot = '.ai-config-hub\staging'; BackupRoot = '.ai-config-hub\backups' }
}
'@
    $legacySource = @'
{
  "servers": {
    "legacy-a": { "package": "legacy-mcp@1.2.3", "command": "npx", "args": ["-y", "legacy-mcp@1.2.3"] },
    "legacy-b": { "command": "node", "args": ["--help"] }
  }
}
'@
    Write-Utf8NoBom (Join-Path $tempRoot 'config\managed-assets.psd1') $v1Manifest
    Write-Utf8NoBom (Join-Path $tempRoot 'tool-configs\mcp\shared\legacy.json') $legacySource

    $normalized = Import-AiConfigHubManagedAssetsManifest (Join-Path $tempRoot 'config\managed-assets.psd1')
    Assert-Equal 2 $normalized.SchemaVersion 'v1 manifest was not normalized to schema v2'
    Assert-Equal 1 $normalized.SourceSchemaVersion 'v1 source schema marker is missing'
    Assert-Equal 'domain' $normalized.Skills.Definitions[0].Role 'v1 normalization dropped Skills.Definitions'

    & (Join-Path $tempRoot 'scripts\render-mcp.ps1') | Out-Null
    & (Join-Path $tempRoot 'scripts\render-mcp.ps1') -Check | Out-Null
    & (Join-Path $tempRoot 'scripts\check-mcp.ps1') | Out-Null
    $legacyHome = Join-Path $tempRoot 'home'
    $legacyDryRun = & (Join-Path $tempRoot 'scripts\sync-mcp.ps1') -UserHome $legacyHome 2>&1 | Out-String
    Assert-True $legacyDryRun.Contains("profile`tfull") 'Normalized v1 sync did not select the synthetic full profile'
    Assert-True $legacyDryRun.Contains('legacy-a') 'Normalized v1 sync did not consume legacy server definitions'
    Assert-True $legacyDryRun.Contains('Dry run only') 'Normalized v1 sync unexpectedly attempted Apply'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    if (Test-Path -LiteralPath $dryRunHome) { Remove-Item -LiteralPath $dryRunHome -Recurse -Force }
}

$global:LASTEXITCODE = 0
Write-Output 'MCP profile and schema compatibility tests passed'
