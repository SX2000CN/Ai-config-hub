$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$SkillName = 'project-ai-config-hub'
$RenderedRoot = Join-Path $Root 'skills\rendered'
$ManagedMarker = '<!-- ai-config-hub-managed: project-ai-config-hub -->'
$SkillRoots = @(
    (Join-Path $RenderedRoot "claude-code\$SkillName"),
    (Join-Path $RenderedRoot "codex\$SkillName"),
    (Join-Path $RenderedRoot "codex-legacy\$SkillName")
)

$Failed = $false

function Fail($Message) {
    Write-Output "ERROR: $Message"
    $script:Failed = $true
}

function Test-Frontmatter($Path) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
    if ($content -notmatch '(?s)^---\s*\r?\n(.+?)\r?\n---') {
        Fail "Missing YAML frontmatter: $Path"
        return
    }

    $frontmatter = $Matches[1]
    if ($frontmatter -notmatch '(?m)^name:\s*project-ai-config-hub\s*$') {
        Fail "Missing expected name in frontmatter: $Path"
    }

    if ($frontmatter -notmatch '(?m)^description:\s*.{20,}$') {
        Fail "Missing useful description in frontmatter: $Path"
    }

    if ($Path -like "*\claude-code\$SkillName\SKILL.md" -and $frontmatter -notmatch '(?m)^when_to_use:\s*.{10,}$') {
        Fail "Missing when_to_use in Claude frontmatter: $Path"
    }

    if ($content -notmatch [regex]::Escape($ManagedMarker)) {
        Fail "Missing managed marker in skill body: $Path"
    }
}

foreach ($rootPath in $SkillRoots) {
    if (-not (Test-Path -LiteralPath $rootPath)) {
        Fail "Missing rendered skill directory: $rootPath. Run scripts\render-skills.ps1 first."
        continue
    }

    $skillFile = Join-Path $rootPath 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillFile)) {
        Fail "Missing SKILL.md: $skillFile"
        continue
    }

    Test-Frontmatter $skillFile

    foreach ($relativePath in @(
        'README.md',
        'workflow.md',
        'references\official-paths.md',
        'references\design-checklist.md',
        'templates\ai-readme.md.tpl',
        'templates\project-readme.md.tpl',
        'templates\skills-registry.md.tpl',
        'templates\claude-skill.md.tpl',
        'templates\codex-skill.md.tpl',
        'templates\codex-legacy-skill.md.tpl'
    )) {
        $path = Join-Path $rootPath $relativePath
        if (-not (Test-Path -LiteralPath $path)) {
            Fail "Missing rendered payload file: $path"
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
    'api[_-]?key\s*=',
    'token\s*=',
    'password\s*=',
    'secret\s*=',
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

