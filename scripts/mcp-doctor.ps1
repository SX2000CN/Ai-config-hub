[CmdletBinding()]
param(
    [string]$Profile,
    [string]$UserHome,
    [ValidateSet('Source', 'Readiness', 'Smoke')][string]$Mode = 'Readiness',
    [switch]$Json,
    [switch]$AllowDegraded,
    [switch]$AllowNetwork
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib\deploy.ps1')
. (Join-Path $PSScriptRoot 'mcp-local.ps1')
$Manifest = Import-AiConfigHubManagedAssetsManifest (Join-Path $Root 'config\managed-assets.psd1')
$ResolvedUserHome = Resolve-AiConfigHubUserHome $UserHome
$ProfileDefinition = Get-AiConfigHubMcpProfile $Manifest $Profile
Assert-AiConfigHubNodeVersion | Out-Null

$readiness = Get-AiConfigHubMcpReadiness -Manifest $Manifest -Root $Root -UserHome $ResolvedUserHome -Profile $ProfileDefinition -Mode $Mode
if ($Json) {
    $readiness | ConvertTo-Json -Depth 8
}
else {
    foreach ($item in $readiness.Items) {
        $status = if ($item.Ready) { 'READY' } elseif ($item.Optional) { 'DEGRADED' } else { 'BLOCKED' }
        $package = if ([string]::IsNullOrWhiteSpace([string]$item.Package)) { 'managed-runtime' } else { "$($item.Package)@$($item.ExpectedVersion)" }
        $toolCount = if ($null -eq $item.ActualToolCount) { "unknown ($($item.ToolCountReason))" } else { "$($item.ActualToolCount)/$($item.ExpectedToolCount)" }
        $drift = if ($null -eq $item.Drift) { "incomparable ($($item.DriftReason))" } elseif ($item.Drift) { "yes ($($item.DriftReason))" } else { 'no' }
        Write-Output "[$status]`t$($item.Name)`t$package`t$($item.Runtime)`t$($item.Reason)"
        Write-Output "  source: version=$($item.SourceVersion) hash=$($item.SourceHash) path=$($item.SourcePath)"
        Write-Output "  install: version=$($item.InstalledVersion) hash=$($item.InstalledHash) path=$($item.InstalledPath) drift=$drift"
        Write-Output "  tools: $toolCount; preferred=$(@($item.PreferredFor) -join ', ')"
    }
    foreach ($conflict in $readiness.RoutingConflicts) { Write-Output "[ROUTING-CONFLICT]`t$($conflict.PreferredFor)`t$($conflict.Servers -join ', ')" }
    Write-Output "Profile $($readiness.Profile): $(@($readiness.Items | Where-Object Ready).Count)/$($readiness.Items.Count) ready ($($readiness.Mode))"
}

$canProceed = if ($AllowDegraded) { [bool]$readiness.DegradedReady } else { [bool]$readiness.Ready }
if (-not $canProceed) {
    throw "MCP profile '$($readiness.Profile)' is not ready. Install required runtimes or use -AllowDegraded for optional servers."
}
