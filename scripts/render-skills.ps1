$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$RenderedRoot = Join-Path $Root 'skills\rendered'
$SkillNames = @('project-ai-config-hub', 'global-frontend-design', 'global-thinking-partner')

function Assert-Path($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required path: $Path"
    }
}

function Copy-CleanDirectory($Source, $Destination) {
    Assert-Path $Source

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
}

function Copy-SharedPayload($SharedSource, $Destination) {
    foreach ($item in Get-ChildItem -LiteralPath $SharedSource -Force) {
        $target = Join-Path $Destination $item.Name
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
        Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
    }
}

foreach ($skillName in $SkillNames) {
    $sharedSource = Join-Path $Root "skills\shared\$skillName"
    $claudeSource = Join-Path $Root "skills\claude-code\$skillName"
    $codexSource = Join-Path $Root "skills\codex\$skillName"

    Assert-Path $sharedSource
    Assert-Path $claudeSource
    Assert-Path $codexSource

    $targets = @(
        @{
            Source = $claudeSource
            Destination = Join-Path $RenderedRoot "claude-code\$skillName"
        },
        @{
            Source = $codexSource
            Destination = Join-Path $RenderedRoot "codex\$skillName"
        },
        @{
            Source = $codexSource
            Destination = Join-Path $RenderedRoot "codex-legacy\$skillName"
        }
    )

    foreach ($target in $targets) {
        Copy-CleanDirectory $target.Source $target.Destination
        Copy-SharedPayload $sharedSource $target.Destination
        Write-Output "Rendered $($target.Destination)"
    }
}
