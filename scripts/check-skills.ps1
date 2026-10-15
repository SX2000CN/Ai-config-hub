$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'
. (Join-Path $PSScriptRoot 'lib\validation.ps1')

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing managed assets manifest: $ManifestPath"
}

$Manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath
$Failed = $false
$CanonicalRoot = Join-Path $Root ([string]$Manifest.Skills.SourceRoot)
$SkillNames = @(Get-ChildItem -LiteralPath $CanonicalRoot -Directory -Force | Sort-Object Name | ForEach-Object { $_.Name })

function Fail($Message) {
    Write-Output "ERROR: $Message"
    $script:Failed = $true
}

function Test-Frontmatter($Path, $SkillName) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
    if ($content -notmatch '(?s)^---\s*\r?\n(.+?)\r?\n---') {
        Fail "Missing YAML frontmatter: $Path"
        return
    }

    $frontmatter = $Matches[1]
    if ($frontmatter -notmatch "(?m)^name:\s*$([regex]::Escape($SkillName))\s*$") {
        Fail "Missing expected name in frontmatter: $Path"
    }
    if ($SkillName -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or $SkillName.Length -gt 64) {
        Fail "Skill name does not match the portable package convention: $SkillName"
    }

    $descriptionMatch = [regex]::Match($frontmatter, '(?m)^description:\s*(?<value>.+)$')
    if (-not $descriptionMatch.Success -or $descriptionMatch.Groups['value'].Value.Trim().Length -lt 20) {
        Fail "Missing useful description in frontmatter: $Path"
    }
    elseif ($descriptionMatch.Groups['value'].Value.Trim().Length -gt 1024) {
        Fail "Skill description exceeds the portable package limit: $Path"
    }

    if ($frontmatter -match '(?m)^when_to_use\s*:') {
        Fail "Non-standard when_to_use frontmatter is not allowed in portable skill packages: $Path"
    }

    $allowedFields = @('name', 'description', 'license', 'compatibility', 'metadata', 'allowed-tools')
    foreach ($line in ($frontmatter -split "`r?`n")) {
        if ($line -match '^([A-Za-z][A-Za-z0-9_-]*):') {
            $field = [string]$Matches[1]
            if ($allowedFields -notcontains $field) {
                Fail "Non-portable top-level frontmatter field '$field' in $Path"
            }
        }
    }

    $managedMarker = "<!-- ai-config-hub-managed: $SkillName -->"
    if ($content -notmatch [regex]::Escape($managedMarker)) {
        Fail "Missing managed marker in skill body: $Path"
    }
}

function Get-FullPathInside($RootPath, $CandidatePath) {
    $rootFull = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $candidateFull = [System.IO.Path]::GetFullPath($CandidatePath)
    if (-not $candidateFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }
    return $candidateFull
}

function Test-PackageReferences($PackageRoot) {
    foreach ($file in Get-ChildItem -LiteralPath $PackageRoot -Recurse -File -Filter '*.md') {
        $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
        $references = New-Object System.Collections.Generic.List[object]

        foreach ($match in [regex]::Matches($content, '\]\((?<path>[^)]+)\)')) {
            $value = [string]$match.Groups['path'].Value
            if ($value -match '^\s*<?(?<path>[^\s>]+)>?') {
                $references.Add([pscustomobject]@{ Path = [string]$Matches['path']; PackageRelative = $false }) | Out-Null
            }
        }
        foreach ($match in [regex]::Matches($content, '`(?<path>(?:references|templates|checklists|scripts)[\\/][^`\s]+)`')) {
            $references.Add([pscustomobject]@{ Path = [string]$match.Groups['path'].Value; PackageRelative = $true }) | Out-Null
        }

        foreach ($reference in $references) {
            $raw = ([string]$reference.Path).Trim().Trim('<', '>')
            if ([string]::IsNullOrWhiteSpace($raw) -or $raw.StartsWith('#') -or $raw -match '^[A-Za-z][A-Za-z0-9+.-]*:') {
                continue
            }
            $pathOnly = ($raw -split '#', 2)[0]
            if ([string]::IsNullOrWhiteSpace($pathOnly)) { continue }
            $base = if ([bool]$reference.PackageRelative) { $PackageRoot } else { $file.DirectoryName }
            $candidate = Get-FullPathInside $PackageRoot (Join-Path $base $pathOnly)
            if ($null -eq $candidate) {
                Fail "Skill reference escapes package root in $($file.FullName): $raw"
                continue
            }
            if (-not (Test-Path -LiteralPath $candidate)) {
                Fail "Broken skill package reference in $($file.FullName): $raw"
            }
        }
    }
}

function Test-SkillRouteFixtures {
    $knownSkills = @{}
    foreach ($skillName in $SkillNames) { $knownSkills[$skillName] = $true }
    $routePath = Join-Path $Root 'skills\evals\routes.json'
    if (-not (Test-Path -LiteralPath $routePath -PathType Leaf)) {
        Fail "Missing skill route fixtures: $routePath"
        return
    }
    try {
        $routeFixtures = Get-Content -Raw -Encoding UTF8 -LiteralPath $routePath | ConvertFrom-Json
        if ([int]$routeFixtures.schemaVersion -ne 1 -or @($routeFixtures.cases).Count -lt 6) {
            Fail 'Skill route fixtures must use schemaVersion 1 and contain at least six cases'
        }
        $caseIds = @{}
        foreach ($case in @($routeFixtures.cases)) {
            if ([string]::IsNullOrWhiteSpace([string]$case.id) -or $caseIds.ContainsKey([string]$case.id)) {
                Fail "Skill route fixture has a missing or duplicate id: $($case.id)"
            }
            else { $caseIds[[string]$case.id] = $true }
            foreach ($skillName in @($case.primary) + @($case.allowedSecondary) + @($case.forbidden)) {
                if ($null -ne $skillName -and -not [string]::IsNullOrWhiteSpace([string]$skillName) -and -not $knownSkills.ContainsKey([string]$skillName)) {
                    Fail "Skill route fixture $($case.id) references unknown skill: $skillName"
                }
            }
        }
    }
    catch {
        Fail "Invalid skill route fixtures: $($_.Exception.Message)"
    }
}

function Test-ThinkingPartnerEvals {
    $casePath = Join-Path $Root 'skills\evals\global-thinking-partner\cases.json'
    $rubricPath = Join-Path $Root 'skills\evals\global-thinking-partner\rubric.md'
    if (-not (Test-Path -LiteralPath $casePath -PathType Leaf) -or -not (Test-Path -LiteralPath $rubricPath -PathType Leaf)) {
        Fail 'Missing global-thinking-partner behavior fixtures or rubric'
        return
    }
    try {
        $fixtures = Get-Content -Raw -Encoding UTF8 -LiteralPath $casePath | ConvertFrom-Json
        if ([int]$fixtures.schemaVersion -ne 1 -or [string]$fixtures.skill -ne 'global-thinking-partner' -or @($fixtures.cases).Count -lt 8) {
            Fail 'Thinking partner fixtures must use schemaVersion 1 and contain at least eight cases'
        }
        foreach ($case in @($fixtures.cases)) {
            if ([string]::IsNullOrWhiteSpace([string]$case.id) -or [string]::IsNullOrWhiteSpace([string]$case.prompt) -or @($case.must).Count -eq 0 -or @($case.mustNot).Count -eq 0) {
                Fail "Incomplete thinking partner fixture: $($case.id)"
            }
        }
    }
    catch {
        Fail "Invalid thinking partner fixtures: $($_.Exception.Message)"
    }

    $thinkingSource = Get-AiConfigHubScanFiles -Paths @(
        (Join-Path $CanonicalRoot 'global-thinking-partner')
    ) -Root $Root
    $forbidden = @(
        ([string]::Concat([char[]]@(0x56FA, 0x5B9A, 0x56DB, 0x4E2A, 0x955C, 0x5934))),
        ([string]::Concat([char[]]@(0x8F93, 0x51FA, 0x6761, 0x6570, 0x7B49, 0x4E8E))),
        ([string]::Concat([char[]]@(0x6700, 0x591A, 0x95EE, 0x4E00, 0x4E2A, 0x95EE, 0x9898))),
        'thinking-brief.md'
    )
    foreach ($file in $thinkingSource) {
        $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
        foreach ($phrase in $forbidden) {
            if ($content.Contains($phrase)) {
                Fail "Thinking partner reintroduced fixed-format phrase '$phrase' in $($file.FullName)"
            }
        }
    }
}

Test-SkillRouteFixtures
Test-ThinkingPartnerEvals

foreach ($skillName in $SkillNames) {
    $packageRoot = Join-Path $CanonicalRoot $skillName
    if (-not (Test-Path -LiteralPath $packageRoot -PathType Container)) {
        Fail "Missing canonical skill package: $packageRoot"
        continue
    }

    $sourceSkillFile = Join-Path $packageRoot 'SKILL.md'
    if (-not (Test-Path -LiteralPath $sourceSkillFile -PathType Leaf)) {
        Fail "Missing canonical SKILL.md: $sourceSkillFile"
        continue
    }
    Test-Frontmatter $sourceSkillFile $skillName
    Test-PackageReferences $packageRoot

}

# Validate only the maintained package source and eval
# fixtures. Historical client-entry directories under skills\ are migration
# candidates and must not participate in canonical content validation.
$skillScanPaths = @(
    $CanonicalRoot,
    (Join-Path $Root 'skills\evals')
)
$skillScanFiles = Get-AiConfigHubScanFiles -Paths $skillScanPaths -Root $Root
foreach ($file in $skillScanFiles) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    if ($content -match '\{\{[^}]+\}\}' -and $file.Extension -ne '.tpl') {
        Fail "Unresolved template placeholder outside template file: $($file.FullName)"
    }
}

$forbiddenPhrases = @(
    ([string]::Concat([char[]]@(0x53EA, 0x4FDD, 0x5B58, 0x4E00, 0x4E2A, 0x5F53, 0x524D, 0x4E3B, 0x9898))),
    ([string]::Concat([char[]]@(0x6BCF, 0x6B21, 0x4EFB, 0x52A1, 0x5B8C, 0x6210, 0x90FD, 0x5FC5, 0x987B, 0x5F52, 0x6863))),
    ('README.md ' + [string]::Concat([char[]]@(0x662F, 0x56FA, 0x5B9A, 0x7684)) + ' agent ' + [string]::Concat([char[]]@(0x63A5, 0x624B, 0x5165, 0x53E3)))
)
foreach ($file in $skillScanFiles) {
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
    foreach ($phrase in $forbiddenPhrases) {
        if ($content.Contains($phrase)) {
            Fail "Forbidden v1 work-state phrase '$phrase' in $($file.FullName)"
        }
    }
}

$sensitiveFiles = Get-AiConfigHubScanFiles -Paths $skillScanPaths -Root $Root
Test-AiConfigHubSensitiveContent -Files $sensitiveFiles -Fail ${function:Fail}

if ($Failed) {
    exit 1
}

Write-Output 'Skill check passed'
