$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$SourcePath = Join-Path $Root 'tool-configs\mcp\shared\browser-visual.json'
$RenderedRoot = Join-Path $Root 'tool-configs\mcp\rendered'
$ClaudeOutput = Join-Path $RenderedRoot 'claude-code.mcp.json'
$CodexOutput = Join-Path $RenderedRoot 'codex.mcp.toml'
$RequiredServers = @('chrome-devtools', 'playwright')
$StartMarker = '# >>> ai-config-hub managed mcp: browser-visual'
$EndMarker = '# <<< ai-config-hub managed mcp: browser-visual'

function Write-Text($Path, $Content) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    Set-Content -Encoding UTF8 -Path $Path -Value $Content -NoNewline
}

if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "Missing MCP source: $SourcePath"
}

$source = Get-Content -Raw -Encoding UTF8 -LiteralPath $SourcePath | ConvertFrom-Json
if ($null -eq $source.servers) {
    throw "Missing servers object in $SourcePath"
}

foreach ($serverName in $RequiredServers) {
    $server = $source.servers.$serverName
    if ($null -eq $server) {
        throw "Missing required MCP server: $serverName"
    }

    if ([string]::IsNullOrWhiteSpace($server.command)) {
        throw "Missing command for MCP server: $serverName"
    }

    if ($null -eq $server.args -or $server.args.Count -eq 0) {
        throw "Missing args for MCP server: $serverName"
    }
}

$claudeServers = [ordered]@{}
foreach ($serverName in $RequiredServers) {
    $server = $source.servers.$serverName
    $claudeServers[$serverName] = [ordered]@{
        command = [string]$server.command
        args = @($server.args)
    }
}

$claudeFragment = [ordered]@{
    mcpServers = $claudeServers
}
$claudeJson = ($claudeFragment | ConvertTo-Json -Depth 8) + "`n"
Write-Text $ClaudeOutput $claudeJson

$codexLines = New-Object System.Collections.Generic.List[string]
$codexLines.Add($StartMarker)
foreach ($serverName in $RequiredServers) {
    $server = $source.servers.$serverName
    $codexLines.Add("")
    $codexLines.Add("[mcp_servers.$serverName]")
    $codexLines.Add('command = "cmd"')

    $args = @('/c', [string]$server.command) + @($server.args)
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
$codexLines.Add($EndMarker)
$codexToml = ($codexLines -join "`n") + "`n"
Write-Text $CodexOutput $codexToml

Write-Output "Rendered MCP config fragments:"
Write-Output "- $ClaudeOutput"
Write-Output "- $CodexOutput"
