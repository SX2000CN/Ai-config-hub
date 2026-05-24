$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$RenderedRoot = Join-Path $Root 'tool-configs\mcp\rendered'
$ClaudePath = Join-Path $RenderedRoot 'claude-code.mcp.json'
$CodexPath = Join-Path $RenderedRoot 'codex.mcp.toml'
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
    }
)
$Failed = $false

function Fail($Message) {
    Write-Output "ERROR: $Message"
    $script:Failed = $true
}

function Get-PropertyNames($Object) {
    if ($null -eq $Object) {
        return @()
    }

    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Get-ManagedServers() {
    $servers = New-Object System.Collections.Generic.List[string]
    foreach ($group in $McpGroups) {
        foreach ($serverName in $group.RequiredServers) {
            $servers.Add($serverName)
        }
    }
    return @($servers)
}

function Test-RepoScript($ServerName, $Server) {
    if ($null -eq $Server.repo_script -or [string]::IsNullOrWhiteSpace($Server.repo_script)) {
        return
    }

    $scriptPath = Join-Path $Root ([string]$Server.repo_script)
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        Fail "Missing repo_script for source server $ServerName`: $scriptPath"
    }
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

function Test-RuntimeEntry($ServerName, $Server) {
    if ($null -eq $Server.runtime_entry -or [string]::IsNullOrWhiteSpace($Server.runtime_entry)) {
        return
    }

    $runtimeEntry = Resolve-UserPath ([string]$Server.runtime_entry)
    if (-not [System.IO.Path]::IsPathRooted($runtimeEntry)) {
        Fail "runtime_entry for source server $ServerName must resolve to an absolute path: $runtimeEntry"
        return
    }

    if (-not (Test-Path -LiteralPath $runtimeEntry)) {
        Write-Warning "context-thread runtime entry was not found at $runtimeEntry. Run scripts\sync-context-thread-runtime.ps1 -Apply before starting context-thread MCP."
    }
}

function Get-SourceServerArgs($Server) {
    $args = @($Server.args)
    if ($null -ne $Server.runtime_entry -and -not [string]::IsNullOrWhiteSpace($Server.runtime_entry)) {
        $args += @(Resolve-UserPath ([string]$Server.runtime_entry))
    }
    if ($null -ne $Server.repo_script -and -not [string]::IsNullOrWhiteSpace($Server.repo_script)) {
        $args += @(Join-Path $Root ([string]$Server.repo_script))
    }
    if ($null -ne $Server.script_args) {
        $args += @($Server.script_args)
    }
    return @($args)
}

foreach ($path in @($ClaudePath, $CodexPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        Fail "Missing MCP file: $path"
    }
}

foreach ($group in $McpGroups) {
    if (-not (Test-Path -LiteralPath $group.SourcePath)) {
        Fail "Missing MCP file: $($group.SourcePath)"
    }
}

if (-not $Failed) {
    $managedServers = Get-ManagedServers

    foreach ($group in $McpGroups) {
        try {
            $source = Get-Content -Raw -Encoding UTF8 -LiteralPath $group.SourcePath | ConvertFrom-Json
            if ($null -eq $source.servers) {
                Fail "Missing servers object in $($group.SourcePath)"
            }
            else {
                $sourceNames = Get-PropertyNames $source.servers
                foreach ($serverName in $group.RequiredServers) {
                    if ($sourceNames -notcontains $serverName) {
                        Fail "Missing required source server: $serverName"
                    }
                }

                foreach ($serverName in $sourceNames) {
                    if ($group.RequiredServers -notcontains $serverName) {
                        Fail "Unexpected source server in $($group.Name): $serverName"
                    }

                    $server = $source.servers.$serverName
                    if ([string]::IsNullOrWhiteSpace($server.command)) {
                        Fail "Missing command for source server: $serverName"
                    }

                    if (@(Get-SourceServerArgs $server).Count -eq 0) {
                        Fail "Missing args for source server: $serverName"
                    }

                    Test-RepoScript $serverName $server
                    Test-RuntimeEntry $serverName $server
                }
            }
        }
        catch {
            Fail "Invalid source JSON $($group.SourcePath): $($_.Exception.Message)"
        }
    }

    try {
        $claude = Get-Content -Raw -Encoding UTF8 -LiteralPath $ClaudePath | ConvertFrom-Json
        $topLevelNames = Get-PropertyNames $claude
        if (@($topLevelNames).Count -ne 1 -or @($topLevelNames)[0] -ne 'mcpServers') {
            Fail "Claude rendered fragment must contain only top-level mcpServers"
        }

        $claudeServerNames = Get-PropertyNames $claude.mcpServers
        foreach ($serverName in $managedServers) {
            if ($claudeServerNames -notcontains $serverName) {
                Fail "Missing Claude rendered server: $serverName"
            }
        }

        foreach ($serverName in $claudeServerNames) {
            if ($managedServers -notcontains $serverName) {
                Fail "Unexpected Claude rendered server: $serverName"
            }
        }
    }
    catch {
        Fail "Invalid Claude rendered JSON: $($_.Exception.Message)"
    }

    $codexContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $CodexPath
    foreach ($group in $McpGroups) {
        $startMarker = "# >>> ai-config-hub managed mcp: $($group.Name)"
        $endMarker = "# <<< ai-config-hub managed mcp: $($group.Name)"
        if (-not $codexContent.Contains($startMarker) -or -not $codexContent.Contains($endMarker)) {
            Fail "Missing Codex managed MCP markers for $($group.Name)"
        }
    }

    foreach ($serverName in $managedServers) {
        if ($codexContent -notmatch "(?m)^\[mcp_servers\.$([regex]::Escape($serverName))\]$") {
            Fail "Missing Codex rendered server section: $serverName"
        }

        if ($codexContent -notmatch "(?m)^\[mcp_servers\.$([regex]::Escape($serverName))\.env\]$") {
            Fail "Missing Codex rendered env section: $serverName"
        }
    }

    $ForbiddenCodexPatterns = @(
        '(?m)^model\s*=',
        '(?m)^model_provider\s*=',
        '(?m)^base_url\s*=',
        '(?m)^\[model_providers\.',
        '(?m)^\[projects\.',
        '(?i)trust_level',
        '(?i)trusted',
        '(?i)provider_url'
    )
    foreach ($pattern in $ForbiddenCodexPatterns) {
        if ($codexContent -match $pattern) {
            Fail "Forbidden Codex config pattern '$pattern' in rendered MCP fragment"
        }
    }
}

$ScanPaths = @(
    (Join-Path $Root 'tool-configs'),
    (Join-Path $Root 'scripts\render-mcp.ps1'),
    (Join-Path $Root 'scripts\check-mcp.ps1'),
    (Join-Path $Root 'scripts\sync-mcp.ps1'),
    (Join-Path $Root 'docs'),
    (Join-Path $Root 'README.md')
)

$SensitivePatterns = @(
    'sk-[A-Za-z0-9_-]{16,}',
    '(?i)api[_-]?key\s*=',
    '(?i)token\s*=',
    '(?i)password\s*=',
    '(?i)secret\s*=',
    '(?i)cookie\s*=',
    '(?i)session\s*=',
    '(?i)provider[_-]?url\s*=',
    '(?i)trusted[_ -]?project',
    '(?i)browser[_ -]?profile'
)

$scanFiles = Get-ChildItem -Path $ScanPaths -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    -not $_.FullName.StartsWith((Join-Path $Root 'private'), [StringComparison]::OrdinalIgnoreCase) -and
    -not ($_.FullName -match '[\\/]node_modules[\\/]') -and
    -not ($_.FullName -match '[\\/]dist[\\/]') -and
    -not ($_.FullName -match '[\\/]release[\\/]') -and
    ($_.Extension -in @('.md', '.toml', '.tpl', '.ps1', '.json', '.txt') -or $_.Name -eq '.gitignore')
}

foreach ($file in $scanFiles) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    if ($file.FullName.StartsWith((Join-Path $Root 'tool-configs')) -and $content -match '\{\{[^}]+\}\}') {
        Fail "Unresolved template placeholder in $($file.FullName)"
    }

    foreach ($pattern in $SensitivePatterns) {
        if ($content -match $pattern) {
            $isPolicyMention = $pattern -eq '(?i)trusted[_ -]?project' -and (
                $file.FullName.EndsWith('docs\secrets-policy.md') -or
                $file.FullName.EndsWith('README.md')
            )
            if (-not $isPolicyMention) {
                Write-Warning "Potential sensitive pattern '$pattern' in $($file.FullName)"
            }
        }
    }
}

if ($Failed) {
    exit 1
}

Write-Output 'MCP check passed'
