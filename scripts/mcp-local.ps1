$ErrorActionPreference = 'Stop'

function Add-AiConfigHubPencilCandidate {
    param(
        [System.Collections.Generic.List[object]]$Candidates,
        [string]$Path,
        [string]$App,
        [string]$Source
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($App)) {
        return
    }

    $Candidates.Add([pscustomobject]@{
        Path = $Path
        App = $App
        Source = $Source
    }) | Out-Null
}

function Get-AiConfigHubPencilMcpCandidates {
    $candidates = New-Object System.Collections.Generic.List[object]
    $userHome = [Environment]::GetFolderPath('UserProfile')

    if (-not [string]::IsNullOrWhiteSpace($env:AI_CONFIG_HUB_PENCIL_MCP_COMMAND)) {
        $app = if ([string]::IsNullOrWhiteSpace($env:AI_CONFIG_HUB_PENCIL_MCP_APP)) { 'desktop' } else { $env:AI_CONFIG_HUB_PENCIL_MCP_APP }
        Add-AiConfigHubPencilCandidate $candidates $env:AI_CONFIG_HUB_PENCIL_MCP_COMMAND $app 'AI_CONFIG_HUB_PENCIL_MCP_COMMAND'
    }

    $desktopRelative = 'Pencil\resources\app.asar.unpacked\out\mcp-server-windows-x64.exe'
    foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA 'Programs'))) {
        if (-not [string]::IsNullOrWhiteSpace($root)) {
            Add-AiConfigHubPencilCandidate $candidates (Join-Path $root $desktopRelative) 'desktop' 'Pencil Desktop'
        }
    }

    $pencilMcpRoot = Join-Path $userHome '.pencil\mcp'
    foreach ($app in @('desktop', 'visual_studio_code', 'cursor', 'windsurf')) {
        Add-AiConfigHubPencilCandidate $candidates (Join-Path $pencilMcpRoot "$app\out\mcp-server-windows-x64.exe") $app "Pencil $app MCP cache"
    }

    if (Test-Path -LiteralPath $pencilMcpRoot) {
        Get-ChildItem -LiteralPath $pencilMcpRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Add-AiConfigHubPencilCandidate $candidates (Join-Path $_.FullName 'out\mcp-server-windows-x64.exe') $_.Name "Pencil $($_.Name) MCP cache"
        }
    }

    $seen = New-Object System.Collections.Generic.HashSet[string]
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($candidate in $candidates) {
        $key = "$($candidate.Path)|$($candidate.App)"
        if ($seen.Add($key)) {
            $result.Add($candidate) | Out-Null
        }
    }

    foreach ($item in $result) {
        $item
    }
}

function Resolve-AiConfigHubPencilMcpServer {
    foreach ($candidate in Get-AiConfigHubPencilMcpCandidates) {
        if (Test-Path -LiteralPath $candidate.Path) {
            return [pscustomobject]@{
                Command = (Resolve-Path -LiteralPath $candidate.Path).Path
                App = $candidate.App
                Source = $candidate.Source
                StartupTimeoutMs = 20000
            }
        }
    }

    return $null
}
