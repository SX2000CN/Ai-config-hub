$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$RenderedRoot = Join-Path $Root 'skills\rendered'
$SkillNames = @('project-ai-config-hub', 'global-frontend-design', 'global-thinking-partner', 'global-context-thread', 'pencil-design-workflow')
$Failed = $false

function Fail($Message) {
    Write-Output "ERROR: $Message"
    $script:Failed = $true
}

function Test-Frontmatter($Path, $SkillName, $RequireWhenToUse) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
    if ($content -notmatch '(?s)^---\s*\r?\n(.+?)\r?\n---') {
        Fail "Missing YAML frontmatter: $Path"
        return
    }

    $frontmatter = $Matches[1]
    if ($frontmatter -notmatch "(?m)^name:\s*$([regex]::Escape($SkillName))\s*$") {
        Fail "Missing expected name in frontmatter: $Path"
    }

    if ($frontmatter -notmatch '(?m)^description:\s*.{20,}$') {
        Fail "Missing useful description in frontmatter: $Path"
    }

    if ($RequireWhenToUse -and $frontmatter -notmatch '(?m)^when_to_use:\s*.{10,}$') {
        Fail "Missing when_to_use in Claude frontmatter: $Path"
    }

    $managedMarker = "<!-- ai-config-hub-managed: $SkillName -->"
    if ($content -notmatch [regex]::Escape($managedMarker)) {
        Fail "Missing managed marker in skill body: $Path"
    }
}

function Get-RelativeFileHash($BasePath, $Path) {
    $base = (Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\') + '\'
    $full = (Resolve-Path -LiteralPath $Path).Path
    $relative = $full.Substring($base.Length)
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
    return "$relative=$hash"
}

foreach ($skillName in $SkillNames) {
    $sharedRoot = Join-Path $Root "skills\shared\$skillName"
    $skillRoots = @(
        @{
            Path = Join-Path $RenderedRoot "claude-code\$skillName"
            RequireWhenToUse = $true
        },
        @{
            Path = Join-Path $RenderedRoot "codex\$skillName"
            RequireWhenToUse = $false
        },
        @{
            Path = Join-Path $RenderedRoot "codex-legacy\$skillName"
            RequireWhenToUse = $false
        }
    )

    if (-not (Test-Path -LiteralPath $sharedRoot)) {
        Fail "Missing shared skill source: $sharedRoot"
        continue
    }

    foreach ($skillRoot in $skillRoots) {
        $rootPath = $skillRoot.Path
        if (-not (Test-Path -LiteralPath $rootPath)) {
            Fail "Missing rendered skill directory: $rootPath. Run scripts\render-skills.ps1 first."
            continue
        }

        $skillFile = Join-Path $rootPath 'SKILL.md'
        if (-not (Test-Path -LiteralPath $skillFile)) {
            Fail "Missing SKILL.md: $skillFile"
            continue
        }

        Test-Frontmatter $skillFile $skillName $skillRoot.RequireWhenToUse

        foreach ($sharedItem in Get-ChildItem -LiteralPath $sharedRoot -Force) {
            $renderedItem = Join-Path $rootPath $sharedItem.Name
            if (-not (Test-Path -LiteralPath $renderedItem)) {
                Fail "Missing rendered shared payload: $renderedItem"
                continue
            }

            if ($sharedItem -is [System.IO.FileInfo]) {
                $sharedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sharedItem.FullName).Hash
                $renderedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $renderedItem).Hash

                if ($sharedHash -ne $renderedHash) {
                    Fail "Rendered shared payload is out of sync: $renderedItem"
                }

                continue
            }

            $sharedItems = Get-ChildItem -LiteralPath $sharedItem.FullName -Recurse -File | ForEach-Object {
                Get-RelativeFileHash $sharedItem.FullName $_.FullName
            } | Sort-Object

            $renderedItems = Get-ChildItem -LiteralPath $renderedItem -Recurse -File | ForEach-Object {
                Get-RelativeFileHash $renderedItem $_.FullName
            } | Sort-Object

            if (($sharedItems -join "`n") -ne ($renderedItems -join "`n")) {
                Fail "Rendered shared payload is out of sync: $renderedItem"
            }
        }
    }
}

$SkillScanRoot = Join-Path $Root 'skills'
$SecretScanRoots = @(
    (Join-Path $Root 'skills'),
    (Join-Path $Root 'scripts')
)

$SecretPatterns = @(
    'sk-[A-Za-z0-9_-]{16,}',
    'api[_-]?key\s=',
    'token\s=',
    'password\s=',
    'secret\s=',
    'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY'
)

$SkillScanFiles = Get-ChildItem -Path $SkillScanRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Extension -in @('.md', '.toml', '.tpl', '.ps1', '.json', '.txt', '.yaml', '.yml')
}

foreach ($file in $SkillScanFiles) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName

    if ($content -match '\{\{[^}]+\}\}' -and $file.FullName -notlike '*.tpl') {
        Fail "Unresolved template placeholder outside template file: $($file.FullName)"
    }
}

$ForbiddenPhrases = @(
    ([string]::Concat([char[]]@(0x53EA, 0x4FDD, 0x5B58, 0x4E00, 0x4E2A, 0x5F53, 0x524D, 0x4E3B, 0x9898))),
    ([string]::Concat([char[]]@(0x6BCF, 0x6B21, 0x4EFB, 0x52A1, 0x5B8C, 0x6210, 0x90FD, 0x5FC5, 0x987B, 0x5F52, 0x6863))),
    ('README.md ' + [string]::Concat([char[]]@(0x662F, 0x56FA, 0x5B9A, 0x7684)) + ' agent ' + [string]::Concat([char[]]@(0x63A5, 0x624B, 0x5165, 0x53E3)))
)

foreach ($file in $SkillScanFiles) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName

    foreach ($phrase in $ForbiddenPhrases) {
        if ($content.Contains($phrase)) {
            Fail "Forbidden v1 work-state phrase '$phrase' in $($file.FullName)"
        }
    }
}

$SecretScanFiles = Get-ChildItem -Path $SecretScanRoots -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Extension -in @('.md', '.toml', '.tpl', '.ps1', '.json', '.txt', '.yaml', '.yml')
}

foreach ($file in $SecretScanFiles) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName

    foreach ($pattern in $SecretPatterns) {
        if ($content -match $pattern) {
            Write-Warning "Potential sensitive pattern '$pattern' in $($file.FullName)"
        }
    }
}

if ($Failed) {
    exit 1
}

Write-Output 'Skill check passed'
