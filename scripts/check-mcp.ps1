[CmdletBinding()]
param([string[]]$Profile)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'
. (Join-Path $PSScriptRoot 'lib\managed-assets.ps1')
. (Join-Path $PSScriptRoot 'mcp-local.ps1')
. (Join-Path $PSScriptRoot 'lib\validation.ps1')
$Manifest = Import-AiConfigHubManagedAssetsManifest $ManifestPath
$IsNormalizedV1 = $null -ne $Manifest.SourceSchemaVersion
$OpenCodeTarget = $Manifest.Mcp.Targets | Where-Object { [string]$_.Name -eq 'OpenCode' } | Select-Object -First 1
$Failed = $false

function Fail($Message) {
    Write-Output "ERROR: $Message"
    $script:Failed = $true
}

function Get-PropertyNames($Object) {
    if ($null -eq $Object) { return @() }
    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Get-SourceServerArgs($Server) {
    $serverArgs = @($Server.args)
    if (-not [string]::IsNullOrWhiteSpace([string]$Server.runtime_entry)) { $serverArgs += @([string]$Server.runtime_entry) }
    if (-not [string]::IsNullOrWhiteSpace([string]$Server.repo_script)) { $serverArgs += @(Join-Path $Root ([string]$Server.repo_script)) }
    if ($null -ne $Server.script_args) { $serverArgs += @($Server.script_args) }
    return @($serverArgs)
}

function Test-PackagePin($ServerName, $Server, $SourcePath) {
    $package = [string]$Server.package
    if ([string]::IsNullOrWhiteSpace($package)) {
        foreach ($argument in @(Get-SourceServerArgs $Server)) {
            if ([string]$argument -match '(?i)@latest(?:$|\s)') { Fail "MCP args must not use @latest for $ServerName in $SourcePath" }
        }
        return
    }
    if ($package -match '(?i)@latest(?:$|\s)' -or
        $package -notmatch '^(@[^/]+/[^@]+|[^@]+)@\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
        Fail "MCP package must use an exact semver for $ServerName in $SourcePath`: $package"
    }
}

$renderParameters = @{ Check = $true }
if ($null -ne $Profile -and $Profile.Count -gt 0) { $renderParameters.Profile = $Profile }
& (Join-Path $PSScriptRoot 'render-mcp.ps1') @renderParameters

$sourceByDefinition = @{}
$sourceServerNamesByDefinition = @{}
foreach ($definition in @($Manifest.Mcp.Servers)) {
    $definitionName = [string]$definition.Name
    if (-not $IsNormalizedV1) {
        foreach ($property in @('RequiresRuntime', 'Optional', 'PreferredFor', 'Doctor')) {
            if (-not $definition.ContainsKey($property)) { Fail "Managed MCP server $definitionName is missing metadata: $property" }
        }
        if ([string]::IsNullOrWhiteSpace([string]$definition.RequiresRuntime)) { Fail "Managed MCP server $definitionName must declare RequiresRuntime" }
        if (@($definition.PreferredFor).Count -eq 0) { Fail "Managed MCP server $definitionName must declare PreferredFor" }
        if ([string]::IsNullOrWhiteSpace([string]$definition.Doctor.Mode)) { Fail "Managed MCP server $definitionName must declare Doctor.Mode" }
        if (-not $definition.Doctor.ContainsKey('ExpectedToolCount') -or [int]$definition.Doctor.ExpectedToolCount -lt 0) { Fail "Managed MCP server $definitionName must declare a non-negative Doctor.ExpectedToolCount" }
    }

    $sourcePath = Join-Path $Root ([string]$definition.Source)
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        Fail "Missing MCP source: $sourcePath"
        continue
    }
    try { $source = Get-Content -Raw -Encoding UTF8 -LiteralPath $sourcePath | ConvertFrom-Json }
    catch { Fail "Invalid source JSON $sourcePath`: $($_.Exception.Message)"; continue }
    $serverNames = @(Get-PropertyNames $source.servers)
    if (-not $IsNormalizedV1 -and ($serverNames.Count -ne 1 -or $serverNames[0] -ne $definitionName)) {
        Fail "Schema v2 MCP source must define exactly server '$definitionName': $sourcePath"
        continue
    }
    $sourceByDefinition[$definitionName] = $source
    $sourceServerNamesByDefinition[$definitionName] = $serverNames
    $server = $source.servers.$definitionName
    if ([string]::IsNullOrWhiteSpace([string]$server.command)) { Fail "Missing command for source server: $definitionName" }
    if (@(Get-SourceServerArgs $server).Count -eq 0) { Fail "Missing args for source server: $definitionName" }
    if (-not $IsNormalizedV1 -and [string]$server.command -match '^(?i:npx)(?:\.cmd)?$') { Fail "Managed MCP server $definitionName must not use npx" }
    Test-PackagePin $definitionName $server $sourcePath
    if (-not [string]::IsNullOrWhiteSpace([string]$server.runtime_entry)) {
        $runtimeEntry = [string]$server.runtime_entry
        if (-not ($runtimeEntry.StartsWith('~\') -or $runtimeEntry.StartsWith('~/')) -or $runtimeEntry -match '(^|[\\/])\.\.([\\/]|$)') {
            Fail "runtime_entry for source server $definitionName must stay under the user profile: $runtimeEntry"
        }
    }
}

$browserPackagePath = Join-Path $Root 'tools\browser-mcp-runtime\package.json'
$browserLockPath = Join-Path $Root 'tools\browser-mcp-runtime\package-lock.json'
if (-not $IsNormalizedV1 -and $sourceByDefinition.ContainsKey('playwright') -and $sourceByDefinition.ContainsKey('chrome-devtools')) { try {
    $browserPackage = Get-Content -Raw -Encoding UTF8 -LiteralPath $browserPackagePath | ConvertFrom-Json
    $expectedBrowserPackages = @{
        'chrome-devtools' = @{ Name = 'chrome-devtools-mcp'; Version = '1.6.0' }
        'playwright' = @{ Name = '@playwright/mcp'; Version = '0.0.78' }
    }
    foreach ($entry in $expectedBrowserPackages.GetEnumerator()) {
        $sourceServer = $sourceByDefinition[$entry.Key].servers.PSObject.Properties[[string]$entry.Key].Value
        $sourcePackage = [string]$sourceServer.package
        $expectedSpec = "$($entry.Value.Name)@$($entry.Value.Version)"
        if ($sourcePackage -ne $expectedSpec) { Fail "MCP source package mismatch for $($entry.Key): expected $expectedSpec, found $sourcePackage" }
        $declaredVersion = [string]$browserPackage.dependencies.PSObject.Properties[[string]$entry.Value.Name].Value
        if ($declaredVersion -ne $entry.Value.Version) { Fail "Browser runtime dependency must pin $expectedSpec" }
    }
    $lockCheck = @'
const fs = require('fs');
const manifest = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
const lock = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const expected = { '@playwright/mcp': '0.0.78', 'chrome-devtools-mcp': '1.6.0' };
for (const [name, version] of Object.entries(expected)) {
  if (manifest.dependencies[name] !== version || lock.packages[`node_modules/${name}`]?.version !== version) {
    console.error(`${name} must be pinned to ${version}`);
    process.exit(1);
  }
}
'@
    & node -e $lockCheck $browserPackagePath $browserLockPath
    if ($LASTEXITCODE -ne 0) { Fail 'Browser runtime package.json and lockfile pins do not match the approved versions' }
}
catch {
    Fail "Invalid browser runtime package metadata: $($_.Exception.Message)"
} }

$profileNames = if ($null -eq $Profile -or $Profile.Count -eq 0) { Get-AiConfigHubMcpProfileNames $Manifest } else { @($Profile) }
foreach ($profileName in $profileNames) {
    $profileDefinition = Get-AiConfigHubMcpProfile $Manifest $profileName
    $claudeDefinitions = @(Get-AiConfigHubMcpServerDefinitionsForProfile $Manifest $profileDefinition 'ClaudeCode')
    $codexDefinitions = @(Get-AiConfigHubMcpServerDefinitionsForProfile $Manifest $profileDefinition 'Codex')
    $grokDefinitions = @(Get-AiConfigHubMcpServerDefinitionsForProfile $Manifest $profileDefinition 'Grok')
    $openCodeDefinitions = if ($null -ne $OpenCodeTarget) { @(Get-AiConfigHubMcpServerDefinitionsForProfile $Manifest $profileDefinition 'OpenCode') } else { @() }
    $expectedClaudeServers = @($claudeDefinitions | ForEach-Object { $sourceServerNamesByDefinition[[string]$_.Name] } | ForEach-Object { $_ })
    $expectedCodexServers = @($codexDefinitions | ForEach-Object { $sourceServerNamesByDefinition[[string]$_.Name] } | ForEach-Object { $_ })
    $expectedGrokServers = @($grokDefinitions | ForEach-Object { $sourceServerNamesByDefinition[[string]$_.Name] } | ForEach-Object { $_ })
    $expectedOpenCodeServers = @($openCodeDefinitions | ForEach-Object { $sourceServerNamesByDefinition[[string]$_.Name] } | ForEach-Object { $_ })

    $claudePath = Get-AiConfigHubMcpRenderedPath $Root $Manifest 'ClaudeCode' $profileName
    $codexPath = Get-AiConfigHubMcpRenderedPath $Root $Manifest 'Codex' $profileName
    $grokPath = Get-AiConfigHubMcpRenderedPath $Root $Manifest 'Grok' $profileName
    $openCodePath = if ($null -ne $OpenCodeTarget) { Get-AiConfigHubMcpRenderedPath $Root $Manifest 'OpenCode' $profileName } else { $null }
    try {
        $claude = Get-Content -Raw -Encoding UTF8 -LiteralPath $claudePath | ConvertFrom-Json
        $topLevelNames = @(Get-PropertyNames $claude)
        if ($topLevelNames.Count -ne 1 -or $topLevelNames[0] -ne 'mcpServers') { Fail "Claude profile $profileName must contain only top-level mcpServers" }
        $actualServers = @(Get-PropertyNames $claude.mcpServers)
        if (($actualServers -join '|') -ne ($expectedClaudeServers -join '|')) { Fail "Claude profile $profileName server set mismatch: expected $($expectedClaudeServers -join ', '), found $($actualServers -join ', ')" }
    }
    catch { Fail "Invalid Claude rendered JSON for profile $profileName`: $($_.Exception.Message)" }

    if ($null -ne $OpenCodeTarget) {
        try {
            $openCode = Get-Content -Raw -Encoding UTF8 -LiteralPath $openCodePath | ConvertFrom-Json
            $topLevelNames = @(Get-PropertyNames $openCode)
            if (($topLevelNames -join '|') -ne 'mcp') { Fail "OpenCode profile $profileName must contain only top-level mcp" }
            $actualServers = @(Get-PropertyNames $openCode.mcp)
            if (($actualServers -join '|') -ne ($expectedOpenCodeServers -join '|')) { Fail "OpenCode profile $profileName server set mismatch: expected $($expectedOpenCodeServers -join ', '), found $($actualServers -join ', ')" }
            foreach ($serverName in $actualServers) {
                $server = $openCode.mcp.$serverName
                if ([string]$server.type -ne 'local') { Fail "OpenCode profile $profileName server $serverName must use type local" }
                if (@($server.command).Count -lt 2) { Fail "OpenCode profile $profileName server $serverName must have a command array" }
                if ($null -eq $server.enabled -or -not [bool]$server.enabled) { Fail "OpenCode profile $profileName server $serverName must be enabled" }
                if ([int]$server.timeout -lt 30000) { Fail "OpenCode profile $profileName server $serverName must set timeout >= 30000" }
            }
        }
        catch { Fail "Invalid OpenCode rendered JSON for profile $profileName`: $($_.Exception.Message)" }
    }

    $codexContent = [string](Get-Content -Raw -Encoding UTF8 -LiteralPath $codexPath)
    foreach ($definition in $codexDefinitions) {
        $definitionName = [string]$definition.Name
        foreach ($marker in @("# >>> ai-config-hub managed mcp: $definitionName", "# <<< ai-config-hub managed mcp: $definitionName")) {
            if (-not $codexContent.Contains($marker)) { Fail "Missing Codex profile $profileName marker: $marker" }
        }
        foreach ($serverName in @($sourceServerNamesByDefinition[$definitionName])) {
            if ([regex]::Matches($codexContent, "(?m)^\[mcp_servers\.$([regex]::Escape($serverName))\]$").Count -ne 1) { Fail "Codex profile $profileName must contain one server section for $serverName" }
            if ([regex]::Matches($codexContent, "(?m)^\[mcp_servers\.$([regex]::Escape($serverName))\.env\]$").Count -ne 1) { Fail "Codex profile $profileName must contain one env section for $serverName" }
        }
    }
    foreach ($name in @($sourceServerNamesByDefinition.Values | ForEach-Object { $_ })) {
        if ($expectedCodexServers -notcontains $name -and $codexContent -match "(?m)^\[mcp_servers\.$([regex]::Escape($name))\]$") { Fail "Unexpected Codex profile $profileName server: $name" }
    }
    if ($codexContent -match '(?i)@latest') { Fail "Codex profile $profileName must not contain @latest" }
    if (-not $IsNormalizedV1 -and $codexContent -match '(?i)\bnpx(?:\.cmd)?\b') { Fail "Codex profile $profileName must not contain npx" }

    $grokContent = [string](Get-Content -Raw -Encoding UTF8 -LiteralPath $grokPath)
    foreach ($definition in $grokDefinitions) {
        $definitionName = [string]$definition.Name
        foreach ($marker in @("# >>> ai-config-hub managed mcp: $definitionName", "# <<< ai-config-hub managed mcp: $definitionName")) {
            if (-not $grokContent.Contains($marker)) { Fail "Missing Grok profile $profileName marker: $marker" }
        }
        foreach ($serverName in @($sourceServerNamesByDefinition[$definitionName])) {
            if ([regex]::Matches($grokContent, "(?m)^\[mcp_servers\.$([regex]::Escape($serverName))\]$").Count -ne 1) { Fail "Grok profile $profileName must contain one server section for $serverName" }
            if (-not ($grokContent -match "(?ms)\[mcp_servers\.$([regex]::Escape($serverName))\].*?startup_timeout_sec\s*=")) {
                Fail "Grok profile $profileName must set startup_timeout_sec for $serverName"
            }
            if ($serverName -eq 'playwright' -and $grokContent -notmatch '--headless') {
                Fail "Grok profile $profileName playwright must default to --headless"
            }
        }
    }
    foreach ($name in @($sourceServerNamesByDefinition.Values | ForEach-Object { $_ })) {
        if ($expectedGrokServers -notcontains $name -and $grokContent -match "(?m)^\[mcp_servers\.$([regex]::Escape($name))\]$") { Fail "Unexpected Grok profile $profileName server: $name" }
    }
    if ($grokContent -match '(?i)@latest') { Fail "Grok profile $profileName must not contain @latest" }
    if (-not $IsNormalizedV1 -and $grokContent -match '(?i)\bnpx(?:\.cmd)?\b') { Fail "Grok profile $profileName must not contain npx" }
    # Grok rendered fragments must be UTF-8 without BOM
    $grokBytes = [System.IO.File]::ReadAllBytes($grokPath)
    if ($grokBytes.Length -ge 3 -and $grokBytes[0] -eq 0xEF -and $grokBytes[1] -eq 0xBB -and $grokBytes[2] -eq 0xBF) {
        Fail "Grok profile $profileName rendered TOML must not contain UTF-8 BOM"
    }
}

$scanFiles = Get-AiConfigHubScanFiles -Paths @(
    (Join-Path $Root 'tool-configs\mcp'),
    (Join-Path $Root 'tools\browser-mcp-runtime'),
    (Join-Path $Root 'scripts\render-mcp.ps1'),
    (Join-Path $Root 'scripts\check-mcp.ps1'),
    (Join-Path $Root 'scripts\mcp-local.ps1'),
    (Join-Path $Root 'scripts\mcp-doctor.ps1'),
    (Join-Path $Root 'scripts\sync-mcp.ps1'),
    (Join-Path $Root 'scripts\sync-opencode-mcp.ps1'),
    (Join-Path $Root 'scripts\sync-browser-mcp-runtime.ps1')
) -Root $Root
foreach ($file in $scanFiles) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    if ($file.FullName.StartsWith((Join-Path $Root 'tool-configs'), [StringComparison]::OrdinalIgnoreCase) -and $content -match '\{\{[^}]+\}\}') { Fail "Unresolved template placeholder in $($file.FullName)" }
}
Test-AiConfigHubSensitiveContent -Files $scanFiles -Fail ${function:Fail}

if ($Failed) { exit 1 }
Write-Output 'MCP check passed'
