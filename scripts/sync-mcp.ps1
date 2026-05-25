[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$ClaudeCode,
    [switch]$Codex
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$RenderedRoot = Join-Path $Root 'tool-configs\mcp\rendered'
$ClaudeSource = Join-Path $RenderedRoot 'claude-code.mcp.json'
$CodexSource = Join-Path $RenderedRoot 'codex.mcp.toml'
$UserHome = [Environment]::GetFolderPath('UserProfile')
$ClaudeTarget = Join-Path $UserHome '.claude.json'
$CodexTarget = Join-Path $UserHome '.codex\config.toml'
. (Join-Path $PSScriptRoot 'mcp-local.ps1')
$McpGroups = @(
    @{
        Name = 'browser-visual'
        Servers = @('chrome-devtools', 'playwright')
    },
    @{
        Name = 'context-thread'
        Servers = @('context-thread')
        LegacyServers = @()
    }
)
$LocalMcpServers = @('pencil')

if (-not $ClaudeCode -and -not $Codex) {
    $ClaudeCode = $true
    $Codex = $true
}

if ($ClaudeCode -and -not (Test-Path -LiteralPath $ClaudeSource)) {
    throw "Missing rendered MCP source: $ClaudeSource. Run scripts\render-mcp.ps1 first."
}

if ($Codex -and -not (Test-Path -LiteralPath $CodexSource)) {
    throw "Missing rendered MCP source: $CodexSource. Run scripts\render-mcp.ps1 first."
}

function Get-ManagedServers() {
    $servers = New-Object System.Collections.Generic.List[string]
    foreach ($group in $McpGroups) {
        foreach ($serverName in $group.Servers) {
            $servers.Add($serverName)
        }
        foreach ($serverName in $group.LegacyServers) {
            $servers.Add($serverName)
        }
    }
    return @($servers)
}

function Get-ActiveManagedServers() {
    $servers = New-Object System.Collections.Generic.List[string]
    foreach ($group in $McpGroups) {
        foreach ($serverName in $group.Servers) {
            $servers.Add($serverName)
        }
    }
    return @($servers)
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

function Test-ContextThreadRuntime() {
    $sourcePath = Join-Path $Root 'tool-configs\mcp\shared\context-thread.json'
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        Write-Warning "context-thread MCP source was not found: $sourcePath"
        return
    }

    try {
        $source = Get-Content -Raw -Encoding UTF8 -LiteralPath $sourcePath | ConvertFrom-Json
        $server = $source.servers.'context-thread'
        if ($null -eq $server -or [string]::IsNullOrWhiteSpace($server.runtime_entry)) {
            Write-Warning 'context-thread MCP source has no runtime_entry.'
            return
        }

        $runtimeEntry = Resolve-UserPath ([string]$server.runtime_entry)
        if (-not (Test-Path -LiteralPath $runtimeEntry)) {
            Write-Warning "context-thread runtime entry was not found at $runtimeEntry. Run scripts\sync-context-thread-runtime.ps1 -Apply before starting context-thread MCP."
        }
    }
    catch {
        Write-Warning "Could not inspect context-thread runtime entry: $($_.Exception.Message)"
    }
}

function Get-PropertyNames($Object) {
    if ($null -eq $Object) {
        return @()
    }

    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function ConvertTo-StableJson($Object) {
    return ($Object | ConvertTo-Json -Depth 32) + "`n"
}

function Get-PencilMcpServerObject($AgentName) {
    $server = Resolve-AiConfigHubPencilMcpServer
    if ($null -eq $server) {
        return $null
    }

    return [pscustomobject]@{
        type = 'stdio'
        command = $server.Command
        args = @('--app', $server.App, '--agent', $AgentName)
    }
}

function Get-ClaudeMergedContent($TargetPath, $SourcePath) {
    $managedServers = Get-ManagedServers
    $activeManagedServers = Get-ActiveManagedServers
    $source = Get-Content -Raw -Encoding UTF8 -LiteralPath $SourcePath | ConvertFrom-Json
    $sourceServers = $source.mcpServers
    if ($null -eq $sourceServers) {
        throw "Rendered Claude MCP fragment is missing mcpServers."
    }

    $targetExists = Test-Path -LiteralPath $TargetPath
    $targetContent = if ($targetExists) { Get-Content -Raw -Encoding UTF8 -LiteralPath $TargetPath } else { '' }
    if ($targetExists) {
        $target = $targetContent | ConvertFrom-Json
    }
    else {
        $target = [pscustomobject]@{}
    }

    if ($null -eq $target.mcpServers) {
        $target | Add-Member -MemberType NoteProperty -Name 'mcpServers' -Value ([pscustomobject]@{})
    }

    $managedChanged = $false
    $actions = New-Object System.Collections.Generic.List[string]
    $existingNames = Get-PropertyNames $target.mcpServers
    foreach ($serverName in $existingNames) {
        if ($managedServers -notcontains $serverName -and $LocalMcpServers -notcontains $serverName) {
            $actions.Add("preserve mcpServers.$serverName")
        }
    }

    foreach ($serverName in $managedServers) {
        if ($activeManagedServers -notcontains $serverName) {
            if ($existingNames -contains $serverName) {
                $target.mcpServers.PSObject.Properties.Remove($serverName)
                $actions.Add("remove legacy mcpServers.$serverName")
                $managedChanged = $true
            }
            continue
        }

        $existingServer = $target.mcpServers.$serverName
        $newServer = $sourceServers.$serverName
        if ($null -eq $newServer) {
            throw "Rendered Claude MCP fragment is missing managed server: $serverName"
        }

        $action = if ($null -eq $existingServer) { 'add' } else { 'update' }
        if ($null -ne $existingServer) {
            $existingJson = $existingServer | ConvertTo-Json -Depth 16 -Compress
            $newJson = $newServer | ConvertTo-Json -Depth 16 -Compress
            if ($existingJson -eq $newJson) {
                $action = 'unchanged'
            }
        }

        if ($action -ne 'unchanged') {
            $managedChanged = $true
        }
        $actions.Add("$action mcpServers.$serverName")

        if ($existingNames -contains $serverName) {
            $target.mcpServers.PSObject.Properties.Remove($serverName)
        }
        $target.mcpServers | Add-Member -MemberType NoteProperty -Name $serverName -Value $newServer
    }

    if ($existingNames -contains 'pencil') {
        $actions.Add('preserve local mcpServers.pencil')
    }
    else {
        $pencilServer = Get-PencilMcpServerObject 'claudeCode'
        if ($null -eq $pencilServer) {
            Write-Warning 'Pencil MCP server was not found locally; sync-mcp will not add mcpServers.pencil. Install Pencil Desktop or Pencil MCP support before using pencil-design-workflow.'
        }
        else {
            $target.mcpServers | Add-Member -MemberType NoteProperty -Name 'pencil' -Value $pencilServer
            $actions.Add("add local mcpServers.pencil ($($pencilServer.command))")
            $managedChanged = $true
        }
    }

    return [pscustomobject]@{
        Content = if ($managedChanged -or -not $targetExists) { ConvertTo-StableJson $target } else { $targetContent }
        Actions = @($actions)
        Changed = $managedChanged -or -not $targetExists
    }
}

function Get-SectionPattern($SectionName) {
    return "(?ms)^\[$([regex]::Escape($SectionName))\]\r?\n.*?(?=^\[[^\]]+\]\r?\n|^# >>> ai-config-hub managed mcp:|\z)"
}

function Get-CodexGroupBlock($Content, $GroupName) {
    $startMarker = "# >>> ai-config-hub managed mcp: $GroupName"
    $endMarker = "# <<< ai-config-hub managed mcp: $GroupName"
    $start = [regex]::Escape($startMarker)
    $end = [regex]::Escape($endMarker)
    $markerPattern = "(?ms)^$start\r?\n.*?^$end\r?\n?"
    $matches = [regex]::Matches($Content, $markerPattern)
    if ($matches.Count -ne 1) {
        throw "Rendered Codex MCP fragment must contain exactly one $GroupName block."
    }
    return $matches[0].Value.TrimEnd()
}

function Format-TomlString($Value) {
    return '"' + ([string]$Value -replace '\\', '\\' -replace '"', '\"') + '"'
}

function Format-TomlStringArray($Values) {
    $quoted = @($Values) | ForEach-Object { Format-TomlString $_ }
    return '[' + ($quoted -join ', ') + ']'
}

function New-CodexPencilMcpBlock {
    $server = Resolve-AiConfigHubPencilMcpServer
    if ($null -eq $server) {
        return $null
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('[mcp_servers.pencil]')
    $lines.Add('command = ' + (Format-TomlString $server.Command))
    $lines.Add('args = ' + (Format-TomlStringArray @('--app', $server.App, '--agent', 'codexCLI')))
    $lines.Add("startup_timeout_ms = $($server.StartupTimeoutMs)")
    return ($lines -join "`n")
}

function Get-CodexMergedContent($TargetPath, $SourcePath) {
    $sourceContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $SourcePath
    $targetContent = if (Test-Path -LiteralPath $TargetPath) {
        Get-Content -Raw -Encoding UTF8 -LiteralPath $TargetPath
    }
    else {
        ''
    }

    $actions = New-Object System.Collections.Generic.List[string]
    if ($targetContent -match '(?m)^\[mcp_servers\.pencil\]$') {
        $actions.Add('preserve mcp_servers.pencil')
    }

    $working = $targetContent
    $newBlocks = New-Object System.Collections.Generic.List[string]

    foreach ($group in $McpGroups) {
        $sourceBlock = Get-CodexGroupBlock $sourceContent $group.Name
        $newBlocks.Add($sourceBlock)

        $startMarker = "# >>> ai-config-hub managed mcp: $($group.Name)"
        $endMarker = "# <<< ai-config-hub managed mcp: $($group.Name)"
        $start = [regex]::Escape($startMarker)
        $end = [regex]::Escape($endMarker)
        $markerPattern = "(?ms)^$start\r?\n.*?^$end\r?\n?"
        $markerMatches = [regex]::Matches($working, $markerPattern)

        if ($markerMatches.Count -gt 1) {
            throw "Multiple $($group.Name) MCP blocks found in $TargetPath. Please clean up manually."
        }

        if ($markerMatches.Count -eq 1) {
            $actions.Add("replace managed $($group.Name) MCP block")
            $working = [regex]::Replace($working, $markerPattern, '', 1)
        }
        else {
            $groupServerNames = @($group.Servers) + @($group.LegacyServers)
            foreach ($serverName in $groupServerNames) {
                foreach ($section in @("mcp_servers.$serverName", "mcp_servers.$serverName.env")) {
                    $pattern = Get-SectionPattern $section
                    $sectionMatches = [regex]::Matches($working, $pattern)
                    if ($sectionMatches.Count -gt 1) {
                        throw "Multiple unmanaged [$section] sections found in $TargetPath. Please clean up manually."
                    }
                    elseif ($sectionMatches.Count -eq 1) {
                        $actions.Add("replace unmanaged $section")
                        $working = [regex]::Replace($working, $pattern, '', 1)
                    }
                }
            }
        }
    }

    if ($working -notmatch '(?m)^\[mcp_servers\.pencil\]$') {
        $pencilBlock = New-CodexPencilMcpBlock
        if ($null -eq $pencilBlock) {
            Write-Warning 'Pencil MCP server was not found locally; sync-mcp will not add [mcp_servers.pencil]. Install Pencil Desktop or Pencil MCP support before using pencil-design-workflow.'
        }
        else {
            $actions.Add('add local mcp_servers.pencil')
            if ([string]::IsNullOrWhiteSpace($working)) {
                $working = $pencilBlock + "`n"
            }
            else {
                $working = $working.TrimEnd() + "`n`n" + $pencilBlock + "`n"
            }
        }
    }

    foreach ($group in $McpGroups) {
        $actions.Add("append managed $($group.Name) MCP block")
    }

    $managedBlock = ($newBlocks -join "`n`n").TrimEnd()
    $mergedContent = $working.TrimEnd()
    if ([string]::IsNullOrWhiteSpace($mergedContent)) {
        $mergedContent = $managedBlock
    }
    else {
        $mergedContent = $mergedContent + "`n`n" + $managedBlock
    }

    $content = $mergedContent.TrimEnd() + "`n"
    return [pscustomobject]@{
        Content = $content
        Actions = @($actions)
        Changed = $content -ne $targetContent
    }
}

function Sync-File($Name, $TargetPath, $Merged) {
    $targetExists = Test-Path -LiteralPath $TargetPath
    $targetContent = if ($targetExists) { Get-Content -Raw -Encoding UTF8 -LiteralPath $TargetPath } else { '' }
    $hasSemanticChange = if ($null -ne $Merged.PSObject.Properties['Changed']) { [bool]$Merged.Changed } else { $targetContent -ne $Merged.Content }
    $status = if (-not $targetExists) { 'missing target' } elseif (-not $hasSemanticChange) { 'unchanged' } else { 'would update' }

    if (-not $Apply) {
        Write-Output "$status`t$Name`t$TargetPath"
        foreach ($action in $Merged.Actions) {
            Write-Output "  - $action"
        }
        return
    }

    if ($targetExists -and -not $hasSemanticChange) {
        Write-Output "Unchanged: $Name`t$TargetPath"
        foreach ($action in $Merged.Actions) {
            Write-Output "  - $action"
        }
        return
    }

    $targetDir = Split-Path -Parent $TargetPath
    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    if ($targetExists) {
        if ($Name -eq 'claude-code') {
            $backupRoot = Join-Path $UserHome '.claude\ai-config-hub-config-backups'
            $backupName = ".claude.json.$timestamp.bak"
        }
        else {
            $backupRoot = Join-Path $UserHome '.codex\ai-config-hub-config-backups'
            $backupName = "config.toml.$timestamp.bak"
        }

        if (-not (Test-Path -LiteralPath $backupRoot)) {
            New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
        }

        $backupPath = Join-Path $backupRoot $backupName
        Copy-Item -LiteralPath $TargetPath -Destination $backupPath -Force
        Write-Output "Backup created: $backupPath"
    }

    Set-Content -Encoding UTF8 -LiteralPath $TargetPath -Value $Merged.Content -NoNewline
    Write-Output "Synced: $Name`t$TargetPath"
    foreach ($action in $Merged.Actions) {
        Write-Output "  - $action"
    }
}

Test-ContextThreadRuntime

if (-not $Apply) {
    Write-Output 'Dry run only. Re-run with -Apply to merge managed MCP fragments after backups.'
}

if ($ClaudeCode) {
    $merged = Get-ClaudeMergedContent $ClaudeTarget $ClaudeSource
    Sync-File 'claude-code' $ClaudeTarget $merged
}

if ($Codex) {
    $merged = Get-CodexMergedContent $CodexTarget $CodexSource
    Sync-File 'codex' $CodexTarget $merged
}
