[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$IncludeCodexLegacy
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$SkillName = 'project-ai-config-hub'
$RenderedRoot = Join-Path $Root 'skills\rendered'
$ManagedMarker = '<!-- ai-config-hub-managed: project-ai-config-hub -->'

$Targets = @(
    @{
        Source = Join-Path $RenderedRoot "claude-code\$SkillName"
        Target = 'C:\Users\sx200\.claude\skills\project-ai-config-hub'
    },
    @{
        Source = Join-Path $RenderedRoot "codex\$SkillName"
        Target = 'C:\Users\sx200\.agents\skills\project-ai-config-hub'
    }
)

if ($IncludeCodexLegacy) {
    $Targets += @{
        Source = Join-Path $RenderedRoot "codex-legacy\$SkillName"
        Target = 'C:\Users\sx200\.codex\skills\project-ai-config-hub'
    }
}

foreach ($item in $Targets) {
    if (-not (Test-Path -LiteralPath $item.Source)) {
        throw "Missing rendered source: $($item.Source). Run scripts\render-skills.ps1 first."
    }
}

function Get-DirectoryFingerprint($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return ''
    }

    $files = Get-ChildItem -LiteralPath $Path -Recurse -File | Sort-Object FullName
    $parts = foreach ($file in $files) {
        $relative = $file.FullName.Substring((Resolve-Path -LiteralPath $Path).Path.Length).TrimStart('\')
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash
        "$relative`t$hash"
    }

    return ($parts -join "`n")
}

function Test-ManagedTarget($Path) {
    $skillFile = Join-Path $Path 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillFile)) {
        return $false
    }

    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillFile
    if ($content.Contains($ManagedMarker)) {
        return $true
    }

    return $content -match '(?m)^name:\s*project-ai-config-hub\s*$'
}

if (-not $Apply) {
    Write-Output 'Dry run only. Re-run with -Apply to sync global skill directories after backups.'
    foreach ($item in $Targets) {
        $sourceFingerprint = Get-DirectoryFingerprint $item.Source
        $targetExists = Test-Path -LiteralPath $item.Target
        $targetFingerprint = if ($targetExists) { Get-DirectoryFingerprint $item.Target } else { '' }
        $status = if (-not $targetExists) {
            'missing target'
        } elseif (-not (Test-ManagedTarget $item.Target)) {
            'would stop: existing unmanaged target'
        } elseif ($sourceFingerprint -eq $targetFingerprint) {
            'unchanged'
        } else {
            'would update managed target'
        }
        Write-Output "$status`t$($item.Source) -> $($item.Target)"
    }
    exit 0
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

foreach ($item in $Targets) {
    $target = $item.Target
    $targetParent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $targetParent)) {
        New-Item -ItemType Directory -Force -Path $targetParent | Out-Null
    }

    if (Test-Path -LiteralPath $target) {
        if (-not (Test-ManagedTarget $target)) {
            throw "Refusing to overwrite unmanaged existing skill target: $target"
        }

        $backup = "$target.$timestamp.bak"
        Copy-Item -LiteralPath $target -Destination $backup -Recurse -Force
        Write-Output "Backup created: $backup"
    }

    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Recurse -Force
    }

    Copy-Item -LiteralPath $item.Source -Destination $target -Recurse -Force
    Write-Output "Synced: $($item.Source) -> $target"
}

