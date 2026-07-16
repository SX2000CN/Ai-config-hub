[CmdletBinding()]
param(
    [string]$UserHome,
    [switch]$IncludeCodexLegacy
)

$ErrorActionPreference = 'Stop'

$resolvedHome = [System.IO.Path]::GetFullPath($UserHome)
$allowedRoot = [System.IO.Path]::GetFullPath($env:AI_CONFIG_HUB_TEST_ALLOWED_HOME_ROOT).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if (-not $resolvedHome.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Test preflight refused a UserHome outside the temporary test root: $resolvedHome"
}

if (-not [string]::IsNullOrWhiteSpace($env:AI_CONFIG_HUB_TEST_PREFLIGHT_LOG)) {
    Add-Content -Encoding UTF8 -LiteralPath $env:AI_CONFIG_HUB_TEST_PREFLIGHT_LOG -Value $resolvedHome
}

if (-not [string]::IsNullOrWhiteSpace($env:AI_CONFIG_HUB_TEST_PREFLIGHT_MUTATION_TARGET)) {
    $mutationTarget = [System.IO.Path]::GetFullPath($env:AI_CONFIG_HUB_TEST_PREFLIGHT_MUTATION_TARGET)
    if (-not $mutationTarget.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Test preflight refused a mutation target outside the temporary test root: $mutationTarget"
    }
    Copy-Item -LiteralPath $env:AI_CONFIG_HUB_TEST_PREFLIGHT_MUTATION_SOURCE -Destination $mutationTarget -Force
    Remove-Item Env:AI_CONFIG_HUB_TEST_PREFLIGHT_MUTATION_TARGET
    Remove-Item Env:AI_CONFIG_HUB_TEST_PREFLIGHT_MUTATION_SOURCE
}

Write-Output "Test preflight passed for $resolvedHome"
& "$env:SystemRoot\System32\cmd.exe" /c exit 0
