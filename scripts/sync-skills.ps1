[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$IncludeCodexLegacy,
    [string]$UserHome
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'
. (Join-Path $PSScriptRoot 'lib\deploy.ps1')

$Manifest = Import-AiConfigHubManagedAssetsManifest $ManifestPath
$ResolvedUserHome = Resolve-AiConfigHubUserHome $UserHome
$SkillDefinitions = if ($null -ne $Manifest.Skills.Definitions -and @($Manifest.Skills.Definitions).Count -gt 0) {
    @($Manifest.Skills.Definitions)
}
else {
    @($Manifest.Skills.Names | ForEach-Object { [pscustomobject]@{ Name = [string]$_ } })
}

$TargetDefinitions = foreach ($definition in $Manifest.Skills.Targets) {
    if ([string]$definition.Name -eq 'CodexLegacy' -and -not $IncludeCodexLegacy) {
        continue
    }
    $definition
}

$Targets = New-Object System.Collections.Generic.List[object]
foreach ($definition in $TargetDefinitions) {
    foreach ($skillDefinition in $SkillDefinitions) {
        $skillName = [string]$skillDefinition.Name
        $Targets.Add([pscustomobject]@{
            Name = "$($definition.Name)-$skillName"
            SkillName = [string]$skillName
            Source = Join-Path (Join-Path $Root ([string]$definition.RenderedRoot)) ([string]$skillName)
            Target = Join-Path (Join-Path $ResolvedUserHome ([string]$definition.UserRelativeRoot)) ([string]$skillName)
        }) | Out-Null
    }
}

if ($Apply) {
    Invoke-AiConfigHubPreflight $Root $ResolvedUserHome -IncludeCodexLegacy:$IncludeCodexLegacy
}

$RetiredSkillNames = @()
if ($null -ne $Manifest.Skills.Retired) {
    $RetiredSkillNames = @($Manifest.Skills.Retired | ForEach-Object { [string]$_ })
}

$Retirements = New-Object System.Collections.Generic.List[object]
foreach ($definition in $TargetDefinitions) {
    foreach ($retiredName in $RetiredSkillNames) {
        $target = Join-Path (Join-Path $ResolvedUserHome ([string]$definition.UserRelativeRoot)) $retiredName
        Assert-AiConfigHubPathInside $target $ResolvedUserHome "$($definition.Name)-retire-$retiredName" | Out-Null
        $exists = Test-Path -LiteralPath $target -PathType Container
        if (-not $exists) {
            Write-Output "retired absent`t$target"
            continue
        }
        $managed = Test-AiConfigHubManagedSkillTarget $target $retiredName
        if (-not $managed) {
            Write-Output "would stop: unmanaged retired target`t$target"
            if ($Apply) {
                throw "Refusing to delete unmanaged retired skill target: $target"
            }
            continue
        }
        Write-Output "would remove retired managed target`t$target"
        $Retirements.Add([pscustomobject]@{
            Name = "$($definition.Name)-retire-$retiredName"
            SkillName = $retiredName
            Target = $target
            ExpectedFingerprint = (Get-AiConfigHubPathFingerprint $target)
        }) | Out-Null
    }
}

foreach ($definition in @($Manifest.Skills.RetiredTargets)) {
    foreach ($retiredName in @($definition.SkillNames | ForEach-Object { [string]$_ })) {
        $target = Join-Path (Join-Path $ResolvedUserHome ([string]$definition.UserRelativeRoot)) $retiredName
        Assert-AiConfigHubPathInside $target $ResolvedUserHome "$($definition.Name)-retire-target-$retiredName" | Out-Null
        if (-not (Test-Path -LiteralPath $target -PathType Container)) {
            Write-Output "retired target absent`t$target"
            continue
        }
        if (-not (Test-AiConfigHubManagedSkillTarget $target $retiredName)) {
            Write-Output "preserved unmanaged retired target`t$target"
            continue
        }
        Write-Output "would remove retired managed target`t$target"
        $Retirements.Add([pscustomobject]@{
            Name = "$($definition.Name)-retire-target-$retiredName"
            SkillName = $retiredName
            Target = $target
            ExpectedFingerprint = (Get-AiConfigHubPathFingerprint $target)
        }) | Out-Null
    }
}

$Changes = New-Object System.Collections.Generic.List[object]
foreach ($item in $Targets) {
    if (-not (Test-Path -LiteralPath $item.Source -PathType Container)) {
        throw "Missing rendered source: $($item.Source). Run scripts\render-skills.ps1 first."
    }
    Assert-AiConfigHubPathInside $item.Target $ResolvedUserHome $item.Name | Out-Null

    $fingerprintBefore = Get-AiConfigHubPathFingerprint $item.Target
    $sourceFingerprint = Get-AiConfigHubPathFingerprint $item.Source
    $targetPathExists = Test-Path -LiteralPath $item.Target
    $targetExists = Test-Path -LiteralPath $item.Target -PathType Container
    if ($targetPathExists -and -not $targetExists) {
        Write-Output "would stop: target is not a directory`t$($item.Source) -> $($item.Target)"
        if ($Apply) {
            throw "Refusing to replace non-directory skill target: $($item.Target)"
        }
        continue
    }
    $targetFingerprint = Get-AiConfigHubPathFingerprint $item.Target
    $managed = -not $targetExists -or (Test-AiConfigHubManagedSkillTarget $item.Target $item.SkillName)
    $fingerprintAfter = Get-AiConfigHubPathFingerprint $item.Target
    if ($fingerprintBefore -ne $fingerprintAfter) {
        throw "Skill target changed while planning; retry the sync: $($item.Target)"
    }
    $status = if (-not $targetExists) {
        'missing target'
    }
    elseif (-not $managed) {
        'would stop: existing unmanaged target'
    }
    elseif ($sourceFingerprint -eq $targetFingerprint) {
        'unchanged'
    }
    else {
        'would update managed target'
    }
    Write-Output "$status`t$($item.Source) -> $($item.Target)"

    if (-not $managed) {
        if ($Apply) {
            throw "Refusing to overwrite unmanaged existing skill target: $($item.Target)"
        }
        continue
    }
    if ($sourceFingerprint -ne $targetFingerprint) {
        $Changes.Add([pscustomobject]@{
            Name = $item.Name
            SkillName = $item.SkillName
            Source = $item.Source
            Target = $item.Target
            ExpectedFingerprint = $fingerprintAfter
        }) | Out-Null
    }
}

if (-not $Apply) {
    Write-Output 'Dry run only. Re-run with -Apply after reviewing the full preflight output.'
    return
}

if ($Changes.Count -eq 0 -and $Retirements.Count -eq 0) {
    Write-Output 'Global skill targets are already up to date.'
    return
}

$context = New-AiConfigHubOperationContext -UserHome $ResolvedUserHome -Pipeline 'skills' -StagingRelativeRoot $Manifest.UserPaths.StagingRoot -BackupRelativeRoot $Manifest.UserPaths.BackupRoot
try {
    foreach ($item in $Changes) {
        $staged = Copy-AiConfigHubStagedDirectory $context $item.Name $item.Source
        Install-AiConfigHubStagedDirectory $context $item.Name $staged $item.Target -ExpectedFingerprint $item.ExpectedFingerprint | Out-Null
        Write-Output "Synced: $($item.Source) -> $($item.Target)"
    }
    foreach ($item in $Retirements) {
        $fingerprint = Get-AiConfigHubPathFingerprint $item.Target
        if ($fingerprint -ne $item.ExpectedFingerprint) {
            throw "Retired skill target changed while applying; retry the sync: $($item.Target)"
        }
        $backup = Join-Path $context.BackupRoot ($item.Name + '.bak')
        if (Test-Path -LiteralPath $backup) {
            Remove-Item -LiteralPath $backup -Recurse -Force
        }
        [System.IO.Directory]::Move($item.Target, $backup)
        $context.Changes.Add([pscustomobject]@{
            Kind = 'Directory'
            Name = $item.Name
            Target = $item.Target
            Backup = $backup
            Existed = $true
        }) | Out-Null
        Write-Output "Removed retired managed skill: $($item.Target)"
    }
    Complete-AiConfigHubOperation $context
}
catch {
    Throw-AiConfigHubOperationFailure $context $_
}
