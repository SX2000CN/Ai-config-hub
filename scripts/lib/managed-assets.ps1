$ErrorActionPreference = 'Stop'

function Test-AiConfigHubRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Label must not be empty."
    }
    if ([System.IO.Path]::IsPathRooted($Value) -or $Value.StartsWith('~')) {
        throw "$Label must be relative: $Value"
    }
    if (($Value -split '[\\/]') -contains '..') {
        throw "$Label must not contain '..': $Value"
    }
}

function ConvertTo-AiConfigHubManagedAssetsV2 {
    param([Parameter(Mandatory = $true)]$Manifest)

    $sourceSchemaVersion = [int]$Manifest.SchemaVersion
    if ($sourceSchemaVersion -eq 2) {
        return $Manifest
    }
    if ($sourceSchemaVersion -ne 1) {
        throw "Unsupported managed assets manifest schema: $sourceSchemaVersion"
    }

    $servers = @(
        foreach ($group in @($Manifest.Mcp.Groups)) {
            @{
                Name = [string]$group.Name
                Source = [string]$group.Source
                Targets = @($group.Targets)
                LegacyServers = @($group.LegacyServers)
                LegacySignatures = @()
                RequiresRuntime = $null
                Optional = $false
                PreferredFor = @()
                Doctor = @{}
            }
        }
    )
    $serverNames = @($servers | ForEach-Object { [string]$_.Name })
    $localServers = @($Manifest.Mcp.LocalServers)

    foreach ($target in @($Manifest.Mcp.Targets)) {
        if ($null -ne $target.Rendered) {
            $target['RenderedByProfile'] = @{ full = [string]$target.Rendered }
        }
    }

    $Manifest.Mcp['DefaultProfile'] = 'full'
    $Manifest.Mcp['Servers'] = $servers
    $Manifest.Mcp['Profiles'] = @(
        @{
            Name = 'full'
            Servers = $serverNames
            LocalServers = $localServers
        }
    )
    $Manifest['SourceSchemaVersion'] = 1
    $Manifest['SchemaVersion'] = 2
    return $Manifest
}

function Import-AiConfigHubManagedAssetsManifest {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing managed assets manifest: $Path"
    }

    $rawManifest = Import-PowerShellDataFile -LiteralPath $Path
    foreach ($entry in @{
        StagingRoot = [string]$rawManifest.UserPaths.StagingRoot
        BackupRoot = [string]$rawManifest.UserPaths.BackupRoot
    }.GetEnumerator()) {
        Test-AiConfigHubRelativePath $entry.Value "Managed assets manifest UserPaths.$($entry.Key)"
    }
    $rawStagingRoot = ([string]$rawManifest.UserPaths.StagingRoot).Replace('/', '\').TrimEnd('\')
    $rawBackupRoot = ([string]$rawManifest.UserPaths.BackupRoot).Replace('/', '\').TrimEnd('\')
    if ($rawStagingRoot.Equals($rawBackupRoot, [StringComparison]::OrdinalIgnoreCase) -or
        $rawStagingRoot.StartsWith($rawBackupRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
        $rawBackupRoot.StartsWith($rawStagingRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Managed assets manifest staging and backup roots must be distinct and non-overlapping.'
    }
    $manifest = ConvertTo-AiConfigHubManagedAssetsV2 $rawManifest

    foreach ($entry in @{
        StagingRoot = [string]$manifest.UserPaths.StagingRoot
        BackupRoot = [string]$manifest.UserPaths.BackupRoot
    }.GetEnumerator()) {
        Test-AiConfigHubRelativePath $entry.Value "Managed assets manifest UserPaths.$($entry.Key)"
    }

    $stagingRoot = ([string]$manifest.UserPaths.StagingRoot).Replace('/', '\').TrimEnd('\')
    $backupRoot = ([string]$manifest.UserPaths.BackupRoot).Replace('/', '\').TrimEnd('\')
    if ($stagingRoot.Equals($backupRoot, [StringComparison]::OrdinalIgnoreCase) -or
        $stagingRoot.StartsWith($backupRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
        $backupRoot.StartsWith($stagingRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Managed assets manifest staging and backup roots must be distinct and non-overlapping.'
    }

    $runtimeNames = @($manifest.Runtimes | ForEach-Object { [string]$_.Name })
    if (@($runtimeNames | Select-Object -Unique).Count -ne $runtimeNames.Count) {
        throw 'Managed assets manifest runtime names must be unique.'
    }

    $serverNames = New-Object System.Collections.Generic.List[string]
    foreach ($server in @($manifest.Mcp.Servers)) {
        $name = [string]$server.Name
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw 'Managed MCP server name must not be empty.'
        }
        if ($serverNames.Contains($name)) {
            throw "Duplicate managed MCP server: $name"
        }
        $serverNames.Add($name) | Out-Null
        Test-AiConfigHubRelativePath ([string]$server.Source) "Managed MCP server source for $name"
        if (-not [string]::IsNullOrWhiteSpace([string]$server.RequiresRuntime) -and
            $runtimeNames -notcontains [string]$server.RequiresRuntime) {
            throw "Managed MCP server $name requires unknown runtime: $($server.RequiresRuntime)"
        }
    }

    $localServerNames = @($manifest.Mcp.LocalServers | ForEach-Object { [string]$_ })
    $profileNames = New-Object System.Collections.Generic.List[string]
    foreach ($profile in @($manifest.Mcp.Profiles)) {
        $profileName = [string]$profile.Name
        if ([string]::IsNullOrWhiteSpace($profileName)) {
            throw 'Managed MCP profile name must not be empty.'
        }
        if ($profileNames.Contains($profileName)) {
            throw "Duplicate managed MCP profile: $profileName"
        }
        $profileNames.Add($profileName) | Out-Null
        foreach ($serverName in @($profile.Servers)) {
            if (-not $serverNames.Contains([string]$serverName)) {
                throw "Managed MCP profile $profileName references unknown server: $serverName"
            }
        }
        foreach ($localServerName in @($profile.LocalServers)) {
            if ($localServerNames -notcontains [string]$localServerName) {
                throw "Managed MCP profile $profileName references unknown local server: $localServerName"
            }
        }
    }

    if (-not $profileNames.Contains([string]$manifest.Mcp.DefaultProfile)) {
        throw "Managed MCP default profile is not registered: $($manifest.Mcp.DefaultProfile)"
    }

    $targetNames = New-Object System.Collections.Generic.List[string]
    foreach ($target in @($manifest.Mcp.Targets)) {
        $targetName = [string]$target.Name
        if ([string]::IsNullOrWhiteSpace($targetName) -or $targetNames.Contains($targetName)) {
            throw "Managed MCP target names must be non-empty and unique: $targetName"
        }
        $targetNames.Add($targetName) | Out-Null
        if ($null -ne $target.RenderedPattern) {
            $pattern = [string]$target.RenderedPattern
            Test-AiConfigHubRelativePath $pattern "Managed MCP rendered pattern for $targetName"
            if (-not $pattern.Contains('{profile}')) {
                throw "Managed MCP rendered pattern for $targetName must contain {profile}: $pattern"
            }
        }
        elseif ($null -eq $target.RenderedByProfile) {
            throw "Managed MCP target $targetName must define RenderedPattern or RenderedByProfile."
        }
        else {
            foreach ($profileName in $profileNames) {
                $renderedPath = [string]$target.RenderedByProfile[$profileName]
                Test-AiConfigHubRelativePath $renderedPath "Managed MCP rendered path for $targetName profile $profileName"
            }
        }
        Test-AiConfigHubRelativePath ([string]$target.UserRelativePath) "Managed MCP user path for $targetName"
    }

    return $manifest
}

function Get-AiConfigHubMcpProfileNames {
    param([Parameter(Mandatory = $true)]$Manifest)
    return @($Manifest.Mcp.Profiles | ForEach-Object { [string]$_.Name })
}

function Get-AiConfigHubMcpProfile {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [string]$Name
    )

    $resolvedName = if ([string]::IsNullOrWhiteSpace($Name)) { [string]$Manifest.Mcp.DefaultProfile } else { $Name }
    $profile = $Manifest.Mcp.Profiles | Where-Object { [string]$_.Name -eq $resolvedName } | Select-Object -First 1
    if ($null -eq $profile) {
        throw "Unknown MCP profile '$resolvedName'. Available profiles: $((Get-AiConfigHubMcpProfileNames $Manifest) -join ', ')"
    }
    return $profile
}

function Get-AiConfigHubMcpServerDefinition {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return $Manifest.Mcp.Servers | Where-Object { [string]$_.Name -eq $Name } | Select-Object -First 1
}

function Test-AiConfigHubMcpServerTargetsTool {
    param(
        [Parameter(Mandatory = $true)]$Server,
        [Parameter(Mandatory = $true)][string]$ToolName
    )

    return $null -eq $Server.Targets -or @($Server.Targets).Count -eq 0 -or @($Server.Targets) -contains $ToolName
}

function Get-AiConfigHubMcpServerDefinitionsForProfile {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$Profile,
        [string]$ToolName
    )

    $definitions = foreach ($name in @($Profile.Servers)) {
        $server = Get-AiConfigHubMcpServerDefinition $Manifest ([string]$name)
        if ($null -eq $server) {
            throw "MCP profile $($Profile.Name) references unknown server: $name"
        }
        if ([string]::IsNullOrWhiteSpace($ToolName) -or (Test-AiConfigHubMcpServerTargetsTool $server $ToolName)) {
            $server
        }
    }
    return @($definitions)
}

function Get-AiConfigHubMcpRenderedPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$ToolName,
        [Parameter(Mandatory = $true)][string]$ProfileName
    )

    $target = $Manifest.Mcp.Targets | Where-Object { [string]$_.Name -eq $ToolName } | Select-Object -First 1
    if ($null -eq $target) {
        throw "Missing MCP render target in manifest: $ToolName"
    }

    $relative = if ($null -ne $target.RenderedPattern) {
        ([string]$target.RenderedPattern).Replace('{profile}', $ProfileName)
    }
    else {
        [string]$target.RenderedByProfile[$ProfileName]
    }
    if ([string]::IsNullOrWhiteSpace($relative)) {
        throw "Missing MCP rendered path for target $ToolName profile $ProfileName"
    }
    return Join-Path $Root $relative
}

function Get-AiConfigHubRuntimeDefinition {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return $Manifest.Runtimes | Where-Object { [string]$_.Name -eq $Name } | Select-Object -First 1
}
