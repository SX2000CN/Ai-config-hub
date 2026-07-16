[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$ClaudeCode,
    [switch]$Codex,
    [string]$Profile,
    [switch]$AllowDegraded,
    [string]$UserHome,
    [string]$ClaudeCommand
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'
$RenderedRoot = Join-Path $Root 'tool-configs\mcp\rendered'
. (Join-Path $PSScriptRoot 'lib\deploy.ps1')
. (Join-Path $PSScriptRoot 'mcp-local.ps1')

$Manifest = Import-AiConfigHubManagedAssetsManifest $ManifestPath
$ResolvedUserHome = Resolve-AiConfigHubUserHome $UserHome
$ProfileDefinition = Get-AiConfigHubMcpProfile $Manifest $Profile
$ProfileName = [string]$ProfileDefinition.Name
$ClaudeDefinition = $Manifest.Mcp.Targets | Where-Object { $_.Name -eq 'ClaudeCode' } | Select-Object -First 1
$CodexDefinition = $Manifest.Mcp.Targets | Where-Object { $_.Name -eq 'Codex' } | Select-Object -First 1
if ($null -eq $ClaudeDefinition -or $null -eq $CodexDefinition) {
    throw 'ClaudeCode and Codex MCP targets must be registered in config/managed-assets.psd1.'
}
$ClaudeSource = Get-AiConfigHubMcpRenderedPath $Root $Manifest 'ClaudeCode' $ProfileName
$CodexSource = Get-AiConfigHubMcpRenderedPath $Root $Manifest 'Codex' $ProfileName
$ClaudeTarget = Join-Path $ResolvedUserHome ([string]$ClaudeDefinition.UserRelativePath)
$CodexTarget = Join-Path $ResolvedUserHome ([string]$CodexDefinition.UserRelativePath)
$McpGroups = foreach ($definition in $Manifest.Mcp.Servers) {
    $sourcePath = Join-Path $Root ([string]$definition.Source)
    $sourceObject = Get-Content -Raw -Encoding UTF8 -LiteralPath $sourcePath | ConvertFrom-Json
    [pscustomobject]@{
        Name = [string]$definition.Name
        Source = $sourceObject
        Servers = @($sourceObject.servers.PSObject.Properties | ForEach-Object { $_.Name })
        LegacyServers = @($definition.LegacyServers)
        LegacySignatures = @($definition.LegacySignatures)
        Targets = @($definition.Targets)
        Optional = [bool]$definition.Optional
    }
}
$LocalMcpServers = @($Manifest.Mcp.LocalServers)
$ProfileLocalMcpServers = @($ProfileDefinition.LocalServers)
$ProfileManagedDefinitions = @(Get-AiConfigHubMcpServerDefinitionsForProfile $Manifest $ProfileDefinition)
$ProfileManagedDefinitionNames = @($ProfileManagedDefinitions | ForEach-Object { [string]$_.Name })
$ActiveManagedDefinitionNames = @($ProfileManagedDefinitionNames)

function Test-GroupTargetsTool($Group, $ToolName) {
    if ($null -eq $Group.Targets -or @($Group.Targets).Count -eq 0) { return $true }
    return @($Group.Targets) -contains $ToolName
}

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

function Get-ManagedServers($ToolName) {
    $servers = New-Object System.Collections.Generic.List[string]
    foreach ($group in $McpGroups) {
        if (-not (Test-GroupTargetsTool $group $ToolName)) { continue }
        foreach ($serverName in $group.Servers) {
            $servers.Add($serverName)
        }
        if ($null -ne $group.LegacyServers) {
            foreach ($serverName in $group.LegacyServers) {
                $servers.Add($serverName)
            }
        }
    }
    return @($servers)
}

function Get-ActiveManagedServers($ToolName) {
    $servers = New-Object System.Collections.Generic.List[string]
    foreach ($group in $McpGroups) {
        if ($ActiveManagedDefinitionNames -notcontains $group.Name) { continue }
        if (-not (Test-GroupTargetsTool $group $ToolName)) { continue }
        foreach ($serverName in $group.Servers) {
            $servers.Add($serverName)
        }
    }
    return @($servers)
}

function Resolve-UserPath($Path) {
    $text = [string]$Path
    if ($text -eq '~') {
        return $ResolvedUserHome
    }

    if ($text.StartsWith('~\') -or $text.StartsWith('~/')) {
        return Join-Path $ResolvedUserHome $text.Substring(2)
    }

    return $text
}

function Write-McpReadiness($Readiness) {
    foreach ($item in $Readiness.Items) {
        $status = if ($item.Ready) { 'ready' } elseif ($item.Optional) { 'optional unavailable' } else { 'required unavailable' }
        Write-Output "readiness`t$status`t$($item.Name)`t$($item.Reason)"
    }
    foreach ($conflict in @($Readiness.RoutingConflicts)) {
        Write-Output "routing conflict`t$($conflict.PreferredFor)`t$($conflict.Servers -join ', ')"
    }
}

function Get-ActiveMcpGroups($ToolName) {
    return @($McpGroups | Where-Object {
        $ActiveManagedDefinitionNames -contains $_.Name -and (Test-GroupTargetsTool $_ $ToolName)
    })
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

function Resolve-McpServerUserPaths($Server) {
    $copy = $Server | ConvertTo-Json -Depth 32 | ConvertFrom-Json
    if ($null -ne $copy.command) {
        $copy.command = Resolve-UserPath ([string]$copy.command)
    }
    if ($null -ne $copy.args) {
        $resolvedArgs = foreach ($argument in @($copy.args)) {
            Resolve-UserPath ([string]$argument)
        }
        $copy.args = @($resolvedArgs)
    }
    return $copy
}

function Get-McpGroupForServer($ServerName) {
    return $McpGroups | Where-Object { @($_.Servers) -contains $ServerName -or @($_.LegacyServers) -contains $ServerName } | Select-Object -First 1
}

function New-ClaudeServerFromLegacySignature($Signature) {
    $entry = [ordered]@{}
    if (-not [string]::IsNullOrWhiteSpace([string]$Signature.Type)) { $entry.type = [string]$Signature.Type }
    $entry.command = [string]$Signature.Command
    $entry.args = @($Signature.Args | ForEach-Object { [string]$_ })
    return Resolve-McpServerUserPaths ([pscustomobject]$entry)
}

function Get-CurrentClaudeManagedServer($ServerName) {
    $group = Get-McpGroupForServer $ServerName
    if ($null -eq $group -or $null -eq $group.Source.servers.$ServerName) { return $null }
    $server = $group.Source.servers.$ServerName
    $arguments = @($server.args | ForEach-Object { [string]$_ })
    if (-not [string]::IsNullOrWhiteSpace([string]$server.runtime_entry)) { $arguments += @([string]$server.runtime_entry) }
    if (-not [string]::IsNullOrWhiteSpace([string]$server.repo_script)) { $arguments += @(Join-Path $Root ([string]$server.repo_script)) }
    if ($null -ne $server.script_args) { $arguments += @($server.script_args | ForEach-Object { [string]$_ }) }
    $entry = [ordered]@{}
    if (-not [string]::IsNullOrWhiteSpace([string]$server.type)) { $entry.type = [string]$server.type }
    $entry.command = [string]$server.command
    $entry.args = $arguments
    return Resolve-McpServerUserPaths ([pscustomobject]$entry)
}

function Test-ClaudeManagedOwnership($ServerName, $ExistingServer, $CurrentServer) {
    if ($null -eq $ExistingServer) { return $false }
    if ($null -ne $CurrentServer -and (Test-SameJsonObject $ExistingServer $CurrentServer)) { return $true }
    $group = Get-McpGroupForServer $ServerName
    if ($null -eq $group) { return $false }
    foreach ($signature in @($group.LegacySignatures)) {
        if (Test-SameJsonObject $ExistingServer (New-ClaudeServerFromLegacySignature $signature)) { return $true }
    }
    return $false
}

function Resolve-CodexRenderedUserPaths($Content) {
    $escapedHome = $ResolvedUserHome.Replace('\', '\\')
    return $Content.Replace('~\\', $escapedHome + '\\').Replace('~/', $escapedHome + '\\')
}

function Get-PencilMcpServerObject($AgentName) {
    $server = Resolve-AiConfigHubPencilMcpServer $ResolvedUserHome
    if ($null -eq $server) {
        return $null
    }

    return [pscustomobject]@{
        type = 'stdio'
        command = $server.Command
        args = @('--app', $server.App, '--agent', $AgentName)
    }
}

function Test-ClaudePencilServerUsesDesktop($Server) {
    if ($null -eq $Server) {
        return $false
    }

    $serverArgs = @($Server.args)
    for ($i = 0; $i -lt $serverArgs.Count - 1; $i++) {
        if ([string]$serverArgs[$i] -eq '--app' -and [string]$serverArgs[$i + 1] -eq 'desktop') {
            return $true
        }
    }

    $command = [string]$Server.command
    return $command -match '\\Program Files\\Pencil\\resources\\app\.asar\.unpacked\\out\\mcp-server-windows-x64\.exe$'
}

function Get-ClaudeMergedContent($TargetPath, $SourcePath) {
    $managedServers = Get-ManagedServers 'ClaudeCode'
    $activeManagedServers = Get-ActiveManagedServers 'ClaudeCode'
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
    $conflicts = New-Object System.Collections.Generic.List[string]
    $existingNames = Get-PropertyNames $target.mcpServers
    foreach ($serverName in $existingNames) {
        if ($managedServers -notcontains $serverName -and $LocalMcpServers -notcontains $serverName) {
            $actions.Add("preserve mcpServers.$serverName")
        }
    }

    foreach ($serverName in $managedServers) {
        $existingServer = $target.mcpServers.$serverName
        $currentManagedServer = Get-CurrentClaudeManagedServer $serverName
        $owned = Test-ClaudeManagedOwnership $serverName $existingServer $currentManagedServer
        if ($activeManagedServers -notcontains $serverName) {
            if ($null -ne $existingServer -and $owned) {
                $target.mcpServers.PSObject.Properties.Remove($serverName)
                $actions.Add("remove owned inactive mcpServers.$serverName")
                $managedChanged = $true
            }
            elseif ($null -ne $existingServer) {
                $actions.Add("preserve custom inactive mcpServers.$serverName")
            }
            continue
        }

        $newServer = Resolve-McpServerUserPaths $sourceServers.$serverName
        if ($null -eq $newServer) {
            throw "Rendered Claude MCP fragment is missing managed server: $serverName"
        }
        if ($null -ne $existingServer -and -not $owned) {
            $message = "custom mcpServers.$serverName conflicts with active managed profile $ProfileName"
            $actions.Add("conflict $message")
            $conflicts.Add($message) | Out-Null
            continue
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

    $existingPencil = $target.mcpServers.pencil
    if ($ProfileLocalMcpServers -notcontains 'pencil') {
        if ($null -ne $existingPencil) { $actions.Add('preserve local mcpServers.pencil outside the selected profile') }
    }
    else {
        $pencilServer = Get-PencilMcpServerObject 'claudeCode'
        if ($null -eq $pencilServer) {
            Write-Warning 'Pencil plugin MCP server was not found locally; sync-mcp will not register pencil with Claude Code.'
        }
        elseif ($null -eq $existingPencil) {
            $actions.Add("register local pencil via Claude Code CLI ($($pencilServer.command))")
        }
        else {
            $existingJson = $existingPencil | ConvertTo-Json -Depth 16 -Compress
            $newJson = $pencilServer | ConvertTo-Json -Depth 16 -Compress
            if ($existingJson -eq $newJson) { $actions.Add('pencil already registered by Claude Code CLI') }
            elseif (Test-ClaudePencilServerUsesDesktop $existingPencil) { $actions.Add("replace desktop pencil via Claude Code CLI ($($pencilServer.command))") }
            else { $actions.Add('preserve local mcpServers.pencil') }
        }
    }

    return [pscustomobject]@{
        Content = if ($managedChanged -or -not $targetExists) { ConvertTo-StableJson $target } else { $targetContent }
        Actions = @($actions)
        Conflicts = @($conflicts | ForEach-Object { $_ })
        Changed = $managedChanged -or -not $targetExists
    }
}

function Get-TomlSectionNamePattern($SectionName) {
    $segments = @([string]$SectionName -split '\.' | ForEach-Object { [regex]::Escape($_) })
    return $segments -join '[ \t]*\.[ \t]*'
}

function Get-SectionHeaderPattern($SectionName) {
    $namePattern = Get-TomlSectionNamePattern $SectionName
    return "(?m)^[ \t]*\[[ \t]*$namePattern[ \t]*\][ \t]*(?:#[^\r\n]*)?\r?$"
}

function Get-SectionPattern($SectionName) {
    $namePattern = Get-TomlSectionNamePattern $SectionName
    return "(?ms)^[ \t]*\[[ \t]*$namePattern[ \t]*\][ \t]*(?:#[^\r\n]*)?(?:\r?\n|\z).*?(?=^[ \t]*\[[^\]\r\n]+\][^\r\n]*(?:\r?\n|\z)|^# >>> ai-config-hub managed mcp:|\z)"
}

function Get-CodexGroupBlock($Content, $GroupName) {
    $startMarker = "# >>> ai-config-hub managed mcp: $GroupName"
    $endMarker = "# <<< ai-config-hub managed mcp: $GroupName"
    $start = [regex]::Escape($startMarker)
    $end = [regex]::Escape($endMarker)
    $markerPattern = "(?ms)^$start\r?\n.*?^$end\r?\n?"
    $markerMatches = [regex]::Matches($Content, $markerPattern)
    if ($markerMatches.Count -ne 1) {
        throw "Rendered Codex MCP fragment must contain exactly one $GroupName block."
    }
    return $markerMatches[0].Value.TrimEnd()
}

function Format-TomlString($Value) {
    return '"' + ([string]$Value -replace '\\', '\\' -replace '"', '\"') + '"'
}

function Format-TomlStringArray($Values) {
    $quoted = @($Values) | ForEach-Object { Format-TomlString $_ }
    return '[' + ($quoted -join ', ') + ']'
}

function New-CodexPencilMcpBlock {
    $server = Resolve-AiConfigHubPencilMcpServer $ResolvedUserHome
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

function Test-CodexPencilBlockUsesDesktop($Content) {
    $pattern = Get-SectionPattern 'mcp_servers.pencil'
    $sectionMatch = [regex]::Match($Content, $pattern)
    if (-not $sectionMatch.Success) {
        return $false
    }

    return $sectionMatch.Value -match '"--app"\s*,\s*"desktop"' -or
        $sectionMatch.Value -match '\\Program Files\\Pencil\\resources\\app\.asar\.unpacked\\out\\mcp-server-windows-x64\.exe'
}

function Remove-CodexPencilBlock($Content) {
    $working = $Content
    foreach ($sectionName in @('mcp_servers.pencil', 'mcp_servers.pencil.env')) {
        $pattern = Get-SectionPattern $sectionName
        $working = [regex]::Replace($working, $pattern, '', 1)
    }
    return $working
}

function Get-CodexMergedContent($TargetPath, $SourcePath) {
    $sourceContent = Resolve-CodexRenderedUserPaths (Get-Content -Raw -Encoding UTF8 -LiteralPath $SourcePath)
    $targetContent = if (Test-Path -LiteralPath $TargetPath) {
        Get-Content -Raw -Encoding UTF8 -LiteralPath $TargetPath
    }
    else {
        ''
    }

    $actions = New-Object System.Collections.Generic.List[string]
    if ([regex]::IsMatch($targetContent, (Get-SectionHeaderPattern 'mcp_servers.pencil'))) {
        $actions.Add('preserve mcp_servers.pencil')
    }

    $working = $targetContent
    if ($ProfileLocalMcpServers -contains 'pencil' -and (Test-CodexPencilBlockUsesDesktop $working)) {
        $working = Remove-CodexPencilBlock $working
        $actions.Add('replace local mcp_servers.pencil desktop target')
    }

    $newBlocks = New-Object System.Collections.Generic.List[string]
    $conflicts = New-Object System.Collections.Generic.List[string]

    foreach ($group in $McpGroups) {
        if (-not (Test-GroupTargetsTool $group 'Codex')) { continue }
        $groupIsActive = $ActiveManagedDefinitionNames -contains $group.Name
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
            $actions.Add($(if ($groupIsActive) { "replace managed $($group.Name) MCP block" } else { "remove managed $($group.Name) MCP block" }))
            $working = [regex]::Replace($working, $markerPattern, '', 1)
            if ($groupIsActive) { $newBlocks.Add((Get-CodexGroupBlock $sourceContent $group.Name)) }
        }
        else {
            $ownership = Get-CodexUnmarkedOwnership $working $group
            if ($ownership.HasSections -and $ownership.Owned) {
                $working = Remove-CodexUnmarkedGroupSections $working $group
                $actions.Add($(if ($groupIsActive) { "migrate owned unmarked $($group.Name) MCP sections" } else { "remove owned inactive $($group.Name) MCP sections" }))
                if ($groupIsActive) { $newBlocks.Add((Get-CodexGroupBlock $sourceContent $group.Name)) }
            }
            elseif ($ownership.HasSections) {
                $actions.Add("preserve custom same-name $($group.Name) MCP sections")
                if ($groupIsActive) {
                    $message = "custom mcp_servers.$($group.Name) conflicts with active managed profile $ProfileName"
                    $actions.Add("conflict $message")
                    $conflicts.Add($message) | Out-Null
                }
            }
            elseif ($groupIsActive) {
                $newBlocks.Add((Get-CodexGroupBlock $sourceContent $group.Name))
            }
        }
    }

    if ($ProfileLocalMcpServers -contains 'pencil' -and -not [regex]::IsMatch($working, (Get-SectionHeaderPattern 'mcp_servers.pencil'))) {
        $pencilBlock = New-CodexPencilMcpBlock
        if ($null -eq $pencilBlock) {
            Write-Warning 'Pencil plugin MCP server was not found locally; sync-mcp will not add [mcp_servers.pencil]. Enable VS Code/Cursor Pencil MCP support before using pencil-design-workflow.'
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
    elseif ($ProfileLocalMcpServers -notcontains 'pencil' -and [regex]::IsMatch($working, (Get-SectionHeaderPattern 'mcp_servers.pencil'))) {
        $actions.Add('preserve local mcp_servers.pencil outside the selected profile')
    }

    foreach ($group in Get-ActiveMcpGroups 'Codex') {
        $actions.Add("append managed $($group.Name) MCP block")
    }

    $managedBlock = ($newBlocks -join "`n`n").TrimEnd()
    $mergedContent = $working.TrimEnd()
    if ([string]::IsNullOrWhiteSpace($managedBlock)) {
        $mergedContent = $mergedContent
    }
    elseif ([string]::IsNullOrWhiteSpace($mergedContent)) {
        $mergedContent = $managedBlock
    }
    else {
        $mergedContent = $mergedContent + "`n`n" + $managedBlock
    }

    $content = $mergedContent.TrimEnd() + "`n"
    return [pscustomobject]@{
        Content = $content
        Actions = @($actions)
        Conflicts = @($conflicts | ForEach-Object { $_ })
        Changed = $content -ne $targetContent
    }
}

function Test-SameJsonObject($Left, $Right) {
    if ($null -eq $Left -or $null -eq $Right) {
        return $false
    }

    $leftJson = $Left | ConvertTo-Json -Depth 16 -Compress
    $rightJson = $Right | ConvertTo-Json -Depth 16 -Compress
    return $leftJson -eq $rightJson
}

function Normalize-CodexOwnershipBlock($Content) {
    $lines = ([string]$Content).Replace("`r`n", "`n").Split("`n") | ForEach-Object {
        $line = $_.TrimEnd()
        if ($line -match '^\s*args\s*=') {
            $line = $line -replace '\[\s+', '['
            $line = $line -replace '\s+\]$', ']'
        }
        $line
    }
    return $lines -join "`n"
}

function New-CodexServerOwnershipBlock($ServerName, $Command, $Arguments, $StartupTimeoutMs, $Style = 'wrapped', $Type = '') {
    $resolvedStyle = if ([string]::IsNullOrWhiteSpace([string]$Style)) { 'wrapped' } else { [string]$Style }
    if ($resolvedStyle -notin @('wrapped', 'direct')) {
        throw "Unsupported Codex legacy ownership style: $resolvedStyle"
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("[mcp_servers.$ServerName]")
    if ($resolvedStyle -eq 'direct') {
        if (-not [string]::IsNullOrWhiteSpace([string]$Type)) {
            $lines.Add('type = ' + (Format-TomlString $Type))
        }
        $lines.Add('command = ' + (Format-TomlString $Command))
        $lines.Add('args = ' + (Format-TomlStringArray $Arguments))
        if ($null -ne $StartupTimeoutMs -and [int]$StartupTimeoutMs -gt 0) { $lines.Add("startup_timeout_ms = $StartupTimeoutMs") }
        return Normalize-CodexOwnershipBlock ($lines -join "`n")
    }

    $lines.Add('command = "cmd"')
    $wrappedArgs = @('/c', [string]$Command) + @($Arguments | ForEach-Object { [string]$_ })
    $lines.Add('args = ' + (Format-TomlStringArray $wrappedArgs))
    if ($null -ne $StartupTimeoutMs -and [int]$StartupTimeoutMs -gt 0) { $lines.Add("startup_timeout_ms = $StartupTimeoutMs") }
    $lines.Add('')
    $lines.Add("[mcp_servers.$ServerName.env]")
    $lines.Add('SystemRoot = "C:\\Windows"')
    $lines.Add('PROGRAMFILES = "C:\\Program Files"')
    return Normalize-CodexOwnershipBlock ($lines -join "`n")
}

function Get-CurrentCodexOwnershipBlock($Group, $ServerName) {
    $sourceServer = $Group.Source.servers.$ServerName
    if ($null -eq $sourceServer) { return $null }
    $current = Get-CurrentClaudeManagedServer $ServerName
    return New-CodexServerOwnershipBlock $ServerName $current.command $current.args $sourceServer.startup_timeout_ms
}

function Get-CodexUnmarkedOwnership($Content, $Group) {
    $hasSections = $false
    $allOwned = $true
    foreach ($serverName in @($Group.Servers) + @($Group.LegacyServers)) {
        $serverMatches = [regex]::Matches($Content, (Get-SectionPattern "mcp_servers.$serverName"))
        $envMatches = [regex]::Matches($Content, (Get-SectionPattern "mcp_servers.$serverName.env"))
        if ($serverMatches.Count -gt 1 -or $envMatches.Count -gt 1) {
            throw "Multiple unmanaged mcp_servers.$serverName sections were found. Please clean up manually."
        }
        if ($serverMatches.Count -eq 0 -and $envMatches.Count -eq 0) { continue }
        $hasSections = $true
        $actual = Normalize-CodexOwnershipBlock (($serverMatches | ForEach-Object { $_.Value.Trim() }) -join "`n`n")
        if ($envMatches.Count -gt 0) { $actual = Normalize-CodexOwnershipBlock ($actual + "`n`n" + $envMatches[0].Value.Trim()) }
        $owned = $false
        $currentBlock = Get-CurrentCodexOwnershipBlock $Group $serverName
        if ($null -ne $currentBlock -and $actual -eq $currentBlock) { $owned = $true }
        if (-not $owned) {
            foreach ($signature in @($Group.LegacySignatures)) {
                $resolvedSignature = New-ClaudeServerFromLegacySignature $signature
                $legacyBlock = New-CodexServerOwnershipBlock $serverName $resolvedSignature.command $resolvedSignature.args $signature.StartupTimeoutMs $signature.CodexStyle $resolvedSignature.type
                if ($actual -eq $legacyBlock) { $owned = $true; break }
            }
        }
        if (-not $owned) { $allOwned = $false }
    }
    return [pscustomobject]@{ HasSections = $hasSections; Owned = ($hasSections -and $allOwned) }
}

function Remove-CodexUnmarkedGroupSections($Content, $Group) {
    $working = $Content
    foreach ($serverName in @($Group.Servers) + @($Group.LegacyServers)) {
        foreach ($section in @("mcp_servers.$serverName", "mcp_servers.$serverName.env")) {
            $working = [regex]::Replace($working, (Get-SectionPattern $section), '', 1)
        }
    }
    return $working
}

function Get-ClaudePencilRegistrationPlan($TargetPath) {
    if ($ProfileLocalMcpServers -notcontains 'pencil') {
        return [pscustomobject]@{ Needed = $false; RemoveExisting = $false; Server = $null; Reason = 'not enabled by selected profile; preserve existing registration' }
    }
    $pencilServer = Get-PencilMcpServerObject 'claudeCode'
    if ($null -eq $pencilServer) {
        return [pscustomobject]@{ Needed = $false; RemoveExisting = $false; Server = $null; Reason = 'pencil MCP server not found' }
    }

    $target = if (Test-Path -LiteralPath $TargetPath) {
        Get-Content -Raw -Encoding UTF8 -LiteralPath $TargetPath | ConvertFrom-Json
    }
    else {
        [pscustomobject]@{}
    }
    $existingPencil = if ($null -ne $target.mcpServers) { $target.mcpServers.pencil } else { $null }

    if (Test-SameJsonObject $existingPencil $pencilServer) {
        return [pscustomobject]@{ Needed = $false; RemoveExisting = $false; Server = $pencilServer; Reason = 'already registered' }
    }

    if ($null -ne $existingPencil -and -not (Test-ClaudePencilServerUsesDesktop $existingPencil)) {
        return [pscustomobject]@{ Needed = $false; RemoveExisting = $false; Server = $pencilServer; Reason = 'preserve custom existing registration' }
    }

    return [pscustomobject]@{ Needed = $true; RemoveExisting = ($null -ne $existingPencil); Server = $pencilServer; Reason = 'register with Claude Code CLI' }
}

function Remove-ClaudePencilFromMergedContent($Merged) {
    $target = $Merged.Content | ConvertFrom-Json
    if ($null -ne $target.mcpServers -and $null -ne $target.mcpServers.pencil) {
        $target.mcpServers.PSObject.Properties.Remove('pencil')
    }
    return [pscustomobject]@{
        Content = ConvertTo-StableJson $target
        Actions = @($Merged.Actions) + @('remove existing desktop pencil before Claude Code CLI registration')
        Changed = $true
    }
}

function Write-MergeStatus($Name, $TargetPath, $Merged) {
    $targetExists = Test-Path -LiteralPath $TargetPath
    $targetContent = if ($targetExists) { Get-Content -Raw -Encoding UTF8 -LiteralPath $TargetPath } else { '' }
    $hasSemanticChange = if ($null -ne $Merged.PSObject.Properties['Changed']) { [bool]$Merged.Changed } else { $targetContent -ne $Merged.Content }
    $status = if (-not $targetExists) { 'missing target' } elseif (-not $hasSemanticChange) { 'unchanged' } else { 'would update' }
    Write-Output "$status`t$Name`t$TargetPath"
    foreach ($action in $Merged.Actions) {
        Write-Output "  - $action"
    }
}

function Assert-ClaudeFinalConfiguration($TargetPath, $PencilPlan) {
    $target = Get-Content -Raw -Encoding UTF8 -LiteralPath $TargetPath | ConvertFrom-Json
    $names = Get-PropertyNames $target.mcpServers
    foreach ($serverName in Get-ActiveManagedServers 'ClaudeCode') {
        if ($names -notcontains $serverName) {
            throw "Final Claude MCP config is missing managed server: $serverName"
        }
    }
    if ($PencilPlan.Needed -and -not (Test-SameJsonObject $target.mcpServers.pencil $PencilPlan.Server)) {
        throw 'Claude Code CLI completed but the final pencil registration does not match the discovered server.'
    }
}

function Assert-CodexFinalConfiguration($TargetPath) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $TargetPath
    foreach ($group in Get-ActiveMcpGroups 'Codex') {
        if (-not $content.Contains("# >>> ai-config-hub managed mcp: $($group.Name)")) {
            throw "Final Codex MCP config is missing managed group: $($group.Name)"
        }
    }
    foreach ($serverName in Get-ActiveManagedServers 'Codex') {
        $sectionName = "mcp_servers.$serverName"
        $sectionCount = [regex]::Matches($content, (Get-SectionHeaderPattern $sectionName)).Count
        if ($sectionCount -ne 1) {
            throw "Final Codex MCP config must contain exactly one [$sectionName] section; found $sectionCount."
        }
        $envSectionName = "$sectionName.env"
        $envSectionCount = [regex]::Matches($content, (Get-SectionHeaderPattern $envSectionName)).Count
        if ($envSectionCount -gt 1) {
            throw "Final Codex MCP config contains duplicate [$envSectionName] sections."
        }
    }
    $pencilSections = [regex]::Matches($content, (Get-SectionHeaderPattern 'mcp_servers.pencil')).Count
    $pencilEnvSections = [regex]::Matches($content, (Get-SectionHeaderPattern 'mcp_servers.pencil.env')).Count
    if ($pencilSections -gt 1 -or $pencilEnvSections -gt 1 -or ($pencilEnvSections -gt 0 -and $pencilSections -eq 0)) {
        throw 'Final Codex MCP config has inconsistent pencil sections.'
    }
}

Assert-AiConfigHubPathInside $ClaudeTarget $ResolvedUserHome 'Claude MCP target' | Out-Null
Assert-AiConfigHubPathInside $CodexTarget $ResolvedUserHome 'Codex MCP target' | Out-Null
foreach ($target in @(
    [pscustomobject]@{ Enabled = $ClaudeCode; Name = 'Claude MCP'; Path = $ClaudeTarget },
    [pscustomobject]@{ Enabled = $Codex; Name = 'Codex MCP'; Path = $CodexTarget }
)) {
    if ($target.Enabled -and (Test-Path -LiteralPath $target.Path) -and -not (Test-Path -LiteralPath $target.Path -PathType Leaf)) {
        throw "$($target.Name) target exists but is not a file: $($target.Path)"
    }
}
if ($Apply) {
    Invoke-AiConfigHubPreflight $Root $ResolvedUserHome
}
$Readiness = Get-AiConfigHubMcpReadiness -Manifest $Manifest -Root $Root -UserHome $ResolvedUserHome -Profile $ProfileDefinition -Mode $(if ($Apply) { 'Smoke' } else { 'Readiness' })
Write-Output "profile`t$ProfileName"
Write-McpReadiness $Readiness
if ($Apply) {
    if ($AllowDegraded) {
        if (-not $Readiness.DegradedReady) {
            throw "MCP profile '$ProfileName' has unavailable required servers. Install their runtimes before Apply."
        }
        $ActiveManagedDefinitionNames = @($Readiness.ReadyDefinitions)
    }
    elseif (-not $Readiness.Ready) {
        throw "MCP profile '$ProfileName' is not ready. Install its runtimes or use -AllowDegraded for optional servers."
    }
}
elseif ($AllowDegraded -and $Readiness.DegradedReady) {
    $ActiveManagedDefinitionNames = @($Readiness.ReadyDefinitions)
}

$ClaudeMerged = $null
$ClaudePencilPlan = $null
$ClaudeChanged = $false
$ClaudeExpectedFingerprint = $null
$CodexMerged = $null
$CodexChanged = $false
$CodexExpectedFingerprint = $null

if ($ClaudeCode) {
    $fingerprintBefore = Get-AiConfigHubPathFingerprint $ClaudeTarget
    $ClaudeMerged = Get-ClaudeMergedContent $ClaudeTarget $ClaudeSource
    $ClaudePencilPlan = Get-ClaudePencilRegistrationPlan $ClaudeTarget
    if ($ClaudePencilPlan.RemoveExisting) {
        $ClaudeMerged = Remove-ClaudePencilFromMergedContent $ClaudeMerged
    }
    $ClaudeChanged = [bool]$ClaudeMerged.Changed
    Write-MergeStatus 'claude-code' $ClaudeTarget $ClaudeMerged
    if ($ClaudePencilPlan.Needed) {
        Write-Output "would register`tclaude-code pencil`t$($ClaudePencilPlan.Server.command)"
        Write-Output '  - via claude mcp add -s user pencil -- <command> <args>'
    }
    else {
        Write-Output "pencil`t$($ClaudePencilPlan.Reason)"
    }
    $ClaudeExpectedFingerprint = Get-AiConfigHubPathFingerprint $ClaudeTarget
    if ($fingerprintBefore -ne $ClaudeExpectedFingerprint) {
        throw "Claude MCP target changed while planning; retry the sync: $ClaudeTarget"
    }
}

if ($Codex) {
    $fingerprintBefore = Get-AiConfigHubPathFingerprint $CodexTarget
    $CodexMerged = Get-CodexMergedContent $CodexTarget $CodexSource
    $CodexChanged = [bool]$CodexMerged.Changed
    Write-MergeStatus 'codex' $CodexTarget $CodexMerged
    $CodexExpectedFingerprint = Get-AiConfigHubPathFingerprint $CodexTarget
    if ($fingerprintBefore -ne $CodexExpectedFingerprint) {
        throw "Codex MCP target changed while planning; retry the sync: $CodexTarget"
    }
}

$ownershipConflicts = @()
if ($null -ne $ClaudeMerged) { $ownershipConflicts += @($ClaudeMerged.Conflicts) }
if ($null -ne $CodexMerged) { $ownershipConflicts += @($CodexMerged.Conflicts) }
$ownershipConflicts = @($ownershipConflicts | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
if ($Apply -and $ownershipConflicts.Count -gt 0) {
    throw "Managed MCP ownership conflicts must be resolved before Apply:`n$($ownershipConflicts -join "`n")"
}

if (-not $Apply) {
    Write-Output 'Dry run only. Re-run with -Apply after reviewing the full preflight output.'
    return
}

$needsClaudeTransaction = $ClaudeCode -and ($ClaudeChanged -or $ClaudePencilPlan.Needed)
$needsCodexTransaction = $Codex -and $CodexChanged
if (-not $needsClaudeTransaction -and -not $needsCodexTransaction) {
    Write-Output 'Managed MCP targets are already up to date.'
    return
}

$context = New-AiConfigHubOperationContext -UserHome $ResolvedUserHome -Pipeline 'mcp' -StagingRelativeRoot $Manifest.UserPaths.StagingRoot -BackupRelativeRoot $Manifest.UserPaths.BackupRoot
try {
    if ($needsClaudeTransaction) {
        $stagedClaude = New-AiConfigHubStagedFile $context 'claude-code.json' $ClaudeMerged.Content
        Install-AiConfigHubStagedFile $context 'claude-code' $stagedClaude $ClaudeTarget -ExpectedFingerprint $ClaudeExpectedFingerprint | Out-Null
    }
    if ($needsCodexTransaction) {
        $stagedCodex = New-AiConfigHubStagedFile $context 'codex.toml' $CodexMerged.Content
        Install-AiConfigHubStagedFile $context 'codex' $stagedCodex $CodexTarget -ExpectedFingerprint $CodexExpectedFingerprint | Out-Null
    }

    if ($ClaudeCode -and $ClaudePencilPlan.Needed) {
        $claude = if ([string]::IsNullOrWhiteSpace($ClaudeCommand)) {
            Get-Command claude -ErrorAction SilentlyContinue
        }
        else {
            Get-Command $ClaudeCommand -ErrorAction SilentlyContinue
        }
        if (-not $claude) {
            throw "Required command 'claude' was not found on PATH for pencil registration."
        }
        $oldUserProfile = $env:USERPROFILE
        $oldHome = $env:HOME
        $oldClaudeConfigDir = $env:CLAUDE_CONFIG_DIR
        try {
            $env:USERPROFILE = $ResolvedUserHome
            $env:HOME = $ResolvedUserHome
            Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue
            & $claude.Source mcp add -s user pencil -- $ClaudePencilPlan.Server.command @($ClaudePencilPlan.Server.args)
            if ($LASTEXITCODE -ne 0) {
                throw "claude mcp add failed for pencil with exit code $LASTEXITCODE"
            }
        }
        finally {
            $env:USERPROFILE = $oldUserProfile
            $env:HOME = $oldHome
            if ($null -eq $oldClaudeConfigDir) {
                Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue
            }
            else {
                $env:CLAUDE_CONFIG_DIR = $oldClaudeConfigDir
            }
        }
    }

    if ($ClaudeCode) { Assert-ClaudeFinalConfiguration $ClaudeTarget $ClaudePencilPlan }
    if ($Codex) { Assert-CodexFinalConfiguration $CodexTarget }

    Complete-AiConfigHubOperation $context
    if ($needsClaudeTransaction) { Write-Output "Synced: claude-code`t$ClaudeTarget" }
    if ($needsCodexTransaction) { Write-Output "Synced: codex`t$CodexTarget" }
}
catch {
    Throw-AiConfigHubOperationFailure $context $_
}
