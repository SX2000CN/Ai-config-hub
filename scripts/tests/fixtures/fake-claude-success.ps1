$ErrorActionPreference = 'Stop'

$target = Join-Path $env:USERPROFILE '.claude.json'
$allowedRoot = [System.IO.Path]::GetFullPath($env:AI_CONFIG_HUB_TEST_ALLOWED_HOME_ROOT).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
$resolvedTarget = [System.IO.Path]::GetFullPath($target)
if (-not $resolvedTarget.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Fake Claude CLI refused a target outside the temporary test root: $resolvedTarget"
}

$config = Get-Content -Raw -Encoding UTF8 -LiteralPath $target | ConvertFrom-Json
if ($null -ne $config.mcpServers.pencil) {
    throw 'sync-mcp must remove the desktop Pencil registration before invoking Claude CLI.'
}

$command = (Resolve-Path -LiteralPath $env:AI_CONFIG_HUB_PENCIL_MCP_COMMAND).Path
$app = $env:AI_CONFIG_HUB_PENCIL_MCP_APP
$pencil = [pscustomobject]@{
    type = 'stdio'
    command = $command
    args = @('--app', $app, '--agent', 'claudeCode')
}
$config.mcpServers | Add-Member -MemberType NoteProperty -Name pencil -Value $pencil -Force

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($target, (($config | ConvertTo-Json -Depth 32) + "`n"), $utf8)

if (-not [string]::IsNullOrWhiteSpace($env:AI_CONFIG_HUB_TEST_CLAUDE_LOG)) {
    [System.IO.File]::AppendAllText($env:AI_CONFIG_HUB_TEST_CLAUDE_LOG, (($args -join "`t") + "`n"), $utf8)
}

exit 0
