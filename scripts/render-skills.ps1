$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$SkillName = 'project-ai-config-hub'
$SharedSource = Join-Path $Root "skills\shared\$SkillName"
$ClaudeSource = Join-Path $Root "skills\claude-code\$SkillName"
$CodexSource = Join-Path $Root "skills\codex\$SkillName"
$RenderedRoot = Join-Path $Root 'skills\rendered'

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

function Copy-SharedPayload($Destination) {
    foreach ($name in @('README.md', 'workflow.md', 'references', 'templates')) {
        $source = Join-Path $SharedSource $name
        if (Test-Path -LiteralPath $source) {
            $target = Join-Path $Destination $name
            if (Test-Path -LiteralPath $target) {
                Remove-Item -LiteralPath $target -Recurse -Force
            }
            Copy-Item -LiteralPath $source -Destination $Destination -Recurse -Force
        }
    }
}

Assert-Path $SharedSource
Assert-Path $ClaudeSource
Assert-Path $CodexSource

$targets = @(
    @{
        Source = $ClaudeSource
        Destination = Join-Path $RenderedRoot "claude-code\$SkillName"
    },
    @{
        Source = $CodexSource
        Destination = Join-Path $RenderedRoot "codex\$SkillName"
    },
    @{
        Source = $CodexSource
        Destination = Join-Path $RenderedRoot "codex-legacy\$SkillName"
    }
)

foreach ($target in $targets) {
    Copy-CleanDirectory $target.Source $target.Destination
    Copy-SharedPayload $target.Destination
    Write-Output "Rendered $($target.Destination)"
}

