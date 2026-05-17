$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$SourcePath = Join-Path $Root 'tool-configs\mcp\shared\browser-visual.json'
$RenderedRoot = Join-Path $Root 'tool-configs\mcp\rendered'
$ClaudePath = Join-Path $RenderedRoot 'claude-code.mcp.json'
$CodexPath = Join-Path $RenderedRoot 'codex.mcp.toml'
$RequiredServers = @('chrome-devtools', 'playwright')
$StartMarker = '# >>> ai-config-hub managed mcp: browser-visual'
$EndMarker = '# <<< ai-config-hub managed mcp: browser-visual'
$Failed = $false

function Fail($Message) {
    Write-Output "ERROR: $Message"
    $script:Failed = $true
}

function Get-PropertyNames($Object) {
    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

foreach ($path in @($SourcePath, $ClaudePath, $CodexPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        Fail "Missing MCP file: $path"
    }
}

if (-not $Failed) {
    try {
        $source = Get-Content -Raw -Encoding UTF8 -LiteralPath $SourcePath | ConvertFrom-Json
        if ($null -eq $source.servers) {
            Fail "Missing servers object in $SourcePath"
        }
        else {
            $sourceNames = Get-PropertyNames $source.servers
            foreach ($serverName in $RequiredServers) {
                if ($sourceNames -notcontains $serverName) {
                    Fail "Missing required source server: $serverName"
                }
            }

            foreach ($serverName in $sourceNames) {
                if ($RequiredServers -notcontains $serverName) {
                    Fail "Unexpected source server: $serverName"
                }
            }
        }
    }
    catch {
        Fail "Invalid source JSON: $($_.Exception.Message)"
    }

    try {
        $claude = Get-Content -Raw -Encoding UTF8 -LiteralPath $ClaudePath | ConvertFrom-Json
        $topLevelNames = Get-PropertyNames $claude
        if (@($topLevelNames).Count -ne 1 -or @($topLevelNames)[0] -ne 'mcpServers') {
            Fail "Claude rendered fragment must contain only top-level mcpServers"
        }

        $claudeServerNames = Get-PropertyNames $claude.mcpServers
        foreach ($serverName in $RequiredServers) {
            if ($claudeServerNames -notcontains $serverName) {
                Fail "Missing Claude rendered server: $serverName"
            }
        }

        foreach ($serverName in $claudeServerNames) {
            if ($RequiredServers -notcontains $serverName) {
                Fail "Unexpected Claude rendered server: $serverName"
            }
        }
    }
    catch {
        Fail "Invalid Claude rendered JSON: $($_.Exception.Message)"
    }

    $codexContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $CodexPath
    if (-not $codexContent.Contains($StartMarker) -or -not $codexContent.Contains($EndMarker)) {
        Fail "Missing Codex managed MCP markers"
    }

    foreach ($serverName in $RequiredServers) {
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
    $_.Extension -in @('.md', '.toml', '.tpl', '.ps1', '.json', '.txt') -or $_.Name -eq '.gitignore'
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
