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
$ManagedServers = @('chrome-devtools', 'playwright')
$StartMarker = '# >>> ai-config-hub managed mcp: browser-visual'
$EndMarker = '# <<< ai-config-hub managed mcp: browser-visual'

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

function Get-PropertyNames($Object) {
    if ($null -eq $Object) {
        return @()
    }

    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function ConvertTo-StableJson($Object) {
    return ($Object | ConvertTo-Json -Depth 32) + "`n"
}

function Get-ClaudeMergedContent($TargetPath, $SourcePath) {
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
        if ($ManagedServers -notcontains $serverName) {
            $actions.Add("preserve mcpServers.$serverName")
        }
    }

    foreach ($serverName in $ManagedServers) {
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

    return [pscustomobject]@{
        Content = if ($managedChanged -or -not $targetExists) { ConvertTo-StableJson $target } else { $targetContent }
        Actions = @($actions)
        Changed = $managedChanged -or -not $targetExists
    }
}

function Get-SectionPattern($SectionName) {
    return "(?ms)^\[$([regex]::Escape($SectionName))\]\r?\n.*?(?=^\[[^\]]+\]\r?\n|^# >>> ai-config-hub managed mcp:|\z)"
}

function Get-CodexMergedContent($TargetPath, $SourcePath) {
    $sourceBlock = (Get-Content -Raw -Encoding UTF8 -LiteralPath $SourcePath).TrimEnd() + "`n"
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

    $start = [regex]::Escape($StartMarker)
    $end = [regex]::Escape($EndMarker)
    $markerPattern = "(?ms)^$start\r?\n.*?^$end\r?\n?"
    $markerMatches = [regex]::Matches($targetContent, $markerPattern)

    if ($markerMatches.Count -gt 1) {
        throw "Multiple ai-config-hub managed MCP blocks found in $TargetPath. Please clean up manually."
    }

    if ($markerMatches.Count -eq 1) {
        $actions.Add('replace managed browser-visual MCP block')
        $merged = [regex]::Replace($targetContent, $markerPattern, $sourceBlock, 1)
        $content = $merged.TrimEnd() + "`n"
        return [pscustomobject]@{
            Content = $content
            Actions = @($actions)
            Changed = $content -ne $targetContent
        }
    }

    $working = $targetContent
    foreach ($serverName in $ManagedServers) {
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

    $actions.Add('append managed browser-visual MCP block')
    $mergedContent = $working.TrimEnd()
    if ([string]::IsNullOrWhiteSpace($mergedContent)) {
        $mergedContent = $sourceBlock.TrimEnd()
    }
    else {
        $mergedContent = $mergedContent + "`n`n" + $sourceBlock.TrimEnd()
    }

    $content = $mergedContent + "`n"
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
