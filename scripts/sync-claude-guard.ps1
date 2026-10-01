[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$UserHome
)

# Deploys the Claude Code PreToolUse guard and registers it in ~/.claude/settings.json.
#
# Why a hook and not a rules line: a boundary written as prose is obeyed at the model's
# discretion and decays with the model generation. Enforcement that lives outside the
# model's judgement does not. This script is the migration of the boundary from the
# rules file into that enforced layer.
#
# Ownership is signature based, matching the MCP pipeline: a hooks.PreToolUse entry is
# managed when its command names the deployed guard. Everything else in settings.json
# belongs to the user or to Claude Code and is preserved verbatim.

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib\deploy.ps1')

$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'
$Manifest = Import-AiConfigHubManagedAssetsManifest $ManifestPath
$ResolvedUserHome = Resolve-AiConfigHubUserHome $UserHome

$GuardSource = Join-Path $Root 'hooks\claude\guard.mjs'
$GuardTarget = Join-Path (Join-Path $ResolvedUserHome '.ai-config-hub\hooks') 'claude-guard.mjs'
$SettingsTarget = Join-Path (Join-Path $ResolvedUserHome '.claude') 'settings.json'
$Matcher = 'Write|Edit|MultiEdit|NotebookEdit|Bash'
$GuardCommandName = 'claude-guard.mjs'

if (-not (Test-Path -LiteralPath $GuardSource -PathType Leaf)) {
    throw "Missing guard source: $GuardSource"
}
Assert-AiConfigHubPathInside $GuardTarget $ResolvedUserHome 'claude-guard-deploy' | Out-Null
Assert-AiConfigHubPathInside $SettingsTarget $ResolvedUserHome 'claude-guard-settings' | Out-Null

function Test-ManagedHookEntry($Entry) {
    foreach ($hook in @($Entry.hooks)) {
        if ([string]$hook.command -like "*$script:GuardCommandName*") { return $true }
    }
    return $false
}

function Get-PlannedSettings {
    $settings = if (Test-Path -LiteralPath $SettingsTarget -PathType Leaf) {
        Get-Content -Raw -Encoding UTF8 -LiteralPath $SettingsTarget | ConvertFrom-Json
    }
    else {
        [pscustomobject]@{}
    }

    $preToolUse = if ($null -ne $settings.hooks) { @($settings.hooks.PreToolUse) } else { @() }
    $kept = @($preToolUse | Where-Object { -not (Test-ManagedHookEntry $_) })
    $dropped = @($preToolUse | Where-Object { Test-ManagedHookEntry $_ })

    $managed = [pscustomobject][ordered]@{
        matcher = $Matcher
        hooks   = @([pscustomobject][ordered]@{
                type    = 'command'
                command = "node `"$GuardTarget`""
            })
    }

    $hooksNode = if ($null -ne $settings.hooks) { $settings.hooks } else { [pscustomobject]@{} }
    $hooksNode | Add-Member -MemberType NoteProperty -Name 'PreToolUse' -Value (@($kept) + @($managed)) -Force

    $settings | Add-Member -MemberType NoteProperty -Name 'hooks' -Value $hooksNode -Force

    return [pscustomobject]@{
        Settings = $settings
        Kept     = $kept
        Dropped  = $dropped
    }
}

function Test-PreservedKeys($Before, $After) {
    foreach ($property in @($Before.PSObject.Properties)) {
        if ($property.Name -eq 'hooks') { continue }
        $afterProperty = $After.PSObject.Properties[$property.Name]
        if ($null -eq $afterProperty) {
            throw "settings.json merge dropped key: $($property.Name)"
        }
        $beforeJson = $property.Value | ConvertTo-Json -Depth 32 -Compress
        $afterJson = $afterProperty.Value | ConvertTo-Json -Depth 32 -Compress
        if ($beforeJson -ne $afterJson) {
            throw "settings.json merge changed key: $($property.Name)"
        }
    }
}

if ($Apply) {
    Invoke-AiConfigHubPreflight $Root $ResolvedUserHome
}

$existingSettings = if (Test-Path -LiteralPath $SettingsTarget -PathType Leaf) {
    Get-Content -Raw -Encoding UTF8 -LiteralPath $SettingsTarget | ConvertFrom-Json
}
else {
    $null
}

$plan = Get-PlannedSettings
$plannedJson = $plan.Settings | ConvertTo-Json -Depth 32

if ($null -ne $existingSettings) {
    Test-PreservedKeys $existingSettings $plan.Settings
}

Write-Output "guard`t$GuardSource -> $GuardTarget"
if (Test-Path -LiteralPath $GuardTarget -PathType Leaf) {
    $same = (Get-FileHash -LiteralPath $GuardSource).Hash -eq (Get-FileHash -LiteralPath $GuardTarget).Hash
    Write-Output "$(if ($same) { 'unchanged' } else { 'would update' })`tdeployed guard"
}
else {
    Write-Output 'missing target`tdeployed guard'
}

Write-Output "settings`t$SettingsTarget"
if ($null -eq $existingSettings) {
    Write-Output 'missing target`tsettings.json (would create)'
}
foreach ($entry in $plan.Dropped) {
    Write-Output "would replace managed PreToolUse entry`t$($entry.matcher)"
}
Write-Output "would add managed PreToolUse entry`t$Matcher"
Write-Output "preserved keys`t$((@($existingSettings.PSObject.Properties | Where-Object { $_.Name -ne 'hooks' }) | ForEach-Object { $_.Name }) -join ', ')"

if (-not $Apply) {
    Write-Output 'Dry run only. Re-run with -Apply after reviewing the full preflight output.'
    return
}

$context = New-AiConfigHubOperationContext -UserHome $ResolvedUserHome -Pipeline 'claude-guard' -StagingRelativeRoot $Manifest.UserPaths.StagingRoot -BackupRelativeRoot $Manifest.UserPaths.BackupRoot
try {
    $stagedGuard = New-AiConfigHubStagedFile $context 'claude-guard.mjs' (Get-Content -Raw -Encoding UTF8 -LiteralPath $GuardSource)
    Install-AiConfigHubStagedFile $context 'claude-guard' $stagedGuard $GuardTarget -ExpectedFingerprint (Get-AiConfigHubPathFingerprint $GuardTarget) | Out-Null

    $stagedSettings = New-AiConfigHubStagedFile $context 'settings.json' ($plannedJson + "`n")
    Install-AiConfigHubStagedFile $context 'claude-settings' $stagedSettings $SettingsTarget -ExpectedFingerprint (Get-AiConfigHubPathFingerprint $SettingsTarget) | Out-Null

    # Post-write verification: the settings file must still parse and keep every
    # non-managed key exactly as it was.
    $written = Get-Content -Raw -Encoding UTF8 -LiteralPath $SettingsTarget | ConvertFrom-Json
    if ($null -ne $existingSettings) {
        Test-PreservedKeys $existingSettings $written
    }
    $managedNow = @($written.hooks.PreToolUse | Where-Object { Test-ManagedHookEntry $_ })
    if ($managedNow.Count -ne 1) {
        throw "expected exactly one managed PreToolUse entry after Apply, found $($managedNow.Count)"
    }

    Complete-AiConfigHubOperation $context
    Write-Output "Synced: claude-guard`t$GuardTarget"
    Write-Output "Synced: claude-settings`t$SettingsTarget"
}
catch {
    Throw-AiConfigHubOperationFailure $context $_
}
