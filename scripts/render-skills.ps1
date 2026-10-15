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
$SkillNames = @($Manifest.Skills.Names | ForEach-Object { [string]$_ })

function Assert-Path($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required path: $Path"
    }
}

function Assert-RenderedDestination($Destination) {
    $renderedRoot = [System.IO.Path]::GetFullPath((Join-Path $Root 'skills\rendered')).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $destinationFull = [System.IO.Path]::GetFullPath($Destination)
    if (-not $destinationFull.StartsWith($renderedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Rendered skill destination must stay under skills\rendered: $destinationFull"
    }
}

function Copy-PackageDirectory($Source, $Destination) {
    Assert-Path $Source

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
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

function Test-RenderedDirectory($PackageSource, $Destination) {
    $messages = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
        $messages.Add("ERROR: Missing rendered skill directory: $Destination") | Out-Null
        return [pscustomobject]@{
            Matches = $false
            Messages = @($messages)
        }
    }

    $expected = @{}
    Add-ExpectedFiles $expected $PackageSource

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
foreach ($relativeRoot in @($Manifest.Skills.RetiredRenderedRoots)) {
    $retiredRoot = [System.IO.Path]::GetFullPath((Join-Path $Root ([string]$relativeRoot)))
    $repositoryRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $retiredRoot.StartsWith($repositoryRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Retired rendered root is outside the repository: $retiredRoot"
    }
    if (-not (Test-Path -LiteralPath $retiredRoot)) {
        continue
    }
    if ($Check) {
        Write-Output "INFO: Retaining legacy rendered skill root as a cleanup candidate: $retiredRoot"
    }
    else {
        Write-Output "Retaining legacy rendered skill root as a cleanup candidate: $retiredRoot"
    }
}

foreach ($skillName in $SkillNames) {
    if ($skillName -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        throw "Invalid skill name in managed assets manifest: $skillName"
    }
    $packageSource = Join-Path $Root "skills\shared\$skillName"
    Assert-Path $packageSource

    foreach ($target in $Manifest.Skills.Targets) {
        $destination = Join-Path (Join-Path $Root ([string]$target.RenderedRoot)) ([string]$skillName)
        Assert-RenderedDestination $destination

        if ($Check) {
            $result = Test-RenderedDirectory $packageSource $destination
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

        Copy-PackageDirectory $packageSource $destination
        Write-Output "Rendered $destination"
    }
}

if ($failed) {
    throw 'Skill render check failed. Run scripts\render-skills.ps1 to refresh rendered skills.'
}
