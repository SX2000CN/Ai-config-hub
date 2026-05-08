$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot

function Read-Text($Path) {
    Get-Content -Raw -Encoding UTF8 -Path $Path
}

function Write-Text($Path, $Content) {
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    Set-Content -Encoding UTF8 -Path $Path -Value $Content
}

$sharedCore = (Read-Text (Join-Path $Root 'rules\shared\core.md')).TrimEnd()
$claudeSupplement = (Read-Text (Join-Path $Root 'rules\tools\claude-code.md')).TrimEnd()
$codexSupplement = (Read-Text (Join-Path $Root 'rules\tools\codex.md')).TrimEnd()

$claudeTemplate = Read-Text (Join-Path $Root 'templates\CLAUDE.md.tpl')
$codexTemplate = Read-Text (Join-Path $Root 'templates\AGENTS.md.tpl')

$claudeOutput = $claudeTemplate.Replace('{{shared_core}}', $sharedCore).Replace('{{claude_code_supplement}}', $claudeSupplement).TrimEnd() + "`n"
$codexOutput = $codexTemplate.Replace('{{shared_core}}', $sharedCore).Replace('{{codex_supplement}}', $codexSupplement).TrimEnd() + "`n"

Write-Text (Join-Path $Root 'rules\rendered\CLAUDE.md') $claudeOutput
Write-Text (Join-Path $Root 'rules\rendered\AGENTS.md') $codexOutput

Write-Output 'Rendered rules/rendered/CLAUDE.md'
Write-Output 'Rendered rules/rendered/AGENTS.md'
