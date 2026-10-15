$ErrorActionPreference = 'Stop'

# Rules must stay free of path and filename references. A rule that names a path
# is the one that rots: 23% of surveyed repository instruction files carry stale
# code references (Treude & Baltes, arXiv:2606.09090). Keeping rules path-free
# makes that class of rot structurally impossible instead of policed.

$Root = Split-Path -Parent $PSScriptRoot
$CorePath = Join-Path $Root '.agents\rules\core.md'
$RationalePath = Join-Path $Root '.agents\rules\core-rationale.md'
$Failed = $false

function Fail($Message) {
    Write-Output "ERROR: $Message"
    $script:Failed = $true
}

if (-not (Test-Path -LiteralPath $CorePath -PathType Leaf)) {
    Fail "Missing shared rules core: $CorePath"
    exit 1
}

$content = Get-Content -Raw -Encoding UTF8 -LiteralPath $CorePath

# Path-shaped references the rules must never carry. Exception: backticked POSIX
# device names and bare command names are the gotchas themselves, not rot risks.
$pathPatterns = @(
    @{ Name = 'home-relative path'; Pattern = '~[/\\]' },
    @{ Name = 'windows absolute path'; Pattern = '[A-Za-z]:\\' },
    @{ Name = 'named file with extension'; Pattern = '[A-Za-z0-9_.-]+\.(md|json|toml|psd1|ps1|js|mjs|ts|yml|yaml|sql|sh|cmd|tpl)\b' },
    @{ Name = 'directory path segment'; Pattern = '(?m)^[-#].*\b(src|lib|scripts|tool-configs|references|templates|skills|rules)/' }
)

foreach ($item in $pathPatterns) {
    foreach ($match in [regex]::Matches($content, $item.Pattern)) {
        $line = ($content.Substring(0, $match.Index) -split "`n").Count
        Fail ".agents/rules/core.md must not carry a $($item.Name) (rot risk) at line ${line}: $($match.Value)"
    }
}

# A rule that names nothing binds nothing. In a 30k-repo static analysis, 89.9% of
# agent configs carried at least one vacuous rule ("keep the code clean"). Vacuousness
# cannot be judged automatically, so the check enforces the triage contract instead:
# every section must have a rationale entry naming the concrete failure it prevents.
if (-not (Test-Path -LiteralPath $RationalePath -PathType Leaf)) {
    Fail "Missing rules rationale file: $RationalePath"
}
else {
    $rationale = Get-Content -Raw -Encoding UTF8 -LiteralPath $RationalePath
    $sections = [regex]::Matches($content, '(?m)^##\s+(.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() }
    if (@($sections).Count -eq 0) {
        Fail '.agents/rules/core.md has no sections; expected a sectioned collaboration contract'
    }
    foreach ($section in $sections) {
        if ($rationale -notmatch [regex]::Escape($section)) {
            Fail ".agents/rules/core.md section '$section' has no rationale entry; every rule needs the concrete failure it prevents"
        }
    }
}

if ($Failed) {
    exit 1
}

Write-Output 'Rules hygiene check passed'
