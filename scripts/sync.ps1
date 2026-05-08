[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Targets = @(
    @{
        Source = Join-Path $Root 'rules\rendered\CLAUDE.md'
        Target = 'C:\Users\sx200\.claude\CLAUDE.md'
    },
    @{
        Source = Join-Path $Root 'rules\rendered\AGENTS.md'
        Target = 'C:\Users\sx200\.codex\AGENTS.md'
    }
)

foreach ($item in $Targets) {
    if (-not (Test-Path $item.Source)) {
        throw "Missing rendered source: $($item.Source). Run scripts\render.ps1 first."
    }
}

if (-not $Apply) {
    Write-Output 'Dry run only. Re-run with -Apply to overwrite global files after backups.'
    foreach ($item in $Targets) {
        $sourceContent = Get-Content -Raw -Encoding UTF8 -Path $item.Source
        $targetExists = Test-Path $item.Target
        $targetContent = if ($targetExists) { Get-Content -Raw -Encoding UTF8 -Path $item.Target } else { '' }
        $status = if (-not $targetExists) { 'missing target' } elseif ($sourceContent -eq $targetContent) { 'unchanged' } else { 'would update' }
        Write-Output "$status`t$($item.Source) -> $($item.Target)"
    }
    exit 0
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

foreach ($item in $Targets) {
    $targetDir = Split-Path -Parent $item.Target
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }

    if (Test-Path $item.Target) {
        $backup = "$($item.Target).$timestamp.bak"
        Copy-Item -Path $item.Target -Destination $backup -Force
        Write-Output "Backup created: $backup"
    }

    Copy-Item -Path $item.Source -Destination $item.Target -Force
    Write-Output "Synced: $($item.Source) -> $($item.Target)"
}
