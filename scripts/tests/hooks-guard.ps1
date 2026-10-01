$ErrorActionPreference = 'Stop'

# Deterministic tests for the Claude Code PreToolUse guard. The guard is the part of
# the boundary that is supposed to survive model upgrades, so its decisions must not
# depend on a model: every case here is a literal JSON payload and a literal verdict.

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$GuardPath = Join-Path $Root 'hooks\claude\guard.mjs'
$Failed = $false

function Fail($Message) {
    Write-Output "ERROR: $Message"
    $script:Failed = $true
}

if (-not (Test-Path -LiteralPath $GuardPath -PathType Leaf)) {
    Fail "Missing guard script: $GuardPath"
    exit 1
}

function Invoke-Guard($Payload) {
    # Pipe without a BOM: some hosts prepend one and JSON.parse rejects it.
    $previousOutputEncoding = $OutputEncoding
    $OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    try {
        $json = $Payload | ConvertTo-Json -Depth 8 -Compress
        $output = $json | & node $GuardPath 2>&1
    }
    finally {
        $OutputEncoding = $previousOutputEncoding
    }
    if ($LASTEXITCODE -ne 0) {
        Fail "guard exited $LASTEXITCODE for: $json"
        return $null
    }
    try {
        return (($output | Out-String).Trim() | ConvertFrom-Json).hookSpecificOutput
    }
    catch {
        Fail "guard produced non-JSON output for: $json"
        return $null
    }
}

function Assert-Decision($Name, $Payload, $Expected) {
    $result = Invoke-Guard $Payload
    if ($null -eq $result) { return }
    if ([string]$result.permissionDecision -ne $Expected) {
        Fail "$Name : expected '$Expected' but guard returned '$($result.permissionDecision)' ($($result.permissionDecisionReason))"
    }
    else {
        Write-Output "ok  $Name -> $Expected"
    }
}

# Workspace writes are the normal case and must not be gated.
Assert-Decision 'workspace write allowed' @{
    hook_event_name = 'PreToolUse'
    tool_name       = 'Write'
    tool_input      = @{ file_path = (Join-Path $Root 'README.md') }
} 'allow'

# User-level tool configuration is the boundary the contract names explicitly.
foreach ($case in @(
    @{ Name = 'claude user config'; Path = "$HOME\.claude\CLAUDE.md" },
    @{ Name = 'codex user config'; Path = "$HOME\.codex\config.toml" },
    @{ Name = 'grok user config'; Path = "$HOME\.grok\config.toml" },
    @{ Name = 'opencode user config'; Path = "$HOME\.config\opencode\opencode.json" },
    @{ Name = 'shared agents skills'; Path = "$HOME\.agents\skills\demo\SKILL.md" },
    @{ Name = 'hub runtime dir'; Path = "$HOME\.ai-config-hub\hooks\claude-guard.mjs" }
)) {
    Assert-Decision $case.Name @{
        hook_event_name = 'PreToolUse'
        tool_name       = 'Write'
        tool_input      = @{ file_path = $case.Path }
    } 'ask'
}

# Machine-local and credential-shaped targets ask before writing.
Assert-Decision 'private dir write' @{
    hook_event_name = 'PreToolUse'
    tool_name       = 'Edit'
    tool_input      = @{ file_path = (Join-Path $Root 'private\local-env.md') }
} 'ask'

Assert-Decision 'credential filename' @{
    hook_event_name = 'PreToolUse'
    tool_name       = 'Write'
    tool_input      = @{ file_path = (Join-Path $Root 'deploy\.env') }
} 'ask'

Assert-Decision 'private key filename' @{
    hook_event_name = 'PreToolUse'
    tool_name       = 'Write'
    tool_input      = @{ file_path = (Join-Path $Root 'secrets\id_rsa') }
} 'ask'

# History rewriting and broad destruction must be confirmed first.
foreach ($case in @(
    @{ Name = 'force push'; Command = 'git push --force origin main' },
    @{ Name = 'force push short'; Command = 'git push -f' },
    @{ Name = 'rebase'; Command = 'git rebase -i HEAD~3' },
    @{ Name = 'hard reset'; Command = 'git reset --hard HEAD~2' },
    @{ Name = 'filter branch'; Command = 'git filter-branch --tree-filter "rm x" HEAD' },
    @{ Name = 'branch delete'; Command = 'git branch -D feature' },
    @{ Name = 'clean force'; Command = 'git clean -fdx' },
    @{ Name = 'root wipe'; Command = 'rm -rf /' },
    @{ Name = 'home wipe'; Command = 'rm -rf ~' }
)) {
    Assert-Decision $case.Name @{
        hook_event_name = 'PreToolUse'
        tool_name       = 'Bash'
        tool_input      = @{ command = $case.Command }
    } 'ask'
}

foreach ($case in @(
    @{ Name = 'run tests'; Command = 'npm test' },
    @{ Name = 'normal push'; Command = 'git push origin main' },
    @{ Name = 'remove one file'; Command = 'rm build/output.tmp' }
)) {
    Assert-Decision $case.Name @{
        hook_event_name = 'PreToolUse'
        tool_name       = 'Bash'
        tool_input      = @{ command = $case.Command }
    } 'allow'
}

# Tools outside the guard surface stay untouched.
Assert-Decision 'read tool untouched' @{
    hook_event_name = 'PreToolUse'
    tool_name       = 'Read'
    tool_input      = @{ file_path = "$HOME\.claude\CLAUDE.md" }
} 'allow'

# Unparseable input must fall toward confirmation, not silent permission.
$rawMalformed = '{"tool_name": "Write", "tool_input": {'
$malformedOutput = $rawMalformed | & node $GuardPath 2>&1
$malformedDecision = (($malformedOutput | Out-String).Trim() | ConvertFrom-Json).hookSpecificOutput.permissionDecision
if ($malformedDecision -ne 'ask') {
    Fail "malformed input: expected 'ask' but guard returned '$malformedDecision'"
}
else {
    Write-Output 'ok  malformed input -> ask'
}

if ($Failed) {
    exit 1
}

Write-Output 'Claude guard tests passed'
