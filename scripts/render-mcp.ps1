[CmdletBinding()]
param(
    [switch]$Check,
    [string[]]$Profile
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'
. (Join-Path $PSScriptRoot 'lib\managed-assets.ps1')
$Manifest = Import-AiConfigHubManagedAssetsManifest $ManifestPath

function Write-Text($Path, $Content) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, [string]$Content, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-PropertyNames($Object) {
    if ($null -eq $Object) { return @() }
    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Get-ServerArgs($Server) {
    $serverArgs = @($Server.args)
    if (-not [string]::IsNullOrWhiteSpace([string]$Server.runtime_entry)) {
        $serverArgs += @([string]$Server.runtime_entry)
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$Server.repo_script)) {
        $serverArgs += @(Join-Path $Root ([string]$Server.repo_script))
    }
    if ($null -ne $Server.script_args) {
        $serverArgs += @($Server.script_args)
    }
    return @($serverArgs)
}

function Test-PinnedPackage($ServerName, $Server, $SourcePath) {
    $package = [string]$Server.package
    if ([string]::IsNullOrWhiteSpace($package)) {
        foreach ($argument in @(Get-ServerArgs $Server)) {
            if ([string]$argument -match '(?i)@latest(?:$|\s)') {
                throw "MCP args must not use @latest for $ServerName in $SourcePath"
            }
        }
        return
    }
    if ($package -match '(?i)@latest(?:$|\s)' -or
        $package -notmatch '^(@[^/]+/[^@]+|[^@]+)@\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
        throw "MCP package must use an exact semver for $ServerName in $SourcePath`: $package"
    }
}

function Read-McpSource($Definition) {
    $sourcePath = Join-Path $Root ([string]$Definition.Source)
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing MCP source: $sourcePath"
    }
    $source = Get-Content -Raw -Encoding UTF8 -LiteralPath $sourcePath | ConvertFrom-Json
    $serverNames = @(Get-PropertyNames $source.servers)
    if ($serverNames.Count -eq 0) {
        throw "MCP source has no servers: $sourcePath"
    }
    if ($null -eq $Manifest.SourceSchemaVersion -and ($serverNames.Count -ne 1 -or $serverNames[0] -ne [string]$Definition.Name)) {
        throw "Schema v2 MCP source must define exactly server '$($Definition.Name)': $sourcePath"
    }

    foreach ($serverName in $serverNames) {
        $server = $source.servers.$serverName
        if ([string]::IsNullOrWhiteSpace([string]$server.command)) {
            throw "Missing command for MCP server $serverName in $sourcePath"
        }
        if (@(Get-ServerArgs $server).Count -eq 0) {
            throw "Missing args for MCP server $serverName in $sourcePath"
        }
        Test-PinnedPackage $serverName $server $sourcePath
        if (-not [string]::IsNullOrWhiteSpace([string]$server.repo_script)) {
            $scriptPath = Join-Path $Root ([string]$server.repo_script)
            if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
                throw "Missing repo_script for MCP server $serverName`: $scriptPath"
            }
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$server.runtime_entry)) {
            $runtimeEntry = [string]$server.runtime_entry
            if (-not ($runtimeEntry.StartsWith('~\') -or $runtimeEntry.StartsWith('~/')) -or
                $runtimeEntry -match '(^|[\\/])\.\.([\\/]|$)') {
                throw "runtime_entry for MCP server $serverName must stay under the user profile: $runtimeEntry"
            }
        }
    }
    return $source
}

function Format-TomlString($Value) {
    return '"' + ([string]$Value).Replace('\', '\\').Replace('"', '\"') + '"'
}

function Test-ExpectedOutput($Path, $Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ Matches = $false; Message = "ERROR: Missing rendered MCP target: $Path" }
    }
    $actual = [string](Get-Content -Raw -Encoding UTF8 -LiteralPath $Path)
    $expectedText = [string]$Expected
    if ($actual -ne $expectedText) {
        return [pscustomobject]@{ Matches = $false; Message = "ERROR: Rendered MCP target is out of date: $Path" }
    }
    return [pscustomobject]@{ Matches = $true; Message = "Verified $Path" }
}

$sourceByDefinition = @{}
foreach ($definition in @($Manifest.Mcp.Servers)) {
    $sourceByDefinition[[string]$definition.Name] = Read-McpSource $definition
}

$profileNames = if ($null -eq $Profile -or $Profile.Count -eq 0) {
    Get-AiConfigHubMcpProfileNames $Manifest
}
else {
    @($Profile)
}
$results = New-Object System.Collections.Generic.List[object]

foreach ($profileName in $profileNames) {
    $profileDefinition = Get-AiConfigHubMcpProfile $Manifest $profileName
    $claudeServers = [ordered]@{}
    foreach ($definition in Get-AiConfigHubMcpServerDefinitionsForProfile $Manifest $profileDefinition 'ClaudeCode') {
        $source = $sourceByDefinition[[string]$definition.Name]
        foreach ($serverName in Get-PropertyNames $source.servers) {
            if ($claudeServers.Contains($serverName)) {
                throw "Duplicate Claude MCP server in profile $profileName`: $serverName"
            }
            $server = $source.servers.$serverName
            $entry = [ordered]@{}
            if (-not [string]::IsNullOrWhiteSpace([string]$server.type)) { $entry.type = [string]$server.type }
            $entry.command = [string]$server.command
            $entry.args = @(Get-ServerArgs $server)
            $claudeServers[$serverName] = $entry
        }
    }
    $claudeJson = ([ordered]@{ mcpServers = $claudeServers } | ConvertTo-Json -Depth 8) + "`n"
    $claudeOutput = Get-AiConfigHubMcpRenderedPath $Root $Manifest 'ClaudeCode' $profileName

    $codexLines = New-Object System.Collections.Generic.List[string]
    foreach ($definition in Get-AiConfigHubMcpServerDefinitionsForProfile $Manifest $profileDefinition 'Codex') {
        $source = $sourceByDefinition[[string]$definition.Name]
        if ($codexLines.Count -gt 0) { $codexLines.Add('') }
        $codexLines.Add("# >>> ai-config-hub managed mcp: $($definition.Name)")
        foreach ($serverName in Get-PropertyNames $source.servers) {
            $server = $source.servers.$serverName
            $codexLines.Add('')
            $codexLines.Add("[mcp_servers.$serverName]")
            $codexLines.Add('command = "cmd"')
            $args = @('/c', [string]$server.command) + @(Get-ServerArgs $server)
            $quotedArgs = $args | ForEach-Object { Format-TomlString $_ }
            $codexLines.Add('args = [' + ($quotedArgs -join ', ') + ']')
            if ($null -ne $server.startup_timeout_ms) {
                $codexLines.Add("startup_timeout_ms = $($server.startup_timeout_ms)")
            }
            $codexLines.Add('')
            $codexLines.Add("[mcp_servers.$serverName.env]")
            $codexLines.Add('SystemRoot = "C:\\Windows"')
            $codexLines.Add('PROGRAMFILES = "C:\\Program Files"')
        }
        $codexLines.Add('')
        $codexLines.Add("# <<< ai-config-hub managed mcp: $($definition.Name)")
    }
    $codexToml = if ($codexLines.Count -eq 0) { "# ai-config-hub managed mcp profile: $profileName (no Codex servers)`n" } else { ($codexLines -join "`n") + "`n" }
    $codexOutput = Get-AiConfigHubMcpRenderedPath $Root $Manifest 'Codex' $profileName

    $grokLines = New-Object System.Collections.Generic.List[string]
    foreach ($definition in Get-AiConfigHubMcpServerDefinitionsForProfile $Manifest $profileDefinition 'Grok') {
        $source = $sourceByDefinition[[string]$definition.Name]
        if ($grokLines.Count -gt 0) { $grokLines.Add('') }
        $grokLines.Add("# >>> ai-config-hub managed mcp: $($definition.Name)")
        foreach ($serverName in Get-PropertyNames $source.servers) {
            $server = $source.servers.$serverName
            $args = @(Get-ServerArgs $server)
            # Grok Playwright defaults to headless; Claude/Codex keep shared source behavior.
            if ($serverName -eq 'playwright' -and ($args -notcontains '--headless')) {
                $args = @($args) + @('--headless')
            }
            $startupSec = 20
            if ($null -ne $server.startup_timeout_ms) {
                $startupSec = [Math]::Max(20, [int][Math]::Ceiling(([double]$server.startup_timeout_ms) / 1000.0))
            }
            $grokLines.Add('')
            $grokLines.Add("[mcp_servers.$serverName]")
            $grokLines.Add('command = ' + (Format-TomlString ([string]$server.command)))
            $quotedArgs = $args | ForEach-Object { Format-TomlString $_ }
            $grokLines.Add('args = [' + ($quotedArgs -join ', ') + ']')
            $grokLines.Add('enabled = true')
            $grokLines.Add("startup_timeout_sec = $startupSec")
        }
        $grokLines.Add('')
        $grokLines.Add("# <<< ai-config-hub managed mcp: $($definition.Name)")
    }
    $grokToml = if ($grokLines.Count -eq 0) { "# ai-config-hub managed mcp profile: $profileName (no Grok servers)`n" } else { ($grokLines -join "`n") + "`n" }
    $grokOutput = Get-AiConfigHubMcpRenderedPath $Root $Manifest 'Grok' $profileName

    if ($Check) {
        $results.Add((Test-ExpectedOutput $claudeOutput $claudeJson)) | Out-Null
        $results.Add((Test-ExpectedOutput $codexOutput $codexToml)) | Out-Null
        $results.Add((Test-ExpectedOutput $grokOutput $grokToml)) | Out-Null
    }
    else {
        Write-Text $claudeOutput $claudeJson
        Write-Text $codexOutput $codexToml
        Write-Text $grokOutput $grokToml
        Write-Output "Rendered MCP profile $profileName`:"
        Write-Output "- $claudeOutput"
        Write-Output "- $codexOutput"
        Write-Output "- $grokOutput"
    }
}

if ($Check) {
    $failed = $false
    foreach ($result in $results) {
        Write-Output $result.Message
        if (-not $result.Matches) { $failed = $true }
    }
    if ($failed) {
        throw 'MCP render check failed. Run scripts\render-mcp.ps1 to refresh rendered fragments.'
    }
}
