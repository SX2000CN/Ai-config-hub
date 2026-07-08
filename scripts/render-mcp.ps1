$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$RenderedRoot = Join-Path $Root 'tool-configs\mcp\rendered'
$ClaudeOutput = Join-Path $RenderedRoot 'claude-code.mcp.json'
$CodexOutput = Join-Path $RenderedRoot 'codex.mcp.toml'
$McpGroups = @(
    @{
        Name = 'browser-visual'
        SourcePath = Join-Path $Root 'tool-configs\mcp\shared\browser-visual.json'
        RequiredServers = @('chrome-devtools', 'playwright')
    },
    @{
        Name = 'context-thread'
        SourcePath = Join-Path $Root 'tool-configs\mcp\shared\context-thread.json'
        RequiredServers = @('context-thread')
    },
    @{
        Name = 'local-webfetch'
        SourcePath = Join-Path $Root 'tool-configs\mcp\shared\local-webfetch.json'
        RequiredServers = @('local-webfetch')
        Targets = @('ClaudeCode')
    }
)

function Test-GroupTargetsTool($Group, $ToolName) {
    if ($null -eq $Group.Targets -or @($Group.Targets).Count -eq 0) { return $true }
    return @($Group.Targets) -contains $ToolName
}

function Write-Text($Path, $Content) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    Set-Content -Encoding UTF8 -Path $Path -Value $Content -NoNewline
}

function Get-PropertyNames($Object) {
    if ($null -eq $Object) {
        return @()
    }

    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Get-ServerArgs($Server) {
    $args = @($Server.args)
    if ($null -ne $Server.runtime_entry -and -not [string]::IsNullOrWhiteSpace($Server.runtime_entry)) {
        $args += @(Resolve-UserPath ([string]$Server.runtime_entry))
    }

    if ($null -ne $Server.repo_script -and -not [string]::IsNullOrWhiteSpace($Server.repo_script)) {
        $scriptPath = Join-Path $Root ([string]$Server.repo_script)
        $args += @($scriptPath)
    }

    if ($null -ne $Server.script_args) {
        $args += @($Server.script_args)
    }

    return @($args)
}

function Resolve-UserPath($Path) {
    $text = [string]$Path
    if ($text -eq '~') {
        return [Environment]::GetFolderPath('UserProfile')
    }

    if ($text.StartsWith('~\') -or $text.StartsWith('~/')) {
        return Join-Path ([Environment]::GetFolderPath('UserProfile')) $text.Substring(2)
    }

    return $text
}

function Read-McpGroup($Group) {
    $sourcePath = $Group.SourcePath
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Missing MCP source: $sourcePath"
    }

    $source = Get-Content -Raw -Encoding UTF8 -LiteralPath $sourcePath | ConvertFrom-Json
    if ($null -eq $source.servers) {
        throw "Missing servers object in $sourcePath"
    }

    $sourceNames = Get-PropertyNames $source.servers
    foreach ($serverName in $Group.RequiredServers) {
        $server = $source.servers.$serverName
        if ($null -eq $server) {
            throw "Missing required MCP server: $serverName"
        }

        if ([string]::IsNullOrWhiteSpace($server.command)) {
            throw "Missing command for MCP server: $serverName"
        }

        if (@(Get-ServerArgs $server).Count -eq 0) {
            throw "Missing args for MCP server: $serverName"
        }

        if ($null -ne $server.repo_script -and -not [string]::IsNullOrWhiteSpace($server.repo_script)) {
            $scriptPath = Join-Path $Root ([string]$server.repo_script)
            if (-not (Test-Path -LiteralPath $scriptPath)) {
                throw "Missing repo_script for MCP server $serverName`: $scriptPath"
            }
        }

        if ($null -ne $server.runtime_entry -and -not [string]::IsNullOrWhiteSpace($server.runtime_entry)) {
            $runtimeEntry = Resolve-UserPath ([string]$server.runtime_entry)
            if (-not [System.IO.Path]::IsPathRooted($runtimeEntry)) {
                throw "runtime_entry for MCP server $serverName must resolve to an absolute path: $runtimeEntry"
            }
        }
    }

    foreach ($serverName in $sourceNames) {
        if ($Group.RequiredServers -notcontains $serverName) {
            throw "Unexpected MCP server in $sourcePath`: $serverName"
        }
    }

    return $source
}

$groupSources = [ordered]@{}
foreach ($group in $McpGroups) {
    $groupSources[$group.Name] = Read-McpGroup $group
}

$claudeServers = [ordered]@{}
foreach ($group in $McpGroups) {
    if (-not (Test-GroupTargetsTool $group 'ClaudeCode')) { continue }
    $source = $groupSources[$group.Name]
    foreach ($serverName in $group.RequiredServers) {
        $server = $source.servers.$serverName
        $entry = [ordered]@{}

        if ($null -ne $server.type -and -not [string]::IsNullOrWhiteSpace($server.type)) {
            $entry.type = [string]$server.type
        }

        $entry.command = [string]$server.command
        $entry.args = @(Get-ServerArgs $server)
        $claudeServers[$serverName] = $entry
    }
}

$claudeFragment = [ordered]@{
    mcpServers = $claudeServers
}
$claudeJson = ($claudeFragment | ConvertTo-Json -Depth 8) + "`n"
Write-Text $ClaudeOutput $claudeJson

$codexLines = New-Object System.Collections.Generic.List[string]
foreach ($group in $McpGroups) {
    if (-not (Test-GroupTargetsTool $group 'Codex')) { continue }
    $source = $groupSources[$group.Name]
    $startMarker = "# >>> ai-config-hub managed mcp: $($group.Name)"
    $endMarker = "# <<< ai-config-hub managed mcp: $($group.Name)"

    if ($codexLines.Count -gt 0) {
        $codexLines.Add("")
    }

    $codexLines.Add($startMarker)
    foreach ($serverName in $group.RequiredServers) {
        $server = $source.servers.$serverName
        $codexLines.Add("")
        $codexLines.Add("[mcp_servers.$serverName]")
        $codexLines.Add('command = "cmd"')

        $args = @('/c', [string]$server.command) + (Get-ServerArgs $server)
        $quotedArgs = $args | ForEach-Object { '"' + ($_ -replace '\\', '\\' -replace '"', '\"') + '"' }
        $codexLines.Add('args = [' + ($quotedArgs -join ', ') + ']')

        if ($null -ne $server.startup_timeout_ms) {
            $codexLines.Add("startup_timeout_ms = $($server.startup_timeout_ms)")
        }

        $codexLines.Add("")
        $codexLines.Add("[mcp_servers.$serverName.env]")
        $codexLines.Add('SystemRoot = "C:\\Windows"')
        $codexLines.Add('PROGRAMFILES = "C:\\Program Files"')
    }
    $codexLines.Add("")
    $codexLines.Add($endMarker)
}
$codexToml = ($codexLines -join "`n") + "`n"
Write-Text $CodexOutput $codexToml

Write-Output "Rendered MCP config fragments:"
Write-Output "- $ClaudeOutput"
Write-Output "- $CodexOutput"
