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

function Read-Text($Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing render source: $Path"
    }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
}

function Write-Text($Path, $Content) {
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    # UTF-8 without BOM: Grok and other TOML/JSON consumers reject or mishandle BOM.
    [System.IO.File]::WriteAllText($Path, [string]$Content, (New-Object System.Text.UTF8Encoding($false)))
}

# One content for every tool. Rules describe how the user works with the model;
# tool-specific facts are not rules and live in a skill reference instead.
$sharedCore = (Read-Text (Join-Path $Root ([string]$Manifest.Rules.SharedCore))).TrimEnd()
$template = Read-Text (Join-Path $Root ([string]$Manifest.Rules.Template))
$expected = $template.Replace('{{shared_core}}', $sharedCore).TrimEnd() + "`n"

if ($expected -match '\{\{[^}]+\}\}') {
    throw "Unresolved template placeholder in $([string]$Manifest.Rules.Template)"
}

$failed = $false
foreach ($target in $Manifest.Rules.Targets) {
    $renderedPath = Join-Path $Root ([string]$target.Rendered)

    if ($Check) {
        if (-not (Test-Path -LiteralPath $renderedPath -PathType Leaf)) {
            Write-Output "ERROR: Missing rendered rule target: $renderedPath"
            $failed = $true
            continue
        }

        $actual = Get-Content -Raw -Encoding UTF8 -LiteralPath $renderedPath
        if ($actual -ne $expected) {
            Write-Output "ERROR: Rendered rule target is out of date: $renderedPath"
            $failed = $true
        }
        else {
            Write-Output "Verified $renderedPath"
        }
        continue
    }

    Write-Text $renderedPath $expected
    Write-Output "Rendered $renderedPath"
}

if ($failed) {
    throw 'Rule render check failed. Run scripts\render.ps1 to refresh rendered files.'
}
