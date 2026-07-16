[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$UserHome
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'
. (Join-Path $PSScriptRoot 'lib\deploy.ps1')

$Manifest = Import-AiConfigHubManagedAssetsManifest $ManifestPath
$ResolvedUserHome = Resolve-AiConfigHubUserHome $UserHome
$Targets = foreach ($target in $Manifest.Rules.Targets) {
    [pscustomobject]@{
        Name = [string]$target.Name
        Source = Join-Path $Root ([string]$target.Rendered)
        Target = Join-Path $ResolvedUserHome ([string]$target.UserRelativePath)
    }
}

foreach ($item in $Targets) {
    if (-not (Test-Path -LiteralPath $item.Source -PathType Leaf)) {
        throw "Missing rendered source: $($item.Source). Run scripts\render.ps1 first."
    }
    Assert-AiConfigHubPathInside $item.Target $ResolvedUserHome $item.Name | Out-Null
}

if ($Apply) {
    Invoke-AiConfigHubPreflight $Root $ResolvedUserHome
}

$Changes = New-Object System.Collections.Generic.List[object]
foreach ($item in $Targets) {
    $fingerprintBefore = Get-AiConfigHubPathFingerprint $item.Target
    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.Source).Hash
    $targetPathExists = Test-Path -LiteralPath $item.Target
    $targetExists = Test-Path -LiteralPath $item.Target -PathType Leaf
    if ($targetPathExists -and -not $targetExists) {
        Write-Output "would stop: target is not a file`t$($item.Source) -> $($item.Target)"
        if ($Apply) {
            throw "Refusing to replace non-file rule target: $($item.Target)"
        }
        continue
    }
    $targetHash = if ($targetExists) { (Get-FileHash -Algorithm SHA256 -LiteralPath $item.Target).Hash } else { '' }
    $fingerprintAfter = Get-AiConfigHubPathFingerprint $item.Target
    if ($fingerprintBefore -ne $fingerprintAfter) {
        throw "Rule target changed while planning; retry the sync: $($item.Target)"
    }
    $status = if (-not $targetExists) { 'missing target' } elseif ($sourceHash -eq $targetHash) { 'unchanged' } else { 'would update' }
    if ($sourceHash -ne $targetHash) {
        $Changes.Add([pscustomobject]@{
            Name = $item.Name
            Source = $item.Source
            Target = $item.Target
            ExpectedFingerprint = $fingerprintAfter
        }) | Out-Null
    }
    Write-Output "$status`t$($item.Source) -> $($item.Target)"
}

if (-not $Apply) {
    Write-Output 'Dry run only. Re-run with -Apply after reviewing the full preflight output.'
    return
}

if ($Changes.Count -eq 0) {
    Write-Output 'Global rule targets are already up to date.'
    return
}

$context = New-AiConfigHubOperationContext -UserHome $ResolvedUserHome -Pipeline 'rules' -StagingRelativeRoot $Manifest.UserPaths.StagingRoot -BackupRelativeRoot $Manifest.UserPaths.BackupRoot
try {
    foreach ($item in $Changes) {
        $staged = Copy-AiConfigHubStagedFile $context ($item.Name + '.md') $item.Source
        Install-AiConfigHubStagedFile $context $item.Name $staged $item.Target -ExpectedFingerprint $item.ExpectedFingerprint | Out-Null
        Write-Output "Synced: $($item.Source) -> $($item.Target)"
    }
    Complete-AiConfigHubOperation $context
}
catch {
    Throw-AiConfigHubOperationFailure $context $_
}
