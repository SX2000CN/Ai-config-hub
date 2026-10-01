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

$renderedHashes = @{}
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
    $renderedHashes[$file] = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash
}

# Rules are a single shared content distributed to every tool. If the rendered
# targets diverge, per-tool drift has crept back in and must be removed.
if ($renderedHashes.Count -gt 1) {
    $distinctHashes = @($renderedHashes.Values | Sort-Object -Unique)
    if ($distinctHashes.Count -gt 1) {
        Fail 'Rendered rule targets are not identical; rules must remain one shared content'
    }
}

$currentGuidanceFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $Root 'rules\shared') -Recurse -File
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

# The context-thread CLI contract lives in exactly one place: the skill that uses it.
# Rules must not repeat it (that duplication is what caused drift).
$contextThreadContract = '~\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js'
$contextThreadSkill = Join-Path $Root 'skills\shared\global-context-thread\workflow.md'
if (-not (Test-Path -LiteralPath $contextThreadSkill -PathType Leaf)) {
    Fail "Missing context-thread skill workflow: $contextThreadSkill"
}
elseif (-not (Get-Content -Raw -Encoding UTF8 -LiteralPath $contextThreadSkill).Contains($contextThreadContract)) {
    Fail 'context-thread CLI contract is missing its real runtime path in the global-context-thread skill'
}
$rulesCore = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $Root 'rules\shared\core.md')
if ($rulesCore.Contains('context-thread.js')) {
    Fail 'rules/shared/core.md must not carry the context-thread CLI contract; it belongs to the global-context-thread skill'
}
if (Test-Path -LiteralPath (Join-Path $Root 'rules\tools') -PathType Container) {
    Fail 'rules/tools must stay empty: tool-specific facts belong in a skill reference, not in always-on rules'
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
