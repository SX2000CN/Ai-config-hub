[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing managed assets manifest: $ManifestPath"
}

$Manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath
$CanonicalRoot = Join-Path $Root ([string]$Manifest.Skills.SourceRoot)
$SkillNames = @(Get-ChildItem -LiteralPath $CanonicalRoot -Directory -Force | Sort-Object Name | ForEach-Object { $_.Name })
if (-not (Test-Path -LiteralPath $CanonicalRoot -PathType Container)) {
    throw "Missing canonical skill source root: $CanonicalRoot"
}

foreach ($skillName in $SkillNames) {
    if ($skillName -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        throw "Invalid skill name in canonical source: $skillName"
    }
    $skillFile = Join-Path (Join-Path $CanonicalRoot $skillName) 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        throw "Missing canonical SKILL.md: $skillFile"
    }
}

Write-Output "Skill packages use canonical source directly: $CanonicalRoot"
if (-not $Check) {
    Write-Output 'No rendered Skill files were generated.'
}
