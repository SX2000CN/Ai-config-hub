[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$Profile,
    [string]$UserHome
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'
. (Join-Path $PSScriptRoot 'lib\deploy.ps1')
. (Join-Path $PSScriptRoot 'lib\managed-assets.ps1')

$Manifest = Import-AiConfigHubManagedAssetsManifest $ManifestPath
$ResolvedUserHome = Resolve-AiConfigHubUserHome $UserHome
$ProfileDefinition = Get-AiConfigHubMcpProfile $Manifest $Profile
$ProfileName = [string]$ProfileDefinition.Name
$TargetDefinition = $Manifest.Mcp.Targets | Where-Object { [string]$_.Name -eq 'OpenCode' } | Select-Object -First 1
if ($null -eq $TargetDefinition) {
    throw 'OpenCode MCP target is not registered in config/managed-assets.psd1.'
}

$SourcePath = Get-AiConfigHubMcpRenderedPath $Root $Manifest 'OpenCode' $ProfileName
if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
    throw "Missing rendered OpenCode MCP source: $SourcePath. Run scripts\render-mcp.ps1 first."
}

$TargetPath = Join-Path $ResolvedUserHome ([string]$TargetDefinition.UserRelativePath)
Assert-AiConfigHubPathInside $TargetPath $ResolvedUserHome 'OpenCode MCP target' | Out-Null

function Get-PropertyNames($Object) {
    if ($null -eq $Object) { return @() }
    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Resolve-UserPath($Path) {
    $text = [string]$Path
    if ($text.StartsWith('~\') -or $text.StartsWith('~/')) {
        return Join-Path $ResolvedUserHome $text.Substring(2)
    }
    return $text
}

function ConvertTo-ResolvedOpenCodeEntry($Entry) {
    $result = [ordered]@{}
    $result.type = [string]$Entry.type
    $result.command = @($Entry.command | ForEach-Object { Resolve-UserPath $_ })
    $result.enabled = [bool]$Entry.enabled
    $result.timeout = [int]$Entry.timeout
    return [pscustomobject]$result
}

function New-OpenCodeServerEntry($Server) {
    $command = @([string]$Server.command) + @($Server.args)
    if (-not [string]::IsNullOrWhiteSpace([string]$Server.runtime_entry)) {
        $command += @([string]$Server.runtime_entry)
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$Server.repo_script)) {
        $command += @((Join-Path $Root ([string]$Server.repo_script)))
    }
    if ($null -ne $Server.script_args) {
        $command += @($Server.script_args)
    }
    $timeout = 30000
    if ($null -ne $Server.startup_timeout_ms) {
        $timeout = [Math]::Max(30000, [int]$Server.startup_timeout_ms)
    }
    return [ordered]@{
        type = 'local'
        command = @($command)
        enabled = $true
        timeout = $timeout
    }
}

function ConvertTo-CanonicalObject($Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [string] -or $Value -is [ValueType]) { return $Value }
    if ($Value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in @($Value.Keys | Sort-Object)) {
            $result[[string]$key] = ConvertTo-CanonicalObject $Value[$key]
        }
        return $result
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        return @($Value | ForEach-Object { ConvertTo-CanonicalObject $_ })
    }
    $ordered = [ordered]@{}
    foreach ($property in @($Value.PSObject.Properties | Sort-Object Name)) {
        $ordered[[string]$property.Name] = ConvertTo-CanonicalObject $property.Value
    }
    return $ordered
}

function Get-StableJson($Value) {
    return (ConvertTo-CanonicalObject $Value | ConvertTo-Json -Depth 64 -Compress)
}

function Test-ManagedEntryOwnership($Existing, $Desired) {
    if ($null -eq $Existing) { return $false }
    return (Get-StableJson $Existing) -eq (Get-StableJson $Desired)
}

function ConvertTo-OpenCodeSignature($Signature) {
    $command = if ($Signature.Command -is [System.Array]) {
        @($Signature.Command | ForEach-Object { Resolve-UserPath $_ })
    }
    else {
        @([string]$Signature.Command) + @($Signature.Args | ForEach-Object { Resolve-UserPath $_ })
    }
    return [pscustomobject]@{
        type = [string]$Signature.Type
        command = @($command)
        enabled = [bool]$Signature.Enabled
        timeout = [int]$Signature.Timeout
    }
}

function Test-RetiredOpenCodeEntry($Name, $Entry) {
    if (@($Manifest.Mcp.RetiredLocalServers | ForEach-Object { [string]$_ }) -contains $Name) {
        $commandText = (@($Entry.command) | ForEach-Object { [string]$_ }) -join ' '
        return $commandText -match '(?i)pencil|--app'
    }
    foreach ($definition in @($Manifest.Mcp.RetiredServers)) {
        if ([string]$definition.Name -ne $Name) { continue }
        foreach ($signature in @($definition.OpenCodeSignatures)) {
            if (Test-ManagedEntryOwnership $Entry (ConvertTo-OpenCodeSignature $signature)) { return $true }
        }
    }
    return $false
}

$fragment = Get-Content -Raw -Encoding UTF8 -LiteralPath $SourcePath | ConvertFrom-Json
if ($null -eq $fragment.mcp) {
    throw "Rendered OpenCode MCP source is missing mcp: $SourcePath"
}

$desiredMcp = [ordered]@{}
foreach ($property in @($fragment.mcp.PSObject.Properties)) {
    $desiredMcp[[string]$property.Name] = ConvertTo-ResolvedOpenCodeEntry $property.Value
}

$managedEntries = @{}
$managedNames = @(
    foreach ($definition in @($Manifest.Mcp.Servers)) {
        $source = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $Root ([string]$definition.Source)) | ConvertFrom-Json
        foreach ($serverName in Get-PropertyNames $source.servers) {
            $managedEntries[$serverName] = ConvertTo-ResolvedOpenCodeEntry (New-OpenCodeServerEntry $source.servers.$serverName)
            $serverName
        }
    }
)
$activeNames = @($desiredMcp.Keys | ForEach-Object { [string]$_ })

$targetExists = Test-Path -LiteralPath $TargetPath
if ($targetExists -and -not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
    throw "OpenCode config target exists but is not a file: $TargetPath"
}
$fingerprintBefore = Get-AiConfigHubPathFingerprint $TargetPath

if ($targetExists) {
    try {
        $config = Get-Content -Raw -Encoding UTF8 -LiteralPath $TargetPath | ConvertFrom-Json
    }
    catch {
        throw "Invalid OpenCode config JSON: $TargetPath`: $($_.Exception.Message)"
    }
}
else {
    $config = [pscustomobject]([ordered]@{ '$schema' = 'https://opencode.ai/config.json' })
}

$existingMcp = if ($null -eq $config.mcp) { [pscustomobject]@{} } else { $config.mcp }
if ($null -eq $existingMcp -or ($existingMcp -is [ValueType]) -or $existingMcp -is [string]) {
    throw "OpenCode config mcp must be an object: $TargetPath"
}

$mergedMcp = [ordered]@{}
$actions = New-Object System.Collections.Generic.List[string]
$conflicts = New-Object System.Collections.Generic.List[string]

foreach ($property in @($existingMcp.PSObject.Properties)) {
    $name = [string]$property.Name
    $existing = $property.Value
    if (Test-RetiredOpenCodeEntry $name $existing) {
        $actions.Add("remove retired mcp.$name") | Out-Null
        continue
    }
    if ($managedNames -contains $name -and $activeNames -contains $name) {
        $desired = $desiredMcp[$name]
        if (Test-ManagedEntryOwnership $existing $desired) {
            $mergedMcp[$name] = $desired
            if ((Get-StableJson $existing) -ne (Get-StableJson $desired)) {
                $actions.Add("update managed mcp.$name") | Out-Null
            }
        }
        else {
            $mergedMcp[$name] = $existing
            $message = "custom mcp.$name conflicts with active managed profile $ProfileName"
            $actions.Add("conflict $message") | Out-Null
            $conflicts.Add($message) | Out-Null
        }
        continue
    }
    if ($managedNames -contains $name -and $activeNames -notcontains $name) {
        $owned = Test-ManagedEntryOwnership $existing $managedEntries[$name]
        if ($owned) {
            $actions.Add("remove owned inactive mcp.$name") | Out-Null
        }
        else {
            $actions.Add("preserve custom inactive mcp.$name") | Out-Null
            $mergedMcp[$name] = $existing
        }
        continue
    }
    $mergedMcp[$name] = $existing
    $actions.Add("preserve custom mcp.$name") | Out-Null
}

foreach ($name in $activeNames) {
    if ($null -eq $existingMcp.PSObject.Properties[$name]) {
        $mergedMcp[$name] = $desiredMcp[$name]
        $actions.Add("add managed mcp.$name") | Out-Null
    }
}

$mergedMcpObject = [pscustomobject]$mergedMcp
if ($null -eq $config.PSObject.Properties['mcp']) {
    $config | Add-Member -MemberType NoteProperty -Name 'mcp' -Value $mergedMcpObject
}
else {
    $config.mcp = $mergedMcpObject
}
$content = ($config | ConvertTo-Json -Depth 64) + "`n"
$fingerprintAfter = Get-AiConfigHubPathFingerprint $TargetPath
if ($fingerprintBefore -ne $fingerprintAfter) {
    throw "OpenCode MCP target changed while planning; retry the sync: $TargetPath"
}

Write-Output "profile`t$ProfileName"
Write-Output "target`t$TargetPath"
foreach ($action in $actions) { Write-Output "  - $action" }
if ($conflicts.Count -gt 0) {
    Write-Output "ownership conflicts`t$($conflicts -join '; ')"
}

if (-not $Apply) {
    Write-Output 'Dry run only. Re-run with -Apply after reviewing the full preflight output.'
    return
}

if ($conflicts.Count -gt 0) {
    throw "Managed OpenCode MCP ownership conflicts must be resolved before Apply:`n$($conflicts -join "`n")"
}

Invoke-AiConfigHubPreflight $Root $ResolvedUserHome | Out-Null

if ((Get-StableJson $config) -eq (Get-StableJson $(if ($targetExists) { Get-Content -Raw -Encoding UTF8 -LiteralPath $TargetPath | ConvertFrom-Json } else { $null }))) {
    Write-Output 'OpenCode MCP target is already up to date.'
    return
}

$context = New-AiConfigHubOperationContext -UserHome $ResolvedUserHome -Pipeline 'mcp-opencode' -StagingRelativeRoot $Manifest.UserPaths.StagingRoot -BackupRelativeRoot $Manifest.UserPaths.BackupRoot
try {
    $staged = New-AiConfigHubStagedFile $context 'opencode.json' $content
    Install-AiConfigHubStagedFile $context 'opencode' $staged $TargetPath -ExpectedFingerprint $fingerprintAfter | Out-Null
    Get-Content -Raw -Encoding UTF8 -LiteralPath $TargetPath | ConvertFrom-Json | Out-Null
    Complete-AiConfigHubOperation $context
    Write-Output "Synced: opencode`t$TargetPath"
}
catch {
    Throw-AiConfigHubOperationFailure $context $_
}
