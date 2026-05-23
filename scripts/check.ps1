$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Files = @(
    (Join-Path $Root 'rules\rendered\CLAUDE.md'),
    (Join-Path $Root 'rules\rendered\AGENTS.md')
)

$Failed = $false

foreach ($file in $Files) {
    if (-not (Test-Path $file)) {
        Write-Error "Missing rendered file: $file"
        $Failed = $true
        continue
    }

    $content = Get-Content -Raw -Encoding UTF8 -Path $file

    if ($content -match '\{\{[^}]+\}\}') {
        Write-Error "Unresolved template placeholder in $file"
        $Failed = $true
    }

    if (-not $content.TrimStart().StartsWith('# ')) {
        Write-Output "ERROR: Missing markdown title in $file"
        $Failed = $true
    }

    if ($file -like '*CLAUDE.md' -and -not $content.Contains('Claude Code')) {
        Write-Output "ERROR: Missing Claude Code marker in $file"
        $Failed = $true
    }

    if ($file -like '*AGENTS.md' -and -not $content.Contains('Codex')) {
        Write-Output "ERROR: Missing Codex marker in $file"
        $Failed = $true
    }
}

$ScanFiles = @(
    (Join-Path $Root 'rules'),
    (Join-Path $Root 'templates'),
    (Join-Path $Root 'docs'),
    (Join-Path $Root 'README.md'),
    (Join-Path $Root 'CHANGELOG.md')
)

$SecretPatterns = @(
    'sk-[A-Za-z0-9_-]{16,}',
    'api[_-]?key\s*=',
    'token\s*=',
    'password\s*=',
    'secret\s*='
)

$MarkdownAndConfigFiles = Get-ChildItem -Path $ScanFiles -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    -not $_.FullName.StartsWith((Join-Path $Root 'private'), [StringComparison]::OrdinalIgnoreCase) -and
    -not ($_.FullName -match '[\\/]node_modules[\\/]') -and
    -not ($_.FullName -match '[\\/]dist[\\/]') -and
    -not ($_.FullName -match '[\\/]release[\\/]') -and
    ($_.Extension -in @('.md', '.toml', '.tpl', '.ps1', '.json', '.txt') -or $_.Name -eq '.gitignore')
}

foreach ($file in $MarkdownAndConfigFiles) {
    $content = Get-Content -Raw -Encoding UTF8 -Path $file.FullName
    foreach ($pattern in $SecretPatterns) {
        if ($content -match $pattern) {
            Write-Warning "Potential sensitive pattern '$pattern' in $($file.FullName)"
        }
    }
}

if ($Failed) {
    exit 1
}

Write-Output 'Check passed'
