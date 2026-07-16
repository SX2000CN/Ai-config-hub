[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root 'config\managed-assets.psd1'

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing managed assets manifest: $ManifestPath"
}

$Manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath
$SkillDefinitions = if ($null -ne $Manifest.Skills.Definitions -and @($Manifest.Skills.Definitions).Count -gt 0) {
    @($Manifest.Skills.Definitions)
}
else {
    @($Manifest.Skills.Names | ForEach-Object { [pscustomobject]@{ Name = [string]$_ } })
}

function Assert-Path($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required path: $Path"
    }
}

function Copy-CleanDirectory($Source, $Destination) {
    Assert-Path $Source

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
}

function Copy-SharedPayload($SharedSource, $Destination) {
    foreach ($item in Get-ChildItem -LiteralPath $SharedSource -Force) {
        $target = Join-Path $Destination $item.Name
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
        Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
    }
}

function Get-RelativePath($BasePath, $Path) {
    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $full = [System.IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside expected base: $full"
    }
    return $full.Substring($base.Length).Replace('/', '\')
}

function Add-ExpectedFiles($Map, $SourceRoot) {
    foreach ($file in Get-ChildItem -LiteralPath $SourceRoot -Recurse -File) {
        $relative = Get-RelativePath $SourceRoot $file.FullName
        $Map[$relative] = $file.FullName
    }
}

function Test-RenderedDirectory($ToolSource, $SharedSource, $Destination) {
    $messages = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
        $messages.Add("ERROR: Missing rendered skill directory: $Destination") | Out-Null
        return [pscustomobject]@{
            Matches = $false
            Messages = @($messages)
        }
    }

    $expected = @{}
    Add-ExpectedFiles $expected $ToolSource
    Add-ExpectedFiles $expected $SharedSource

    $actual = @{}
    foreach ($file in Get-ChildItem -LiteralPath $Destination -Recurse -File) {
        $relative = Get-RelativePath $Destination $file.FullName
        $actual[$relative] = $file.FullName
    }

    $matches = $true
    foreach ($relative in $expected.Keys) {
        if (-not $actual.ContainsKey($relative)) {
            $messages.Add("ERROR: Missing rendered skill file: $(Join-Path $Destination $relative)") | Out-Null
            $matches = $false
            continue
        }

        $expectedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $expected[$relative]).Hash
        $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $actual[$relative]).Hash
        if ($expectedHash -ne $actualHash) {
            $messages.Add("ERROR: Rendered skill file is out of date: $($actual[$relative])") | Out-Null
            $matches = $false
        }
    }

    foreach ($relative in $actual.Keys) {
        if (-not $expected.ContainsKey($relative)) {
            $messages.Add("ERROR: Unexpected rendered skill file: $($actual[$relative])") | Out-Null
            $matches = $false
        }
    }

    return [pscustomobject]@{
        Matches = $matches
        Messages = @($messages)
    }
}

$failed = $false
foreach ($skillDefinition in $SkillDefinitions) {
    $skillName = [string]$skillDefinition.Name
    $sharedSource = Join-Path $Root "skills\shared\$skillName"
    Assert-Path $sharedSource

    foreach ($target in $Manifest.Skills.Targets) {
        $toolSource = Join-Path (Join-Path $Root ([string]$target.SourceRoot)) ([string]$skillName)
        $destination = Join-Path (Join-Path $Root ([string]$target.RenderedRoot)) ([string]$skillName)
        Assert-Path $toolSource

        if ($Check) {
            $result = Test-RenderedDirectory $toolSource $sharedSource $destination
            foreach ($message in $result.Messages) {
                Write-Output $message
            }
            if ($result.Matches) {
                Write-Output "Verified $destination"
            }
            else {
                $failed = $true
            }
            continue
        }

        Copy-CleanDirectory $toolSource $destination
        Copy-SharedPayload $sharedSource $destination
        Write-Output "Rendered $destination"
    }
}

if ($failed) {
    throw 'Skill render check failed. Run scripts\render-skills.ps1 to refresh rendered skills.'
}
