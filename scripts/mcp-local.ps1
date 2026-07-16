$ErrorActionPreference = 'Stop'

function Add-AiConfigHubPencilCandidate {
    param([System.Collections.Generic.List[object]]$Candidates, [string]$Path, [string]$App, [string]$Source)
    if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($App)) { return }
    $Candidates.Add([pscustomobject]@{ Path = $Path; App = $App; Source = $Source }) | Out-Null
}

function Get-AiConfigHubPencilMcpCandidates {
    param([string]$UserHome)
    $candidates = New-Object System.Collections.Generic.List[object]
    $resolvedUserHome = if ([string]::IsNullOrWhiteSpace($UserHome)) { [Environment]::GetFolderPath('UserProfile') } else { [System.IO.Path]::GetFullPath($UserHome) }
    if (-not [string]::IsNullOrWhiteSpace($env:AI_CONFIG_HUB_PENCIL_MCP_COMMAND)) {
        $app = if ([string]::IsNullOrWhiteSpace($env:AI_CONFIG_HUB_PENCIL_MCP_APP)) { 'visual_studio_code' } else { $env:AI_CONFIG_HUB_PENCIL_MCP_APP }
        Add-AiConfigHubPencilCandidate $candidates $env:AI_CONFIG_HUB_PENCIL_MCP_COMMAND $app 'AI_CONFIG_HUB_PENCIL_MCP_COMMAND'
    }
    $pencilMcpRoot = Join-Path $resolvedUserHome '.pencil\mcp'
    foreach ($app in @('visual_studio_code', 'cursor', 'windsurf')) {
        Add-AiConfigHubPencilCandidate $candidates (Join-Path $pencilMcpRoot "$app\out\mcp-server-windows-x64.exe") $app "Pencil $app MCP cache"
    }
    if (Test-Path -LiteralPath $pencilMcpRoot) {
        Get-ChildItem -LiteralPath $pencilMcpRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Name -ne 'desktop') { Add-AiConfigHubPencilCandidate $candidates (Join-Path $_.FullName 'out\mcp-server-windows-x64.exe') $_.Name "Pencil $($_.Name) MCP cache" }
        }
    }
    $seen = New-Object System.Collections.Generic.HashSet[string]
    foreach ($candidate in $candidates) {
        if ($seen.Add("$($candidate.Path)|$($candidate.App)")) { $candidate }
    }
}

function Resolve-AiConfigHubPencilMcpServer {
    param([string]$UserHome)
    foreach ($candidate in Get-AiConfigHubPencilMcpCandidates $UserHome) {
        if (Test-Path -LiteralPath $candidate.Path -PathType Leaf) {
            return [pscustomobject]@{ Command = (Resolve-Path -LiteralPath $candidate.Path).Path; App = $candidate.App; Source = $candidate.Source; StartupTimeoutMs = 20000 }
        }
    }
    return $null
}

function Get-AiConfigHubMcpPropertyNames($Object) {
    if ($null -eq $Object) { return @() }
    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Get-AiConfigHubRuntimeRelativePath {
    param([string]$RuntimeRoot, [string]$Path)
    $root = [IO.Path]::GetFullPath($RuntimeRoot).TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
    $fullPath = [IO.Path]::GetFullPath($Path)
    $prefix = $root + [IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Runtime hash path is outside its root: $fullPath"
    }
    return $fullPath.Substring($prefix.Length).Replace('\', '/')
}

function Test-AiConfigHubIgnoredRuntimeHashPath {
    param([string]$RelativePath)
    $normalized = $RelativePath.Replace('\', '/')
    $segments = @($normalized.Split('/') | Where-Object { $_ -ne '' })
    if ($segments.Count -eq 0) { return $true }

    $ignoredDirectories = @('.cache', '.npm', '.nyc_output', '.turbo', '.vite', 'coverage')
    if ($segments[0] -in @('log', 'logs', 'temp', 'tmp')) { return $true }
    if (@($segments | Where-Object { $_ -in $ignoredDirectories }).Count -gt 0) { return $true }

    $name = $segments[-1]
    return $name -eq '.DS_Store' -or
        $name -match '(?i)^(npm-debug|yarn-debug|yarn-error|pnpm-debug)\.log(?:\..*)?$' -or
        $name -match '(?i)\.(?:log|tmp)$'
}

function ConvertFrom-AiConfigHubJsonDictionary {
    param([string]$Json)
    $convertFromJson = Get-Command ConvertFrom-Json -ErrorAction Stop
    if ($convertFromJson.Parameters.ContainsKey('AsHashtable')) {
        return ConvertFrom-Json -InputObject $Json -AsHashtable
    }

    Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $serializer.MaxJsonLength = [int]::MaxValue
    $serializer.RecursionLimit = 1024
    return $serializer.DeserializeObject($Json)
}

function Get-AiConfigHubLockedPackageMap {
    param([string]$RuntimeRoot)
    $result = @{}
    $lockPath = Join-Path $RuntimeRoot 'package-lock.json'
    if (-not (Test-Path -LiteralPath $lockPath -PathType Leaf)) { return $result }

    try { $lock = ConvertFrom-AiConfigHubJsonDictionary (Get-Content -Raw -Encoding UTF8 -LiteralPath $lockPath) }
    catch { throw "Invalid runtime package-lock.json at $lockPath`: $($_.Exception.Message)" }
    if ($null -eq $lock -or -not $lock.ContainsKey('packages')) { return $result }

    foreach ($property in $lock['packages'].GetEnumerator()) {
        $relativePath = ([string]$property.Key).Replace('\', '/').TrimEnd('/')
        if (-not $relativePath.StartsWith('node_modules/', [StringComparison]::Ordinal)) { continue }
        $metadata = $property.Value
        $isDevelopmentOnly = $null -ne $metadata -and
            $metadata.ContainsKey('dev') -and
            [bool]$metadata['dev']
        $result[$relativePath] = -not $isDevelopmentOnly
    }
    return $result
}

function Add-AiConfigHubRuntimeHashFile {
    param($Files, [string]$RuntimeRoot, [string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $relativePath = Get-AiConfigHubRuntimeRelativePath $RuntimeRoot $Path
    if (Test-AiConfigHubIgnoredRuntimeHashPath $relativePath) { return }
    $Files[$relativePath] = [IO.Path]::GetFullPath($Path)
}

function Get-AiConfigHubRuntimeHashFiles {
    param([string]$RuntimeRoot, $Runtime)
    $files = @{}
    $entryRelativePath = ([string]$Runtime.EntryRelativePath).Replace('\', '/').TrimStart('/')
    $entryPath = Join-Path $RuntimeRoot ([string]$Runtime.EntryRelativePath)
    if (-not (Test-Path -LiteralPath $entryPath -PathType Leaf)) {
        return [pscustomobject]@{ Files = $null; Reason = "runtime entry is missing: $entryPath" }
    }

    foreach ($fileName in @('package.json', 'package-lock.json')) {
        Add-AiConfigHubRuntimeHashFile $files $RuntimeRoot (Join-Path $RuntimeRoot $fileName)
    }

    $entrySegments = @($entryRelativePath.Split('/') | Where-Object { $_ -ne '' })
    if ($entrySegments.Count -gt 1) {
        $payloadRoot = Join-Path $RuntimeRoot $entrySegments[0]
        if (Test-Path -LiteralPath $payloadRoot -PathType Container) {
            Get-ChildItem -LiteralPath $payloadRoot -Recurse -Force -File | ForEach-Object {
                Add-AiConfigHubRuntimeHashFile $files $RuntimeRoot $_.FullName
            }
        }
    }
    else {
        Get-ChildItem -LiteralPath $RuntimeRoot -Force -File | Where-Object {
            $_.Extension -in @('.cjs', '.js', '.json', '.mjs', '.node', '.wasm')
        } | ForEach-Object {
            Add-AiConfigHubRuntimeHashFile $files $RuntimeRoot $_.FullName
        }
    }
    Add-AiConfigHubRuntimeHashFile $files $RuntimeRoot $entryPath

    $packageMap = Get-AiConfigHubLockedPackageMap $RuntimeRoot
    $nodeModulesRoot = Join-Path $RuntimeRoot 'node_modules'
    if ($packageMap.Count -gt 0 -and (Test-Path -LiteralPath $nodeModulesRoot -PathType Container)) {
        Get-ChildItem -LiteralPath $nodeModulesRoot -Recurse -Force -File | ForEach-Object {
            $relativePath = Get-AiConfigHubRuntimeRelativePath $RuntimeRoot $_.FullName
            if ($relativePath.StartsWith('node_modules/.bin/', [StringComparison]::OrdinalIgnoreCase)) { return }
            if (Test-AiConfigHubIgnoredRuntimeHashPath $relativePath) { return }

            $candidate = $relativePath.Substring(0, $relativePath.LastIndexOf('/'))
            while ($candidate.StartsWith('node_modules/', [StringComparison]::OrdinalIgnoreCase)) {
                if ($packageMap.ContainsKey($candidate)) {
                    if ([bool]$packageMap[$candidate]) { $files[$relativePath] = $_.FullName }
                    break
                }
                $separator = $candidate.LastIndexOf('/')
                if ($separator -lt 0) { break }
                $candidate = $candidate.Substring(0, $separator)
            }
        }
    }

    return [pscustomobject]@{ Files = $files; Reason = '' }
}

function Get-AiConfigHubRuntimeHash {
    param([string]$RuntimeRoot, $Runtime)
    if ([string]::IsNullOrWhiteSpace($RuntimeRoot) -or $null -eq $Runtime) {
        return [pscustomobject]@{ Hash = $null; Reason = 'runtime is not managed by ai-config-hub' }
    }
    if (-not (Test-Path -LiteralPath $RuntimeRoot -PathType Container)) {
        return [pscustomobject]@{ Hash = $null; Reason = "runtime root is missing: $RuntimeRoot" }
    }

    try { $hashFiles = Get-AiConfigHubRuntimeHashFiles $RuntimeRoot $Runtime }
    catch { return [pscustomobject]@{ Hash = $null; Reason = $_.Exception.Message } }
    if ($null -eq $hashFiles.Files) { return [pscustomobject]@{ Hash = $null; Reason = [string]$hashFiles.Reason } }

    [string[]]$relativePaths = @($hashFiles.Files.Keys)
    [Array]::Sort($relativePaths, [StringComparer]::Ordinal)
    $parts = New-Object System.Collections.Generic.List[string]
    $fileSha = [Security.Cryptography.SHA256]::Create()
    try {
        foreach ($relativePath in $relativePaths) {
            $path = [string]$hashFiles.Files[$relativePath]
            $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
            try { $fileHash = [BitConverter]::ToString($fileSha.ComputeHash($stream)).Replace('-', '') }
            finally { $stream.Dispose() }
            $parts.Add("$relativePath`t$fileHash") | Out-Null
        }
    }
    finally {
        $fileSha.Dispose()
    }
    if ($parts.Count -eq 0) { return [pscustomobject]@{ Hash = $null; Reason = 'no comparable runtime files were found' } }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [pscustomobject]@{ Hash = ([BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')); Reason = '' } }
    finally { $sha.Dispose() }
}

function Split-AiConfigHubPackageSpec {
    param([string]$Spec)
    if ([string]::IsNullOrWhiteSpace($Spec)) { return $null }
    $separator = $Spec.LastIndexOf('@')
    if ($separator -le 0) { return $null }
    return [pscustomobject]@{ Name = $Spec.Substring(0, $separator); Version = $Spec.Substring($separator + 1) }
}

function Get-AiConfigHubPackageVersion {
    param([string]$RuntimeRoot, [string]$PackageName)
    $packageJson = if ([string]::IsNullOrWhiteSpace($PackageName)) {
        Join-Path $RuntimeRoot 'package.json'
    }
    else {
        Join-Path (Join-Path $RuntimeRoot 'node_modules') ($PackageName.Replace('/', '\') + '\package.json')
    }
    if (-not (Test-Path -LiteralPath $packageJson -PathType Leaf)) { return $null }
    try { return [string](Get-Content -Raw -Encoding UTF8 -LiteralPath $packageJson | ConvertFrom-Json).version }
    catch { return $null }
}

function Get-AiConfigHubRuntimePackageName {
    param([string]$RuntimeRoot)
    $packageJson = Join-Path $RuntimeRoot 'package.json'
    if (-not (Test-Path -LiteralPath $packageJson -PathType Leaf)) { return $null }
    try { return [string](Get-Content -Raw -Encoding UTF8 -LiteralPath $packageJson | ConvertFrom-Json).name }
    catch { return $null }
}

function Get-AiConfigHubResolvedServerCommand {
    param($Server, [string]$RuntimeEntry, [string]$Root)
    $arguments = @($Server.args | ForEach-Object { [string]$_ })
    if (-not [string]::IsNullOrWhiteSpace([string]$Server.runtime_entry)) { $arguments += @($RuntimeEntry) }
    if (-not [string]::IsNullOrWhiteSpace([string]$Server.repo_script)) { $arguments += @(Join-Path $Root ([string]$Server.repo_script)) }
    if ($null -ne $Server.script_args) { $arguments += @($Server.script_args | ForEach-Object { [string]$_ }) }
    $command = [string]$Server.command
    $resolvedCommand = Get-Command $command -ErrorAction SilentlyContinue
    if ($resolvedCommand) { $command = $resolvedCommand.Source }
    return [pscustomobject]@{ Command = $command; Args = @($arguments) }
}

function Invoke-AiConfigHubMcpToolsProbe {
    param([string]$Root, [string]$Command, [object[]]$Arguments)
    $probePath = Join-Path $Root 'scripts\lib\mcp-smoke.mjs'
    $json = ConvertTo-Json -InputObject ([object[]]@($Arguments)) -Compress
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $output = (& node $probePath $Command $encoded 20000 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { return [pscustomobject]@{ Ready = $false; Reason = $output; ToolCount = $null; Tools = @() } }
    try {
        $payload = $output | ConvertFrom-Json
        return [pscustomobject]@{ Ready = [bool]$payload.ok; Reason = $(if ($payload.ok) { 'MCP initialize and tools/list passed' } else { [string]$payload.error }); ToolCount = [int]$payload.toolCount; Tools = @($payload.tools) }
    }
    catch { return [pscustomobject]@{ Ready = $false; Reason = "Invalid MCP smoke output: $output"; ToolCount = $null; Tools = @() } }
}

function Invoke-AiConfigHubMcpEntryProbe {
    param($Definition, [string]$EntryPath)
    $mode = [string]$Definition.Doctor.Mode
    if ([string]::IsNullOrWhiteSpace($mode)) { return [pscustomobject]@{ Ready = $true; Reason = 'legacy server has no managed entry probe' } }
    $arguments = @($Definition.Doctor.Args | ForEach-Object { [string]$_ })
    $output = if ($mode -eq 'node-check') { (& node --check $EntryPath 2>&1 | Out-String).Trim() } else { (& node $EntryPath @arguments 2>&1 | Out-String).Trim() }
    if ($LASTEXITCODE -ne 0) { return [pscustomobject]@{ Ready = $false; Reason = "entry probe failed with exit code $LASTEXITCODE`: $output" } }
    return [pscustomobject]@{ Ready = $true; Reason = 'entry probe passed' }
}

function Get-AiConfigHubMcpReadiness {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$UserHome,
        [Parameter(Mandatory = $true)]$Profile,
        [ValidateSet('Source', 'Readiness', 'Smoke')][string]$Mode = 'Readiness'
    )

    $items = New-Object System.Collections.Generic.List[object]
    $definitionStates = @{}
    $sourceRuntimeHashCache = @{}
    $installedRuntimeHashCache = @{}
    foreach ($definition in Get-AiConfigHubMcpServerDefinitionsForProfile $Manifest $Profile) {
        $definitionName = [string]$definition.Name
        $sourcePath = Join-Path $Root ([string]$definition.Source)
        $source = Get-Content -Raw -Encoding UTF8 -LiteralPath $sourcePath | ConvertFrom-Json
        $runtime = if ([string]::IsNullOrWhiteSpace([string]$definition.RequiresRuntime)) { $null } else { Get-AiConfigHubRuntimeDefinition $Manifest ([string]$definition.RequiresRuntime) }
        $sourceRuntimeRoot = if ($null -eq $runtime) { '' } else { Join-Path $Root ([string]$runtime.SourceRoot) }
        $installedRuntimeRoot = if ($null -eq $runtime) { '' } else { Join-Path $UserHome ([string]$runtime.UserRelativeRoot) }
        if ($null -eq $runtime) {
            $sourceHashInfo = [pscustomobject]@{ Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash; Reason = 'source JSON only' }
            $installedHashInfo = [pscustomobject]@{ Hash = $null; Reason = 'legacy command-backed server has no comparable install' }
        }
        else {
            $runtimeKey = [string]$runtime.Name
            if (-not $sourceRuntimeHashCache.ContainsKey($runtimeKey)) {
                $sourceRuntimeHashCache[$runtimeKey] = Get-AiConfigHubRuntimeHash $sourceRuntimeRoot $runtime
            }
            $sourceHashInfo = $sourceRuntimeHashCache[$runtimeKey]
            if ($Mode -eq 'Source') {
                $installedHashInfo = [pscustomobject]@{ Hash = $null; Reason = 'installed runtime is not evaluated in Source mode' }
            }
            else {
                if (-not $installedRuntimeHashCache.ContainsKey($runtimeKey)) {
                    $installedRuntimeHashCache[$runtimeKey] = Get-AiConfigHubRuntimeHash $installedRuntimeRoot $runtime
                }
                $installedHashInfo = $installedRuntimeHashCache[$runtimeKey]
            }
        }
        $drift = $null
        $driftReason = if ($null -eq $installedHashInfo.Hash) { [string]$installedHashInfo.Reason } elseif ($null -eq $sourceHashInfo.Hash) { [string]$sourceHashInfo.Reason } else { $drift = $sourceHashInfo.Hash -ne $installedHashInfo.Hash; $(if ($drift) { 'source and installed comparable files differ' } else { 'source and installed comparable files match' }) }
        $definitionReady = $true

        foreach ($serverName in Get-AiConfigHubMcpPropertyNames $source.servers) {
            $server = $source.servers.$serverName
            $package = Split-AiConfigHubPackageSpec ([string]$server.package)
            $sourceVersion = if ($null -eq $runtime) { if ($null -eq $package) { $null } else { $package.Version } } else { Get-AiConfigHubPackageVersion $sourceRuntimeRoot $(if ($null -eq $package) { '' } else { $package.Name }) }
            $installedVersion = if ($null -eq $runtime) { $null } else { Get-AiConfigHubPackageVersion $installedRuntimeRoot $(if ($null -eq $package) { '' } else { $package.Name }) }
            $reportedPackage = if ($null -ne $package) { $package.Name } elseif ($null -ne $runtime) { Get-AiConfigHubRuntimePackageName $sourceRuntimeRoot } else { '' }
            $expectedVersion = if ($null -ne $package) { $package.Version } else { $sourceVersion }
            $activeRuntimeRoot = if ($Mode -eq 'Source') { $sourceRuntimeRoot } else { $installedRuntimeRoot }
            $runtimeEntry = if ($null -eq $runtime) { '' } else { Join-Path $activeRuntimeRoot ([string]$runtime.EntryRelativePath) }
            $resolved = Get-AiConfigHubResolvedServerCommand $server $runtimeEntry $Root
            $ready = if ($null -eq $runtime) { $null -ne (Get-Command ([string]$server.command) -ErrorAction SilentlyContinue) } else { Test-Path -LiteralPath $runtimeEntry -PathType Leaf }
            $reason = if ($ready) { if ($null -eq $runtime) { 'legacy command is available' } else { 'runtime entry exists' } } else { if ($null -eq $runtime) { "command is unavailable: $($server.command)" } else { "runtime entry is missing: $runtimeEntry" } }
            $expectedToolCount = if ($definition.Doctor.ContainsKey('ExpectedToolCount')) { [int]$definition.Doctor.ExpectedToolCount } else { $null }
            $actualToolCount = $null
            $tools = @()
            $toolCountReason = if ($Mode -eq 'Readiness') { 'not probed in Readiness mode' } else { '' }

            if ($ready -and $Mode -ne 'Readiness' -and $null -ne $runtime) {
                $entryProbe = Invoke-AiConfigHubMcpEntryProbe $definition $runtimeEntry
                if (-not $entryProbe.Ready) { $ready = $false; $reason = $entryProbe.Reason }
                if ($ready) {
                    $toolsProbe = Invoke-AiConfigHubMcpToolsProbe $Root $resolved.Command $resolved.Args
                    $ready = [bool]$toolsProbe.Ready
                    $reason = [string]$toolsProbe.Reason
                    $actualToolCount = $toolsProbe.ToolCount
                    $tools = @($toolsProbe.Tools)
                    if ($ready -and $null -ne $expectedToolCount -and $actualToolCount -ne $expectedToolCount) {
                        $ready = $false
                        $reason = "tool count mismatch: expected $expectedToolCount, found $actualToolCount"
                    }
                }
            }
            elseif ($Mode -ne 'Readiness' -and $null -eq $runtime) {
                $toolCountReason = 'legacy command-backed smoke is disabled to avoid implicit package download or network use'
            }

            if ($null -ne $package -and $Mode -ne 'Source' -and -not [string]::IsNullOrWhiteSpace($installedVersion) -and $installedVersion -ne $package.Version) {
                $ready = $false
                $reason = "installed package version mismatch: expected $($package.Version), found $installedVersion"
            }
            if ($null -ne $runtime -and $null -eq $sourceHashInfo.Hash) {
                $ready = $false
                $reason = "source runtime hash is unavailable: $($sourceHashInfo.Reason)"
            }
            elseif ($Mode -ne 'Source' -and $null -ne $runtime -and $null -eq $installedHashInfo.Hash) {
                $ready = $false
                $reason = "installed runtime hash is unavailable: $($installedHashInfo.Reason)"
            }
            elseif ($Mode -ne 'Source' -and $null -ne $runtime -and $drift -eq $true) {
                $ready = $false
                $reason = 'installed runtime hash differs from the repository source'
            }
            if ($Mode -ne 'Source' -and $null -ne $runtime -and
                -not [string]::IsNullOrWhiteSpace([string]$sourceVersion) -and
                -not [string]::IsNullOrWhiteSpace([string]$installedVersion) -and
                $sourceVersion -ne $installedVersion) {
                $ready = $false
                $reason = "installed runtime version mismatch: source $sourceVersion, installed $installedVersion"
            }
            if (-not $ready) { $definitionReady = $false }
            $items.Add([pscustomobject]@{
                Kind = 'managed'; Definition = $definitionName; Name = [string]$serverName; Ready = $ready; Optional = [bool]$definition.Optional
                Package = $reportedPackage; ExpectedVersion = $expectedVersion
                SourceVersion = $sourceVersion; InstalledVersion = $installedVersion; SourceHash = $sourceHashInfo.Hash; InstalledHash = $installedHashInfo.Hash
                Drift = $drift; DriftReason = $driftReason; Runtime = $(if ($null -eq $runtime) { 'command' } else { [string]$runtime.Name })
                SourcePath = $(if ($null -eq $runtime) { $sourcePath } else { Join-Path $sourceRuntimeRoot ([string]$runtime.EntryRelativePath) })
                InstalledPath = $(if ($null -eq $runtime) { '' } else { Join-Path $installedRuntimeRoot ([string]$runtime.EntryRelativePath) })
                ActivePath = $(if ($null -eq $runtime) { [string]$server.command } else { $runtimeEntry }); PreferredFor = @($definition.PreferredFor)
                ExpectedToolCount = $expectedToolCount; ActualToolCount = $actualToolCount; ToolCountReason = $toolCountReason; Tools = $tools; Reason = $reason
            }) | Out-Null
        }
        $definitionStates[$definitionName] = $definitionReady
    }

    foreach ($localServerName in @($Profile.LocalServers)) {
        $pencil = if ([string]$localServerName -eq 'pencil') { Resolve-AiConfigHubPencilMcpServer $UserHome } else { $null }
        $items.Add([pscustomobject]@{
            Kind = 'local'; Definition = [string]$localServerName; Name = [string]$localServerName; Ready = ($null -ne $pencil); Optional = $true
            Package = ''; ExpectedVersion = ''; SourceVersion = $null; InstalledVersion = $null; SourceHash = $null; InstalledHash = $null
            Drift = $null; DriftReason = 'local plugin is outside managed runtime comparison'; Runtime = 'local-plugin'; SourcePath = ''
            InstalledPath = $(if ($null -eq $pencil) { '' } else { [string]$pencil.Command }); ActivePath = $(if ($null -eq $pencil) { '' } else { [string]$pencil.Command })
            PreferredFor = @('visual-design'); ExpectedToolCount = $null; ActualToolCount = $null; ToolCountReason = 'local plugin tool count is not probed'
            Tools = @(); Reason = $(if ($null -eq $pencil) { 'Pencil MCP server was not found locally' } else { "discovered from $($pencil.Source)" })
        }) | Out-Null
    }

    $routeMap = @{}
    foreach ($definition in Get-AiConfigHubMcpServerDefinitionsForProfile $Manifest $Profile) {
        foreach ($route in @($definition.PreferredFor)) {
            if (-not $routeMap.ContainsKey([string]$route)) { $routeMap[[string]$route] = New-Object System.Collections.Generic.List[string] }
            $routeMap[[string]$route].Add([string]$definition.Name) | Out-Null
        }
    }
    $routingConflicts = @(
        foreach ($route in $routeMap.Keys | Sort-Object) {
            $servers = @($routeMap[$route] | Select-Object -Unique)
            if ($servers.Count -gt 1) { [pscustomobject]@{ PreferredFor = $route; Servers = $servers; Reason = 'multiple active managed servers claim the same preferred route' } }
        }
    )
    $itemArray = @($items | ForEach-Object { $_ })
    $requiredFailures = @($itemArray | Where-Object { -not $_.Ready -and -not $_.Optional })
    $optionalFailures = @($itemArray | Where-Object { -not $_.Ready -and $_.Optional })
    return [pscustomobject]@{
        Profile = [string]$Profile.Name; Mode = $Mode; NetworkAllowed = $false; Items = $itemArray
        ReadyServers = @($itemArray | Where-Object { $_.Kind -eq 'managed' -and $_.Ready } | ForEach-Object { $_.Name })
        ReadyDefinitions = @($definitionStates.Keys | Where-Object { $definitionStates[$_] })
        RequiredFailures = $requiredFailures; OptionalFailures = $optionalFailures; RoutingConflicts = $routingConflicts
        Ready = ($requiredFailures.Count -eq 0 -and $optionalFailures.Count -eq 0); DegradedReady = ($requiredFailures.Count -eq 0)
    }
}
