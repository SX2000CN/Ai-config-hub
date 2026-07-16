$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'
. (Join-Path $PSScriptRoot 'lib\validation.ps1')

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing managed assets manifest: $ManifestPath"
}

$Manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath
$Failed = $false

function Fail($Message) {
    Write-Output "ERROR: $Message"
    $script:Failed = $true
}

& (Join-Path $PSScriptRoot 'render.ps1') -Check

foreach ($target in $Manifest.Rules.Targets) {
    $file = Join-Path $Root ([string]$target.Rendered)
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        Fail "Missing rendered file: $file"
        continue
    }

    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file
    if ($content -match '\{\{[^}]+\}\}') {
        Fail "Unresolved template placeholder in $file"
    }
    if (-not $content.TrimStart().StartsWith('# ')) {
        Fail "Missing markdown title in $file"
    }
    if ([string]$target.Name -eq 'ClaudeCode' -and -not $content.Contains('Claude Code')) {
        Fail "Missing Claude Code marker in $file"
    }
    if ([string]$target.Name -eq 'Codex' -and -not $content.Contains('Codex')) {
        Fail "Missing Codex marker in $file"
    }
}

$currentGuidanceFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $Root 'rules\shared') -Recurse -File
    Get-ChildItem -LiteralPath (Join-Path $Root 'rules\tools') -Recurse -File
    Get-Item -LiteralPath (Join-Path $Root 'README.md')
    Get-ChildItem -LiteralPath (Join-Path $Root 'docs') -Recurse -File | Where-Object {
        -not $_.FullName.StartsWith((Join-Path $Root 'docs\archive'), [StringComparison]::OrdinalIgnoreCase)
    }
)

$dangerousPhrases = @(
    ([string]::Concat([char[]]@(0x9664, 0x975E, 0x7528, 0x6237, 0x660E, 0x786E, 0x6388, 0x6743))),
    ([string]::Concat([char[]]@(0x4E13, 0x95E8, 0x7684, 0x79C1, 0x6709, 0x51ED, 0x8BC1, 0x6587, 0x6863))),
    ([string]::Concat([char[]]@(0x65E0, 0x8BBA, 0x5177, 0x4F53, 0x539F, 0x56E0)))
)
foreach ($file in $currentGuidanceFiles) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    if ($content -cmatch '\b[FV][0-4]\b') {
        Fail "Current guidance must not depend on F/V matrices: $($file.FullName)"
    }
    foreach ($phrase in $dangerousPhrases) {
        if ($content.Contains($phrase)) {
            Fail "Dangerous authorization or credential wording reintroduced in $($file.FullName)"
        }
    }
}

$claudeSupplement = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $Root 'rules\tools\claude-code.md')
$codexSupplement = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $Root 'rules\tools\codex.md')
if (-not $claudeSupplement.Contains('~\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js')) {
    Fail 'Claude context-thread CLI contract is missing its real runtime path'
}
if (-not $codexSupplement.Contains('~/.ai-config-hub/mcp/context-thread/dist/bin/context-thread.js')) {
    Fail 'Codex context-thread CLI contract is missing its real runtime path'
}

$scanPaths = @(
    (Join-Path $Root 'rules'),
    (Join-Path $Root 'templates'),
    (Join-Path $Root 'docs'),
    (Join-Path $Root 'README.md'),
    (Join-Path $Root 'CHANGELOG.md')
)
$scanFiles = Get-AiConfigHubScanFiles -Paths $scanPaths -Root $Root
Test-AiConfigHubSensitiveContent -Files $scanFiles -Fail ${function:Fail}

if ($Failed) {
    exit 1
}

Write-Output 'Check passed'
