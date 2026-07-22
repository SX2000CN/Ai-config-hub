[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$ClaudeCode,
    [switch]$Codex,
    [switch]$Grok,
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
$GrokDefinition = $Manifest.Mcp.Targets | Where-Object { $_.Name -eq 'Grok' } | Select-Object -First 1
if ($null -eq $ClaudeDefinition -or $null -eq $CodexDefinition -or $null -eq $GrokDefinition) {
    throw 'ClaudeCode, Codex, and Grok MCP targets must be registered in config/managed-assets.psd1.'
}
$ClaudeSource = Get-AiConfigHubMcpRenderedPath $Root $Manifest 'ClaudeCode' $ProfileName
$CodexSource = Get-AiConfigHubMcpRenderedPath $Root $Manifest 'Codex' $ProfileName
$GrokSource = Get-AiConfigHubMcpRenderedPath $Root $Manifest 'Grok' $ProfileName
$ClaudeTarget = Join-Path $ResolvedUserHome ([string]$ClaudeDefinition.UserRelativePath)
$CodexTarget = Join-Path $ResolvedUserHome ([string]$CodexDefinition.UserRelativePath)
$GrokTarget = Join-Path $ResolvedUserHome ([string]$GrokDefinition.UserRelativePath)
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

if (-not $ClaudeCode -and -not $Codex -and -not $Grok) {
    $ClaudeCode = $true
    $Codex = $true
    $Grok = $true
}

if ($ClaudeCode -and -not (Test-Path -LiteralPath $ClaudeSource)) {
    throw "Missing rendered MCP source: $ClaudeSource. Run scripts\render-mcp.ps1 first."
}

if ($Codex -and -not (Test-Path -LiteralPath $CodexSource)) {
    throw "Missing rendered MCP source: $CodexSource. Run scripts\render-mcp.ps1 first."
}

if ($Grok -and -not (Test-Path -LiteralPath $GrokSource)) {
    throw "Missing rendered MCP source: $GrokSource. Run scripts\render-mcp.ps1 first."
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

function Resolve-TomlRenderedUserPaths($Content) {
    $escapedHome = $ResolvedUserHome.Replace('\', '\\')
    return $Content.Replace('~\\', $escapedHome + '\\').Replace('~/', $escapedHome + '\\')
}

function Resolve-CodexRenderedUserPaths($Content) {
    return Resolve-TomlRenderedUserPaths $Content
}

function Test-IsRetiredPencilClaudeServer($Server) {
    if ($null -eq $Server) { return $false }
    $command = [string]$Server.command
    $joinedArgs = (@($Server.args) | ForEach-Object { [string]$_ }) -join ' '
    if ($command -match '(?i)pencil') { return $true }
    if ($joinedArgs -match '(?i)pencil') { return $true }
    if ($joinedArgs -match '(?i)--app') { return $true }
    if ($joinedArgs -match '(?i)--agent\s+(claudeCode|codexCLI|grok)\b') { return $true }
    return $false
}

function Test-IsRetiredPencilTomlBlock($Content) {
    if (-not [regex]::IsMatch([string]$Content, (Get-SectionHeaderPattern 'mcp_servers.pencil'))) { return $false }
    $pattern = Get-SectionPattern 'mcp_servers.pencil'
    $sectionMatch = [regex]::Match([string]$Content, $pattern)
    if (-not $sectionMatch.Success) { return $false }
    return $sectionMatch.Value -match '(?i)pencil' -or
        $sectionMatch.Value -match '(?i)--app' -or
        $sectionMatch.Value -match '(?i)claudeCode|codexCLI'
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
    if ($null -ne $existingPencil) {
        if (Test-IsRetiredPencilClaudeServer $existingPencil) {
            $target.mcpServers.PSObject.Properties.Remove('pencil')
            $actions.Add('remove retired mcpServers.pencil')
            $managedChanged = $true
        }
        else {
            $actions.Add('preserve custom mcpServers.pencil (not recognized as Pencil MCP)')
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

function Get-GrokManagedCompatBlock {
    $lines = @(
        '# >>> ai-config-hub managed compat'
        '[compat.claude]'
        'mcps = false'
        'skills = false'
        'agents = false'
        'rules = false'
        '# <<< ai-config-hub managed compat'
    )
    return ($lines -join "`n")
}

function Remove-GrokManagedCompatBlock($Content) {
    $pattern = '(?ms)^# >>> ai-config-hub managed compat\r?\n.*?^# <<< ai-config-hub managed compat\r?\n?'
    return [regex]::Replace([string]$Content, $pattern, '')
}

function Remove-CodexPencilBlock($Content) {
    $working = $Content
    foreach ($sectionName in @('mcp_servers.pencil', 'mcp_servers.pencil.env')) {
        $pattern = Get-SectionPattern $sectionName
        $working = [regex]::Replace($working, $pattern, '', 1)
    }
    return $working
}

function Get-TomlToolMergedContent {
    param(
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$ToolName
    )

    $sourceContent = Resolve-TomlRenderedUserPaths (Get-Content -Raw -Encoding UTF8 -LiteralPath $SourcePath)
    $targetContent = if (Test-Path -LiteralPath $TargetPath) {
        Get-Content -Raw -Encoding UTF8 -LiteralPath $TargetPath
    }
    else {
        ''
    }

    $actions = New-Object System.Collections.Generic.List[string]
    $working = $targetContent
    if ($ToolName -eq 'Grok') {
        $working = Remove-GrokManagedCompatBlock $working
    }
    if (Test-IsRetiredPencilTomlBlock $working) {
        $working = Remove-CodexPencilBlock $working
        $actions.Add('remove retired mcp_servers.pencil')
    }
    elseif ([regex]::IsMatch($working, (Get-SectionHeaderPattern 'mcp_servers.pencil'))) {
        $actions.Add('preserve custom mcp_servers.pencil (not recognized as Pencil MCP)')
    }

    $newBlocks = New-Object System.Collections.Generic.List[string]
    $conflicts = New-Object System.Collections.Generic.List[string]

    foreach ($group in $McpGroups) {
        if (-not (Test-GroupTargetsTool $group $ToolName)) { continue }
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
            $ownership = Get-CodexUnmarkedOwnership $working $group $ToolName
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

    foreach ($group in Get-ActiveMcpGroups $ToolName) {
        $actions.Add("append managed $($group.Name) MCP block")
    }

    if ($ToolName -eq 'Grok') {
        $newBlocks.Add((Get-GrokManagedCompatBlock))
        $actions.Add('upsert managed compat.claude block (mcps/skills/agents/rules=false)')
        $claudeJsonPath = Join-Path $ResolvedUserHome '.claude.json'
        if (Test-Path -LiteralPath $claudeJsonPath -PathType Leaf) {
            $actions.Add('compat risk: ~/.claude.json still present; managed compat.claude.mcps=false makes native config.toml the MCP source of truth')
        }
        $claudeHomeRules = Join-Path $ResolvedUserHome '.claude\CLAUDE.md'
        if (Test-Path -LiteralPath $claudeHomeRules -PathType Leaf) {
            $actions.Add('compat risk: ~/.claude/CLAUDE.md still present; managed compat disables Claude home agents/rules scan in favor of ~/.grok/AGENTS.md')
        }
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

function Get-CodexMergedContent($TargetPath, $SourcePath) {
    return Get-TomlToolMergedContent -TargetPath $TargetPath -SourcePath $SourcePath -ToolName 'Codex'
}

function Get-GrokMergedContent($TargetPath, $SourcePath) {
    return Get-TomlToolMergedContent -TargetPath $TargetPath -SourcePath $SourcePath -ToolName 'Grok'
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

function Get-CurrentGrokOwnershipBlock($Group, $ServerName) {
    $sourceServer = $Group.Source.servers.$ServerName
    if ($null -eq $sourceServer) { return $null }
    $current = Get-CurrentClaudeManagedServer $ServerName
    $arguments = @($current.args | ForEach-Object { [string]$_ })
    if ($ServerName -eq 'playwright' -and ($arguments -notcontains '--headless')) {
        $arguments += @('--headless')
    }
    $startupSec = 20
    if ($null -ne $sourceServer.startup_timeout_ms) {
        $startupSec = [Math]::Max(20, [int][Math]::Ceiling(([double]$sourceServer.startup_timeout_ms) / 1000.0))
    }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("[mcp_servers.$ServerName]")
    $lines.Add('command = ' + (Format-TomlString $current.command))
    $lines.Add('args = ' + (Format-TomlStringArray $arguments))
    $lines.Add('enabled = true')
    $lines.Add("startup_timeout_sec = $startupSec")
    return Normalize-CodexOwnershipBlock ($lines -join "`n")
}

function Get-CodexUnmarkedOwnership($Content, $Group, $ToolName = 'Codex') {
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
        $currentBlock = if ($ToolName -eq 'Grok') {
            Get-CurrentGrokOwnershipBlock $Group $serverName
        }
        else {
            Get-CurrentCodexOwnershipBlock $Group $serverName
        }
        if ($null -ne $currentBlock -and $actual -eq $currentBlock) { $owned = $true }
        if (-not $owned -and $ToolName -ne 'Grok') {
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

function Assert-ClaudeFinalConfiguration($TargetPath) {
    $target = Get-Content -Raw -Encoding UTF8 -LiteralPath $TargetPath | ConvertFrom-Json
    $names = Get-PropertyNames $target.mcpServers
    foreach ($serverName in Get-ActiveManagedServers 'ClaudeCode') {
        if ($names -notcontains $serverName) {
            throw "Final Claude MCP config is missing managed server: $serverName"
        }
    }
    if ($null -ne $target.mcpServers.pencil -and (Test-IsRetiredPencilClaudeServer $target.mcpServers.pencil)) {
        throw 'Final Claude MCP config still contains retired pencil server.'
    }
}

function Assert-TomlToolFinalConfiguration($TargetPath, $ToolName) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $TargetPath
    foreach ($group in Get-ActiveMcpGroups $ToolName) {
        if (-not $content.Contains("# >>> ai-config-hub managed mcp: $($group.Name)")) {
            throw "Final $ToolName MCP config is missing managed group: $($group.Name)"
        }
    }
    foreach ($serverName in Get-ActiveManagedServers $ToolName) {
        $sectionName = "mcp_servers.$serverName"
        $sectionCount = [regex]::Matches($content, (Get-SectionHeaderPattern $sectionName)).Count
        if ($sectionCount -ne 1) {
            throw "Final $ToolName MCP config must contain exactly one [$sectionName] section; found $sectionCount."
        }
        if ($ToolName -eq 'Codex') {
            $envSectionName = "$sectionName.env"
            $envSectionCount = [regex]::Matches($content, (Get-SectionHeaderPattern $envSectionName)).Count
            if ($envSectionCount -gt 1) {
                throw "Final $ToolName MCP config contains duplicate [$envSectionName] sections."
            }
        }
    }
    if (Test-IsRetiredPencilTomlBlock $content) {
        throw "Final $ToolName MCP config still contains retired mcp_servers.pencil."
    }
    if ($ToolName -eq 'Grok') {
        if (-not $content.Contains('# >>> ai-config-hub managed compat')) {
            throw 'Final Grok config is missing managed compat block.'
        }
        if ($content -notmatch '(?m)^\s*mcps\s*=\s*false\s*$') {
            throw 'Final Grok managed compat block must set mcps = false.'
        }
    }
}

function Assert-CodexFinalConfiguration($TargetPath) {
    Assert-TomlToolFinalConfiguration $TargetPath 'Codex'
}

function Assert-GrokFinalConfiguration($TargetPath) {
    Assert-TomlToolFinalConfiguration $TargetPath 'Grok'
}

Assert-AiConfigHubPathInside $ClaudeTarget $ResolvedUserHome 'Claude MCP target' | Out-Null
Assert-AiConfigHubPathInside $CodexTarget $ResolvedUserHome 'Codex MCP target' | Out-Null
Assert-AiConfigHubPathInside $GrokTarget $ResolvedUserHome 'Grok MCP target' | Out-Null
foreach ($target in @(
    [pscustomobject]@{ Enabled = $ClaudeCode; Name = 'Claude MCP'; Path = $ClaudeTarget },
    [pscustomobject]@{ Enabled = $Codex; Name = 'Codex MCP'; Path = $CodexTarget },
    [pscustomobject]@{ Enabled = $Grok; Name = 'Grok MCP'; Path = $GrokTarget }
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
$ClaudeChanged = $false
$ClaudeExpectedFingerprint = $null
$CodexMerged = $null
$CodexChanged = $false
$CodexExpectedFingerprint = $null
$GrokMerged = $null
$GrokChanged = $false
$GrokExpectedFingerprint = $null

if ($ClaudeCode) {
    $fingerprintBefore = Get-AiConfigHubPathFingerprint $ClaudeTarget
    $ClaudeMerged = Get-ClaudeMergedContent $ClaudeTarget $ClaudeSource
    $ClaudeChanged = [bool]$ClaudeMerged.Changed
    Write-MergeStatus 'claude-code' $ClaudeTarget $ClaudeMerged
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

if ($Grok) {
    $fingerprintBefore = Get-AiConfigHubPathFingerprint $GrokTarget
    $GrokMerged = Get-GrokMergedContent $GrokTarget $GrokSource
    $GrokChanged = [bool]$GrokMerged.Changed
    Write-MergeStatus 'grok' $GrokTarget $GrokMerged
    $GrokExpectedFingerprint = Get-AiConfigHubPathFingerprint $GrokTarget
    if ($fingerprintBefore -ne $GrokExpectedFingerprint) {
        throw "Grok MCP target changed while planning; retry the sync: $GrokTarget"
    }
}

$ownershipConflicts = @()
if ($null -ne $ClaudeMerged) { $ownershipConflicts += @($ClaudeMerged.Conflicts) }
if ($null -ne $CodexMerged) { $ownershipConflicts += @($CodexMerged.Conflicts) }
if ($null -ne $GrokMerged) { $ownershipConflicts += @($GrokMerged.Conflicts) }
$ownershipConflicts = @($ownershipConflicts | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
if ($Apply -and $ownershipConflicts.Count -gt 0) {
    throw "Managed MCP ownership conflicts must be resolved before Apply:`n$($ownershipConflicts -join "`n")"
}

if (-not $Apply) {
    Write-Output 'Dry run only. Re-run with -Apply after reviewing the full preflight output.'
    return
}

$needsClaudeTransaction = $ClaudeCode -and $ClaudeChanged
$needsCodexTransaction = $Codex -and $CodexChanged
$needsGrokTransaction = $Grok -and $GrokChanged
if (-not $needsClaudeTransaction -and -not $needsCodexTransaction -and -not $needsGrokTransaction) {
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
    if ($needsGrokTransaction) {
        $stagedGrok = New-AiConfigHubStagedFile $context 'grok.toml' $GrokMerged.Content
        Install-AiConfigHubStagedFile $context 'grok' $stagedGrok $GrokTarget -ExpectedFingerprint $GrokExpectedFingerprint | Out-Null
    }

    if ($ClaudeCode) { Assert-ClaudeFinalConfiguration $ClaudeTarget }
    if ($Codex) { Assert-CodexFinalConfiguration $CodexTarget }
    if ($Grok) { Assert-GrokFinalConfiguration $GrokTarget }

    Complete-AiConfigHubOperation $context
    if ($needsClaudeTransaction) { Write-Output "Synced: claude-code`t$ClaudeTarget" }
    if ($needsCodexTransaction) { Write-Output "Synced: codex`t$CodexTarget" }
    if ($needsGrokTransaction) { Write-Output "Synced: grok`t$GrokTarget" }
}
catch {
    Throw-AiConfigHubOperationFailure $context $_
}
