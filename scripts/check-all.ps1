$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot

& (Join-Path $Root 'scripts\render.ps1')
& (Join-Path $Root 'scripts\check.ps1')
& (Join-Path $Root 'scripts\render-skills.ps1')
& (Join-Path $Root 'scripts\check-skills.ps1')
& (Join-Path $Root 'scripts\sync-context-thread-runtime.ps1')
& (Join-Path $Root 'scripts\render-mcp.ps1')
& (Join-Path $Root 'scripts\check-mcp.ps1')
& (Join-Path $Root 'scripts\sync.ps1')
& (Join-Path $Root 'scripts\sync-skills.ps1')
& (Join-Path $Root 'scripts\sync-mcp.ps1')

Write-Output 'All render, check, and dry-run steps passed'
