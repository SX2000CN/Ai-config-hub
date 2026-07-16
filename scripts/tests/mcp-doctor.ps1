$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
function Assert-True($Value, $Message) { if (-not $Value) { throw $Message } }
function Assert-Equal($Expected, $Actual, $Message) { if ($Expected -ne $Actual) { throw "$Message. Expected '$Expected', got '$Actual'." } }
function Copy-TestItem($TargetRoot, $RelativePath) {
    $source = Join-Path $Root $RelativePath
    $target = Join-Path $TargetRoot $RelativePath
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
}
. (Join-Path $Root 'scripts\mcp-local.ps1')

$sourceCore = (& (Join-Path $Root 'scripts\mcp-doctor.ps1') -Profile core -Mode Source -Json | Out-String) | ConvertFrom-Json
Assert-Equal 'core' $sourceCore.Profile 'Doctor JSON omitted the selected profile'
Assert-Equal 'Source' $sourceCore.Mode 'Doctor JSON omitted the selected mode'
Assert-Equal 1 $sourceCore.Items[0].ExpectedToolCount 'local-webfetch expected tool count changed'
Assert-Equal 1 $sourceCore.Items[0].ActualToolCount 'local-webfetch source smoke tool count changed'
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$sourceCore.Items[0].SourceHash)) 'Doctor source hash is missing'

$sourceFull = (& (Join-Path $Root 'scripts\mcp-doctor.ps1') -Profile full -Mode Source -AllowDegraded -Json | Out-String) | ConvertFrom-Json
$conflict = @($sourceFull.RoutingConflicts | Where-Object PreferredFor -eq 'browser-inspection')
Assert-Equal 1 $conflict.Count 'Doctor did not report the full-profile browser routing conflict'
foreach ($expectation in @{'context-thread'=9; 'playwright'=24; 'chrome-devtools'=29}.GetEnumerator()) {
    $item = $sourceFull.Items | Where-Object Name -eq $expectation.Key | Select-Object -First 1
    Assert-Equal $expectation.Value $item.ActualToolCount "Doctor source smoke tool count changed for $($expectation.Key)"
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('ai-config-hub-doctor-' + [Guid]::NewGuid().ToString('N'))
$savedAllowedRoot = $env:AI_CONFIG_HUB_TEST_ALLOWED_HOME_ROOT
$savedPreflightLog = $env:AI_CONFIG_HUB_TEST_PREFLIGHT_LOG
try {
    $syntheticRuntimeRoot = Join-Path $tempRoot 'synthetic-runtime'
    New-Item -ItemType Directory -Force -Path (Join-Path $syntheticRuntimeRoot 'dist\bin') | Out-Null
    Set-Content -Encoding UTF8 -LiteralPath (Join-Path $syntheticRuntimeRoot 'package.json') -Value '{"name":"synthetic-runtime","version":"1.0.0"}'
    Set-Content -Encoding UTF8 -LiteralPath (Join-Path $syntheticRuntimeRoot 'package-lock.json') -Value '{"lockfileVersion":3,"packages":{"":{"name":"synthetic-runtime","version":"1.0.0"}}}'
    Set-Content -Encoding UTF8 -LiteralPath (Join-Path $syntheticRuntimeRoot 'dist\bin\entry.js') -Value 'import "../runtime.js";'
    $syntheticPayload = Join-Path $syntheticRuntimeRoot 'dist\runtime.js'
    Set-Content -Encoding UTF8 -LiteralPath $syntheticPayload -Value 'export const value = 1;'
    $syntheticRuntime = [pscustomobject]@{ Name = 'synthetic'; EntryRelativePath = 'dist\bin\entry.js' }
    $syntheticBaseline = Get-AiConfigHubRuntimeHash $syntheticRuntimeRoot $syntheticRuntime
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$syntheticBaseline.Hash)) 'Synthetic runtime baseline hash is missing'
    New-Item -ItemType Directory -Force -Path (Join-Path $syntheticRuntimeRoot '.cache') | Out-Null
    Set-Content -Encoding UTF8 -LiteralPath (Join-Path $syntheticRuntimeRoot '.cache\doctor.log') -Value 'ignored diagnostic output'
    $syntheticWithCache = Get-AiConfigHubRuntimeHash $syntheticRuntimeRoot $syntheticRuntime
    Assert-Equal $syntheticBaseline.Hash $syntheticWithCache.Hash 'Runtime cache or log output changed the managed hash'
    Add-Content -Encoding UTF8 -LiteralPath $syntheticPayload -Value 'export const changed = true;'
    $syntheticChanged = Get-AiConfigHubRuntimeHash $syntheticRuntimeRoot $syntheticRuntime
    Assert-True ($syntheticChanged.Hash -ne $syntheticBaseline.Hash) 'Runtime payload outside the entry file was not covered by the managed hash'

    $userHome = Join-Path $tempRoot 'home'
    New-Item -ItemType Directory -Force -Path $userHome | Out-Null
    $missingFailed = $false
    try { & (Join-Path $Root 'scripts\mcp-doctor.ps1') -Profile core -Mode Readiness -UserHome $userHome | Out-Null }
    catch { $missingFailed = $true; Assert-True $_.Exception.Message.Contains('is not ready') 'Missing runtime doctor failed for the wrong reason' }
    Assert-True $missingFailed 'Doctor Readiness must fail when a required runtime is missing'

    $localTarget = Join-Path $userHome '.ai-config-hub\mcp\local-webfetch'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $localTarget) | Out-Null
    Copy-Item -LiteralPath (Join-Path $Root 'tools\local-webfetch') -Destination $localTarget -Recurse -Force
    $installedCore = (& (Join-Path $Root 'scripts\mcp-doctor.ps1') -Profile core -Mode Smoke -UserHome $userHome -Json | Out-String) | ConvertFrom-Json
    Assert-True $installedCore.Ready 'Doctor Smoke did not accept a matching installed core runtime'
    Assert-Equal $false $installedCore.Items[0].Drift 'Matching local-webfetch runtime reported drift'
    Assert-Equal 1 $installedCore.Items[0].ActualToolCount 'Installed local-webfetch smoke tool count changed'

    $degradedBrowser = (& (Join-Path $Root 'scripts\mcp-doctor.ps1') -Profile browser -Mode Readiness -UserHome $userHome -AllowDegraded -Json | Out-String) | ConvertFrom-Json
    Assert-True $degradedBrowser.DegradedReady 'Optional browser runtime should be degradable when core is ready'
    Assert-Equal 1 @($degradedBrowser.OptionalFailures).Count 'Missing browser runtime was not reported as one optional failure'

    $testRepo = Join-Path $tempRoot 'repository'
    foreach ($relativePath in @(
        'config\managed-assets.psd1', 'tools\browser-mcp-runtime', 'scripts\sync-browser-mcp-runtime.ps1',
        'scripts\lib\managed-assets.ps1', 'scripts\lib\deploy.ps1'
    )) { Copy-TestItem $testRepo $relativePath }
    $fixtureTarget = Join-Path $testRepo 'scripts\check-all.ps1'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $fixtureTarget) | Out-Null
    Copy-Item -LiteralPath (Join-Path $Root 'scripts\tests\fixtures\check-all-pass.ps1') -Destination $fixtureTarget -Force
    $env:AI_CONFIG_HUB_TEST_ALLOWED_HOME_ROOT = $tempRoot
    $env:AI_CONFIG_HUB_TEST_PREFLIGHT_LOG = Join-Path $tempRoot 'preflight.log'
    & (Join-Path $testRepo 'scripts\sync-browser-mcp-runtime.ps1') -Apply -UserHome $userHome | Out-Null

    $browserSmoke = (& (Join-Path $Root 'scripts\mcp-doctor.ps1') -Profile browser -Mode Smoke -UserHome $userHome -Json | Out-String) | ConvertFrom-Json
    Assert-True $browserSmoke.Ready 'Doctor Smoke did not accept the installed browser profile'
    $playwright = $browserSmoke.Items | Where-Object Name -eq 'playwright' | Select-Object -First 1
    Assert-Equal '0.0.78' $playwright.InstalledVersion 'Installed Playwright MCP version changed'
    Assert-Equal 24 $playwright.ActualToolCount 'Installed Playwright MCP tool count changed'
    Assert-Equal $false $playwright.Drift 'Matching browser runtime reported drift'

    $installedBrowserRoot = Join-Path $userHome '.ai-config-hub\mcp\browser'
    $cachePath = Join-Path $installedBrowserRoot 'node_modules\@playwright\mcp\.cache\doctor.log'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $cachePath) | Out-Null
    Set-Content -Encoding UTF8 -LiteralPath $cachePath -Value 'ignored diagnostic output'
    $browserWithCache = (& (Join-Path $Root 'scripts\mcp-doctor.ps1') -Profile browser -Mode Readiness -UserHome $userHome -Json | Out-String) | ConvertFrom-Json
    $cachedPlaywright = $browserWithCache.Items | Where-Object Name -eq 'playwright' | Select-Object -First 1
    Assert-True $browserWithCache.Ready 'Ignored package cache/log output made the browser profile unready'
    Assert-Equal $false $cachedPlaywright.Drift 'Ignored package cache/log output reported runtime drift'

    $playwrightPayload = Join-Path $installedBrowserRoot 'node_modules\@playwright\mcp\cli.js'
    $playwrightPayloadBytes = [IO.File]::ReadAllBytes($playwrightPayload)
    try {
        Add-Content -Encoding UTF8 -LiteralPath $playwrightPayload -Value "`n// test-only managed package drift"
        $modifiedBrowser = (& (Join-Path $Root 'scripts\mcp-doctor.ps1') -Profile browser -Mode Readiness -UserHome $userHome -AllowDegraded -Json | Out-String) | ConvertFrom-Json
        $modifiedPlaywright = $modifiedBrowser.Items | Where-Object Name -eq 'playwright' | Select-Object -First 1
        Assert-True $modifiedBrowser.DegradedReady 'Optional browser package drift incorrectly blocked degraded readiness'
        Assert-Equal $true $modifiedPlaywright.Drift 'Modified locked Playwright package content did not report drift'
        Assert-Equal $false $modifiedPlaywright.Ready 'Modified locked Playwright package content remained ready'
    }
    finally { [IO.File]::WriteAllBytes($playwrightPayload, $playwrightPayloadBytes) }

    $chromePayload = Join-Path $installedBrowserRoot 'node_modules\chrome-devtools-mcp\build\src\bin\chrome-devtools-mcp.js'
    $chromePayloadBytes = [IO.File]::ReadAllBytes($chromePayload)
    try {
        Remove-Item -LiteralPath $chromePayload -Force
        $missingBrowser = (& (Join-Path $Root 'scripts\mcp-doctor.ps1') -Profile browser-debug -Mode Readiness -UserHome $userHome -AllowDegraded -Json | Out-String) | ConvertFrom-Json
        $missingChrome = $missingBrowser.Items | Where-Object Name -eq 'chrome-devtools' | Select-Object -First 1
        Assert-True $missingBrowser.DegradedReady 'Optional browser package loss incorrectly blocked degraded readiness'
        Assert-Equal $true $missingChrome.Drift 'Missing locked Chrome DevTools package content did not report drift'
        Assert-Equal $false $missingChrome.Ready 'Missing locked Chrome DevTools package content remained ready'
    }
    finally { [IO.File]::WriteAllBytes($chromePayload, $chromePayloadBytes) }
}
finally {
    $env:AI_CONFIG_HUB_TEST_ALLOWED_HOME_ROOT = $savedAllowedRoot
    $env:AI_CONFIG_HUB_TEST_PREFLIGHT_LOG = $savedPreflightLog
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

$global:LASTEXITCODE = 0
Write-Output 'MCP doctor tests passed'
