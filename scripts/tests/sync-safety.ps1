$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$FixtureRoot = Join-Path $PSScriptRoot 'fixtures'
. (Join-Path $Root 'scripts\lib\deploy.ps1')

function Assert-Equal($Expected, $Actual, $Message) {
    if ($Expected -ne $Actual) {
        throw "$Message. Expected '$Expected', got '$Actual'."
    }
}

function Assert-True($Value, $Message) {
    if (-not $Value) {
        throw $Message
    }
}

function Assert-Contains($Text, $Expected, $Message) {
    if (-not ([string]$Text).Contains($Expected)) {
        throw "$Message. Expected to find '$Expected' in '$Text'."
    }
}

function Write-Utf8NoBom($Path, $Content) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Copy-TestItem($TestRoot, $RelativePath) {
    $source = Join-Path $Root $RelativePath
    $target = Join-Path $TestRoot $RelativePath
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
}

function Get-TestContextRuntimeScript {
    return @'
const readline = require('readline');
if (process.argv.includes('--help')) { console.log('mock context-thread'); process.exit(0); }
const tools = Array.from({ length: 9 }, (_, index) => ({ name: `tool_${index}`, description: '', inputSchema: { type: 'object' } }));
const lines = readline.createInterface({ input: process.stdin });
lines.on('line', (line) => {
  const message = JSON.parse(line);
  if (message.id === 1) process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id: 1, result: { protocolVersion: '2024-11-05', capabilities: { tools: {} }, serverInfo: { name: 'mock', version: '1' } } }) + '\n');
  if (message.id === 2) process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id: 2, result: { tools } }) + '\n');
});
'@
}

function New-TestRepository($Path) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    foreach ($relativePath in @(
        'config\managed-assets.psd1',
        'rules\rendered\CLAUDE.md',
        'rules\rendered\AGENTS.md',
        'rules\rendered\grok-AGENTS.md',
        'rules\rendered\opencode-AGENTS.md',
        'skills\rendered',
        'tool-configs\mcp\rendered',
        'tool-configs\mcp\shared',
        'tools\local-webfetch',
        'scripts\lib\deploy.ps1',
        'scripts\lib\managed-assets.ps1',
        'scripts\lib\mcp-smoke.mjs',
        'scripts\mcp-local.ps1',
        'scripts\sync.ps1',
        'scripts\sync-skills.ps1',
        'scripts\sync-mcp.ps1',
        'scripts\sync-opencode-mcp.ps1'
    )) {
        Copy-TestItem $Path $relativePath
    }
    Copy-Item -LiteralPath (Join-Path $FixtureRoot 'check-all-pass.ps1') -Destination (Join-Path $Path 'scripts\check-all.ps1') -Force
    $contextRuntimeRoot = Join-Path $Path 'tools\context-thread-engine'
    Write-Utf8NoBom (Join-Path $contextRuntimeRoot 'package.json') '{"name":"@ai-config-hub/context-thread","version":"0.9.6"}'
    Write-Utf8NoBom (Join-Path $contextRuntimeRoot 'package-lock.json') '{"lockfileVersion":3,"packages":{"":{"name":"@ai-config-hub/context-thread","version":"0.9.6"}}}'
    Write-Utf8NoBom (Join-Path $contextRuntimeRoot 'dist\bin\context-thread.js') (Get-TestContextRuntimeScript)
    return $Path
}

function Initialize-TestRuntimeEntries($UserHome) {
    $target = Join-Path $UserHome '.ai-config-hub\mcp\local-webfetch'
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Copy-Item -LiteralPath (Join-Path $Root 'tools\local-webfetch') -Destination $target -Recurse -Force
}

function Initialize-TestContextRuntime($UserHome, $RepositoryRoot) {
    $target = Join-Path $UserHome '.ai-config-hub\mcp\context-thread'
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'tools\context-thread-engine') -Destination $target -Recurse -Force
}

function Get-InitialClaudeConfig {
    return @'
{
  "theme": "preserve-me",
  "mcpServers": {
    "custom": {
      "command": "custom-command",
      "args": []
    },
    "pencil": {
      "type": "stdio",
      "command": "C:\\Program Files\\Pencil\\resources\\app.asar.unpacked\\out\\mcp-server-windows-x64.exe",
      "args": ["--app", "desktop", "--agent", "claudeCode"]
    },
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@playwright/mcp@0.0.78"]
    }
  }
}
'@
}

function Get-InitialCodexConfig {
    return @'
model = "preserve-me"

[mcp_servers.custom]
command = "custom-command"
args = []

[mcp_servers.pencil]
command = "C:\\Program Files\\Pencil\\resources\\app.asar.unpacked\\out\\mcp-server-windows-x64.exe"
args = ["--app", "desktop", "--agent", "codexCLI"]

[mcp_servers.pencil.env]
LEGACY = "remove-me"

[mcp_servers.playwright]
command = "cmd"
args = ["/c", "npx", "-y", "@playwright/mcp@0.0.78"]
startup_timeout_ms = 20000

[mcp_servers.playwright.env]
SystemRoot = "C:\\Windows"
PROGRAMFILES = "C:\\Program Files"
'@
}

function Get-InitialGrokConfig {
    return @'
[models]
default = "preserve-me"

[mcp_servers.custom]
command = "custom-command"
args = []

[mcp_servers.pencil]
command = "C:\\Program Files\\Pencil\\resources\\app.asar.unpacked\\out\\mcp-server-windows-x64.exe"
args = ["--app", "desktop", "--agent", "grok"]

[mcp_servers.playwright]
command = "npx"
args = ["-y", "@playwright/mcp@0.0.78", "--headless"]
enabled = true
startup_timeout_sec = 20
'@
}

function Get-InitialOpenCodeConfig {
    return @'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "preserve-me",
  "mcp": {
    "custom": {
      "type": "local",
      "command": ["custom-command"],
      "enabled": true,
      "timeout": 30000
    },
    "pencil": {
      "type": "local",
      "command": ["C:\\Program Files\\Pencil\\resources\\app.asar.unpacked\\out\\mcp-server-windows-x64.exe", "--app", "desktop"],
      "enabled": true,
      "timeout": 30000
    },
    "playwright": {
      "type": "local",
      "command": ["npx", "-y", "@playwright/mcp@0.0.78"],
      "enabled": true,
      "timeout": 30000
    }
  }
}
'@
}

function Assert-RulesApplied($TestRoot, $UserHome) {
    $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $TestRoot 'config\managed-assets.psd1')
    foreach ($definition in $manifest.Rules.Targets) {
        $source = Join-Path $TestRoot ([string]$definition.Rendered)
        $target = Join-Path $UserHome ([string]$definition.UserRelativePath)
        Assert-Equal (Get-AiConfigHubPathFingerprint $source) (Get-AiConfigHubPathFingerprint $target) "Rule Apply failed for $($definition.Name)"
    }
}

function Assert-SkillsApplied($TestRoot, $UserHome) {
    $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $TestRoot 'config\managed-assets.psd1')
    foreach ($definition in @($manifest.Skills.Targets | Where-Object { $_.Name -ne 'CodexLegacy' })) {
        foreach ($skillName in $manifest.Skills.Names) {
            $source = Join-Path (Join-Path $TestRoot ([string]$definition.RenderedRoot)) ([string]$skillName)
            $target = Join-Path (Join-Path $UserHome ([string]$definition.UserRelativeRoot)) ([string]$skillName)
            Assert-Equal (Get-AiConfigHubPathFingerprint $source) (Get-AiConfigHubPathFingerprint $target) "Skill Apply failed for $($definition.Name)-$skillName"
        }
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ai-config-hub-sync-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$savedEnvironment = @{
    AllowedHomeRoot = $env:AI_CONFIG_HUB_TEST_ALLOWED_HOME_ROOT
    PreflightLog = $env:AI_CONFIG_HUB_TEST_PREFLIGHT_LOG
    ConcurrentTarget = $env:AI_CONFIG_HUB_TEST_CONCURRENT_TARGET
    PreflightMutationTarget = $env:AI_CONFIG_HUB_TEST_PREFLIGHT_MUTATION_TARGET
    PreflightMutationSource = $env:AI_CONFIG_HUB_TEST_PREFLIGHT_MUTATION_SOURCE
}

try {
    $env:AI_CONFIG_HUB_TEST_ALLOWED_HOME_ROOT = $tempRoot
    $env:AI_CONFIG_HUB_TEST_PREFLIGHT_LOG = Join-Path $tempRoot 'preflight.log'

    $context1 = New-AiConfigHubOperationContext $tempRoot 'test'
    $context2 = New-AiConfigHubOperationContext $tempRoot 'test'
    Assert-True ($context1.BackupRoot -ne $context2.BackupRoot) 'Backup roots must be unique'

    $targetFile = Join-Path $tempRoot 'config\settings.txt'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetFile) | Out-Null
    Set-Content -LiteralPath $targetFile -Value 'before' -NoNewline
    $stagedFile = New-AiConfigHubStagedFile $context1 'settings.txt' 'after'
    Install-AiConfigHubStagedFile $context1 'settings' $stagedFile $targetFile | Out-Null
    Assert-Equal 'after' (Get-Content -Raw -LiteralPath $targetFile) 'Atomic file replacement failed'
    Restore-AiConfigHubOperation $context1
    Assert-Equal 'before' (Get-Content -Raw -LiteralPath $targetFile) 'File rollback failed'

    $context3 = New-AiConfigHubOperationContext $tempRoot 'test-directory'
    $sourceDir = Join-Path $tempRoot 'source-dir'
    $targetDir = Join-Path $tempRoot 'skills\demo'
    New-Item -ItemType Directory -Force -Path $sourceDir | Out-Null
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Set-Content -LiteralPath (Join-Path $sourceDir 'value.txt') -Value 'new' -NoNewline
    Set-Content -LiteralPath (Join-Path $targetDir 'value.txt') -Value 'old' -NoNewline
    $stagedDir = Copy-AiConfigHubStagedDirectory $context3 'demo' $sourceDir
    Install-AiConfigHubStagedDirectory $context3 'demo' $stagedDir $targetDir | Out-Null
    Assert-Equal 'new' (Get-Content -Raw -LiteralPath (Join-Path $targetDir 'value.txt')) 'Directory swap failed'
    Restore-AiConfigHubOperation $context3
    Assert-Equal 'old' (Get-Content -Raw -LiteralPath (Join-Path $targetDir 'value.txt')) 'Directory rollback failed'

    $missingFileTarget = Join-Path $tempRoot 'first-install-race\shared.txt'
    $missingFileFingerprint = Get-AiConfigHubPathFingerprint $missingFileTarget
    Assert-Equal '<missing>' $missingFileFingerprint 'File race target must start missing'
    $fileRaceContextA = New-AiConfigHubOperationContext $tempRoot 'file-race-a'
    $fileRaceContextB = New-AiConfigHubOperationContext $tempRoot 'file-race-b'
    $fileRaceStagedA = New-AiConfigHubStagedFile $fileRaceContextA 'candidate-a.txt' 'installed by A'
    $fileRaceStagedB = New-AiConfigHubStagedFile $fileRaceContextB 'candidate-b.txt' 'installed by B'
    Install-AiConfigHubStagedFile $fileRaceContextA 'shared-file-a' $fileRaceStagedA $missingFileTarget -ExpectedFingerprint $missingFileFingerprint | Out-Null
    $fileRaceRejected = $false
    try {
        Install-AiConfigHubStagedFile $fileRaceContextB 'shared-file-b' $fileRaceStagedB $missingFileTarget -ExpectedFingerprint $missingFileFingerprint | Out-Null
    }
    catch {
        $fileRaceRejected = $true
        Assert-Contains $_.Exception.Message 'changed after planning' 'Second missing-file installer failed for the wrong reason'
    }
    Assert-True $fileRaceRejected 'Second missing-file installer must reject the target created by the first installer'
    Assert-Equal 'installed by A' (Get-Content -Raw -LiteralPath $missingFileTarget) 'Second missing-file installer overwrote the first result'
    Assert-True (Test-Path -LiteralPath $fileRaceStagedB -PathType Leaf) 'Rejected missing-file candidate must remain in its own staging directory'
    Complete-AiConfigHubOperation $fileRaceContextA | Out-Null
    Remove-AiConfigHubOperationStaging $fileRaceContextB

    $missingDirectoryTarget = Join-Path $tempRoot 'first-install-race\shared-directory'
    $missingDirectoryFingerprint = Get-AiConfigHubPathFingerprint $missingDirectoryTarget
    Assert-Equal '<missing>' $missingDirectoryFingerprint 'Directory race target must start missing'
    $directoryRaceSourceA = Join-Path $tempRoot 'first-install-race\source-a'
    $directoryRaceSourceB = Join-Path $tempRoot 'first-install-race\source-b'
    New-Item -ItemType Directory -Force -Path $directoryRaceSourceA | Out-Null
    New-Item -ItemType Directory -Force -Path $directoryRaceSourceB | Out-Null
    Write-Utf8NoBom (Join-Path $directoryRaceSourceA 'winner.txt') 'installed by A'
    Write-Utf8NoBom (Join-Path $directoryRaceSourceB 'winner.txt') 'installed by B'
    $directoryRaceContextA = New-AiConfigHubOperationContext $tempRoot 'directory-race-a'
    $directoryRaceContextB = New-AiConfigHubOperationContext $tempRoot 'directory-race-b'
    $directoryRaceStagedA = Copy-AiConfigHubStagedDirectory $directoryRaceContextA 'candidate-a' $directoryRaceSourceA
    $directoryRaceStagedB = Copy-AiConfigHubStagedDirectory $directoryRaceContextB 'candidate-b' $directoryRaceSourceB
    Install-AiConfigHubStagedDirectory $directoryRaceContextA 'shared-directory-a' $directoryRaceStagedA $missingDirectoryTarget -ExpectedFingerprint $missingDirectoryFingerprint | Out-Null
    $directoryRaceRejected = $false
    try {
        Install-AiConfigHubStagedDirectory $directoryRaceContextB 'shared-directory-b' $directoryRaceStagedB $missingDirectoryTarget -ExpectedFingerprint $missingDirectoryFingerprint | Out-Null
    }
    catch {
        $directoryRaceRejected = $true
        Assert-Contains $_.Exception.Message 'changed after planning' 'Second missing-directory installer failed for the wrong reason'
    }
    Assert-True $directoryRaceRejected 'Second missing-directory installer must reject the target created by the first installer'
    Assert-Equal 'installed by A' (Get-Content -Raw -LiteralPath (Join-Path $missingDirectoryTarget 'winner.txt')) 'Second missing-directory installer overwrote the first result'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $missingDirectoryTarget 'candidate-b'))) 'Rejected missing-directory candidate was nested into the installed target'
    Assert-True (Test-Path -LiteralPath $directoryRaceStagedB -PathType Container) 'Rejected missing-directory candidate must remain in its own staging directory'
    Complete-AiConfigHubOperation $directoryRaceContextA | Out-Null
    Remove-AiConfigHubOperationStaging $directoryRaceContextB

    $unmanaged = Join-Path $tempRoot 'unmanaged'
    New-Item -ItemType Directory -Force -Path $unmanaged | Out-Null
    Set-Content -LiteralPath (Join-Path $unmanaged 'SKILL.md') -Value "---`nname: other`n---" -NoNewline
    Assert-True (-not (Test-AiConfigHubManagedSkillTarget $unmanaged 'demo')) 'Unmanaged skill target must be rejected'
    Set-Content -LiteralPath (Join-Path $unmanaged 'SKILL.md') -Value "---`nname: demo`n---" -NoNewline
    Assert-True (-not (Test-AiConfigHubManagedSkillTarget $unmanaged 'demo')) 'Same-name skill without managed marker must be rejected'

    Assert-Equal (Resolve-AiConfigHubUserHome) (Resolve-AiConfigHubUserHome '~') 'Tilde UserHome expansion failed'
    $relativeRejected = $false
    try { Resolve-AiConfigHubUserHome '.\relative-home' | Out-Null } catch { $relativeRejected = $true }
    Assert-True $relativeRejected 'Relative UserHome must be rejected'

    $escaped = $false
    try {
        Assert-AiConfigHubPathInside (Join-Path (Split-Path -Parent $tempRoot) 'outside.txt') $tempRoot 'Test' | Out-Null
    }
    catch {
        $escaped = $true
    }
    Assert-True $escaped 'Path boundary check must reject targets outside UserHome'

    $manifestFixtureRoot = Join-Path $tempRoot 'manifest-fixtures'
    New-Item -ItemType Directory -Force -Path $manifestFixtureRoot | Out-Null
    $invalidManifests = @(
        [pscustomobject]@{
            Name = 'absolute-staging.psd1'
            Content = "@{ SchemaVersion = 1; UserPaths = @{ StagingRoot = 'C:\\outside'; BackupRoot = '.ai-config-hub\\backups' } }"
            Error = 'must be relative'
        },
        [pscustomobject]@{
            Name = 'parent-traversal.psd1'
            Content = "@{ SchemaVersion = 1; UserPaths = @{ StagingRoot = '..\\staging'; BackupRoot = '.ai-config-hub\\backups' } }"
            Error = "must not contain '..'"
        },
        [pscustomobject]@{
            Name = 'overlapping-roots.psd1'
            Content = "@{ SchemaVersion = 1; UserPaths = @{ StagingRoot = '.ai-config-hub'; BackupRoot = '.ai-config-hub\\backups' } }"
            Error = 'must be distinct and non-overlapping'
        }
    )
    foreach ($invalidManifest in $invalidManifests) {
        $manifestPath = Join-Path $manifestFixtureRoot $invalidManifest.Name
        Write-Utf8NoBom $manifestPath $invalidManifest.Content
        $manifestRejected = $false
        try {
            Import-AiConfigHubManagedAssetsManifest $manifestPath | Out-Null
        }
        catch {
            $manifestRejected = $true
            Assert-Contains $_.Exception.Message $invalidManifest.Error "Manifest $($invalidManifest.Name) failed for the wrong reason"
        }
        Assert-True $manifestRejected "Manifest $($invalidManifest.Name) must be rejected"
    }

    $typeContext = New-AiConfigHubOperationContext $tempRoot 'type-conflicts'
    $directoryAtFileTarget = Join-Path $tempRoot 'type-conflicts\file-target'
    New-Item -ItemType Directory -Force -Path $directoryAtFileTarget | Out-Null
    Write-Utf8NoBom (Join-Path $directoryAtFileTarget 'keep.txt') 'keep directory'
    $typeStagedFile = New-AiConfigHubStagedFile $typeContext 'replacement.txt' 'replacement'
    $fileTypeRejected = $false
    try {
        Install-AiConfigHubStagedFile $typeContext 'file-conflict' $typeStagedFile $directoryAtFileTarget -ExpectedFingerprint (Get-AiConfigHubPathFingerprint $directoryAtFileTarget) | Out-Null
    }
    catch {
        $fileTypeRejected = $true
        Assert-Contains $_.Exception.Message 'is not a file' 'File target type conflict failed for the wrong reason'
    }
    Assert-True $fileTypeRejected 'File installation must reject an existing directory target'
    Assert-Equal 'keep directory' (Get-Content -Raw -LiteralPath (Join-Path $directoryAtFileTarget 'keep.txt')) 'File type conflict changed the target directory'

    $fileAtDirectoryTarget = Join-Path $tempRoot 'type-conflicts\directory-target'
    Write-Utf8NoBom $fileAtDirectoryTarget 'keep file'
    $typeSourceDirectory = Join-Path $tempRoot 'type-conflicts\source-directory'
    New-Item -ItemType Directory -Force -Path $typeSourceDirectory | Out-Null
    Write-Utf8NoBom (Join-Path $typeSourceDirectory 'replacement.txt') 'replacement'
    $typeStagedDirectory = Copy-AiConfigHubStagedDirectory $typeContext 'replacement-directory' $typeSourceDirectory
    $directoryTypeRejected = $false
    try {
        Install-AiConfigHubStagedDirectory $typeContext 'directory-conflict' $typeStagedDirectory $fileAtDirectoryTarget -ExpectedFingerprint (Get-AiConfigHubPathFingerprint $fileAtDirectoryTarget) | Out-Null
    }
    catch {
        $directoryTypeRejected = $true
        Assert-Contains $_.Exception.Message 'is not a directory' 'Directory target type conflict failed for the wrong reason'
    }
    Assert-True $directoryTypeRejected 'Directory installation must reject an existing file target'
    Assert-Equal 'keep file' (Get-Content -Raw -LiteralPath $fileAtDirectoryTarget) 'Directory type conflict changed the target file'
    Remove-AiConfigHubOperationStaging $typeContext

    $context4 = New-AiConfigHubOperationContext $tempRoot 'rollback-errors'
    $firstTarget = Join-Path $tempRoot 'rollback\first.txt'
    $secondTarget = Join-Path $tempRoot 'rollback\second.txt'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $firstTarget) | Out-Null
    Set-Content -LiteralPath $firstTarget -Value 'first-old' -NoNewline
    Set-Content -LiteralPath $secondTarget -Value 'second-old' -NoNewline
    $firstStaged = New-AiConfigHubStagedFile $context4 'first.txt' 'first-new'
    $secondStaged = New-AiConfigHubStagedFile $context4 'second.txt' 'second-new'
    Install-AiConfigHubStagedFile $context4 'first' $firstStaged $firstTarget | Out-Null
    $secondRecord = Install-AiConfigHubStagedFile $context4 'second' $secondStaged $secondTarget
    Remove-Item -LiteralPath $secondRecord.Backup -Force
    $rollbackFailed = $false
    try { Restore-AiConfigHubOperation $context4 } catch { $rollbackFailed = $true }
    Assert-True $rollbackFailed 'Missing backup must report an incomplete rollback'
    Assert-Equal 'first-old' (Get-Content -Raw -LiteralPath $firstTarget) 'Rollback must continue after another target fails'
    Assert-Equal 'second-new' (Get-Content -Raw -LiteralPath $secondTarget) 'Target with missing backup must not be deleted'

    $testRepository = New-TestRepository (Join-Path $tempRoot 'repository')
    $unmanagedApplyHome = Join-Path $tempRoot 'unmanaged-apply-home'
    New-Item -ItemType Directory -Force -Path $unmanagedApplyHome | Out-Null
    $unmanagedSkillTarget = Join-Path $unmanagedApplyHome '.claude\skills\project-ai-config-hub\SKILL.md'
    $unmanagedSkillContent = "---`nname: project-ai-config-hub`n---`n`n# User-owned skill`n"
    Write-Utf8NoBom $unmanagedSkillTarget $unmanagedSkillContent

    $unmanagedApplyRejected = $false
    try {
        & (Join-Path $testRepository 'scripts\sync-skills.ps1') -Apply -UserHome $unmanagedApplyHome | Out-Null
    }
    catch {
        $unmanagedApplyRejected = $true
        Assert-Contains $_.Exception.Message 'Refusing to overwrite unmanaged existing skill target' 'Unmanaged skill Apply failed for the wrong reason'
    }
    Assert-True $unmanagedApplyRejected 'Skill Apply must reject a same-name target without the managed marker'
    Assert-Equal $unmanagedSkillContent (Get-Content -Raw -Encoding UTF8 -LiteralPath $unmanagedSkillTarget) 'Rejected unmanaged skill content was changed'

    $testManifest = Import-AiConfigHubManagedAssetsManifest (Join-Path $testRepository 'config\managed-assets.psd1')
    foreach ($definition in @($testManifest.Skills.Targets | Where-Object { $_.Name -ne 'CodexLegacy' })) {
        foreach ($skillName in $testManifest.Skills.Names) {
            $candidate = Join-Path (Join-Path $unmanagedApplyHome ([string]$definition.UserRelativeRoot)) ([string]$skillName)
            if ([System.IO.Path]::GetFullPath($candidate) -eq [System.IO.Path]::GetFullPath((Split-Path -Parent $unmanagedSkillTarget))) {
                continue
            }
            Assert-True (-not (Test-Path -LiteralPath $candidate)) "Rejected unmanaged skill Apply wrote another target: $candidate"
        }
    }

    $applyHome = Join-Path $tempRoot 'apply-home'
    New-Item -ItemType Directory -Force -Path $applyHome | Out-Null

    foreach ($relativePath in @('.claude\CLAUDE.md', '.codex\AGENTS.md', '.grok\AGENTS.md', '.config\opencode\AGENTS.md')) {
        Write-Utf8NoBom (Join-Path $applyHome $relativePath) 'old rule content'
    }
    & (Join-Path $testRepository 'scripts\sync.ps1') -Apply -UserHome $applyHome | Out-Null
    Assert-RulesApplied $testRepository $applyHome

    $retiredManagedOpenCodeSkill = Join-Path $applyHome '.config\opencode\skills\project-ai-config-hub\SKILL.md'
    Write-Utf8NoBom $retiredManagedOpenCodeSkill "---`nname: project-ai-config-hub`n---`n`n<!-- ai-config-hub-managed: project-ai-config-hub -->`n"
    $retiredUnmanagedOpenCodeSkill = Join-Path $applyHome '.config\opencode\skills\global-context-thread\SKILL.md'
    $retiredUnmanagedContent = "---`nname: global-context-thread`n---`n`n# User-owned OpenCode skill`n"
    Write-Utf8NoBom $retiredUnmanagedOpenCodeSkill $retiredUnmanagedContent
    & (Join-Path $testRepository 'scripts\sync-skills.ps1') -Apply -UserHome $applyHome | Out-Null
    Assert-SkillsApplied $testRepository $applyHome
    Assert-True (-not (Test-Path -LiteralPath (Split-Path -Parent $retiredManagedOpenCodeSkill))) 'Managed retired OpenCode skill target was not removed'
    Assert-Equal $retiredUnmanagedContent (Get-Content -Raw -Encoding UTF8 -LiteralPath $retiredUnmanagedOpenCodeSkill) 'Unmanaged retired OpenCode skill target was changed'

    Initialize-TestRuntimeEntries $applyHome
    $claudeTarget = Join-Path $applyHome '.claude.json'
    $codexTarget = Join-Path $applyHome '.codex\config.toml'
    $grokTarget = Join-Path $applyHome '.grok\config.toml'
    $openCodeTarget = Join-Path $applyHome '.config\opencode\opencode.json'
    Write-Utf8NoBom $claudeTarget (Get-InitialClaudeConfig)
    Write-Utf8NoBom $codexTarget (Get-InitialCodexConfig)
    Write-Utf8NoBom $grokTarget (Get-InitialGrokConfig)
    Write-Utf8NoBom $openCodeTarget (Get-InitialOpenCodeConfig)

    & (Join-Path $testRepository 'scripts\sync-mcp.ps1') -Apply -Profile core -UserHome $applyHome | Out-Null
    & (Join-Path $testRepository 'scripts\sync-opencode-mcp.ps1') -Apply -Profile core -UserHome $applyHome | Out-Null

    $claudeConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $claudeTarget | ConvertFrom-Json
    Assert-equal 'preserve-me' $claudeConfig.theme 'Claude non-MCP configuration was not preserved'
    Assert-equal 'custom-command' $claudeConfig.mcpServers.custom.command 'Claude custom MCP server was not preserved'
    Assert-True ($null -eq $claudeConfig.mcpServers.pencil) 'Claude retired pencil MCP server was not removed'
    Assert-True ($null -ne $claudeConfig.mcpServers.'local-webfetch') 'Claude local-webfetch server is missing from core profile'
    foreach ($managedServer in @('chrome-devtools', 'playwright', 'context-thread')) {
        Assert-True ($null -eq $claudeConfig.mcpServers.$managedServer) "Claude core profile unexpectedly contains: $managedServer"
    }

    $codexConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $codexTarget
    Assert-Contains $codexConfig 'model = "preserve-me"' 'Codex non-MCP configuration was not preserved'
    Assert-Contains $codexConfig '[mcp_servers.custom]' 'Codex custom MCP server was not preserved'
    Assert-True ($codexConfig -notmatch '(?m)^\[mcp_servers\.pencil\]') 'Codex retired pencil MCP section was not removed'
    Assert-True ($codexConfig -notmatch '(?m)^\[mcp_servers\.pencil\.env\]$') 'Codex pencil env section was not removed'
    Assert-True ($codexConfig -notmatch '(?m)^\[mcp_servers\.playwright\]$') 'Codex retired Playwright MCP section was not removed'

    $grokConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $grokTarget
    Assert-Contains $grokConfig 'default = "preserve-me"' 'Grok non-MCP configuration was not preserved'
    Assert-Contains $grokConfig '[mcp_servers.custom]' 'Grok custom MCP server was not preserved'
    Assert-True ($grokConfig -notmatch '(?m)^\[mcp_servers\.pencil\]') 'Grok retired pencil MCP section was not removed'
    Assert-True ($grokConfig -notmatch '(?m)^\[mcp_servers\.playwright\]') 'Grok retired Playwright MCP section was not removed'
    Assert-Contains $grokConfig '# >>> ai-config-hub managed compat' 'Grok managed compat block is missing'
    Assert-Contains $grokConfig 'mcps = false' 'Grok managed compat must disable Claude MCP scan'
    Assert-True ($grokConfig -notmatch '(?m)^# >>> ai-config-hub managed mcp: local-webfetch$') 'Grok core profile retained local-webfetch'
    $grokBytes = [System.IO.File]::ReadAllBytes($grokTarget)
    Assert-True (-not ($grokBytes.Length -ge 3 -and $grokBytes[0] -eq 0xEF -and $grokBytes[1] -eq 0xBB -and $grokBytes[2] -eq 0xBF)) 'Grok config.toml must be written without UTF-8 BOM'

    $openCodeConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $openCodeTarget | ConvertFrom-Json
    Assert-equal 'preserve-me' $openCodeConfig.model 'OpenCode non-MCP configuration was not preserved'
    Assert-True ($null -ne $openCodeConfig.mcp.custom) 'OpenCode custom MCP server was not preserved'
    Assert-True ($null -eq $openCodeConfig.mcp.pencil) 'OpenCode retired pencil MCP server was not removed'
    Assert-True ($null -eq $openCodeConfig.mcp.'local-webfetch') 'OpenCode retired local-webfetch server was not removed'
    Assert-True ($null -eq $openCodeConfig.mcp.'playwright') 'OpenCode retired Playwright MCP server was not removed'
    Assert-True ($null -eq $openCodeConfig.mcp.'context-thread') 'OpenCode core profile unexpectedly contains context-thread'

    & (Join-Path $testRepository 'scripts\sync-opencode-mcp.ps1') -Apply -Profile code-intel -UserHome $applyHome | Out-Null
    $openCodeCodeIntel = Get-Content -Raw -Encoding UTF8 -LiteralPath $openCodeTarget | ConvertFrom-Json
    Assert-True ($null -eq $openCodeCodeIntel.mcp.'local-webfetch') 'OpenCode code-intel profile retained retired local-webfetch'
    Assert-True ($null -ne $openCodeCodeIntel.mcp.'context-thread') 'OpenCode code-intel profile missing context-thread'
    Assert-equal 'preserve-me' $openCodeCodeIntel.model 'OpenCode profile switch changed non-MCP configuration'

    $openCodeCodeIntel.mcp.'context-thread'.enabled = $false
    Write-Utf8NoBom $openCodeTarget (($openCodeCodeIntel | ConvertTo-Json -Depth 32) + "`n")
    $openCodeConflict = ''
    try {
        & (Join-Path $testRepository 'scripts\sync-opencode-mcp.ps1') -Apply -Profile code-intel -UserHome $applyHome | Out-Null
    }
    catch {
        $openCodeConflict = $_.Exception.Message
    }
    Assert-Contains $openCodeConflict 'ownership conflicts' 'OpenCode Apply must reject a user-modified managed server'
    $openCodeAfterConflict = Get-Content -Raw -Encoding UTF8 -LiteralPath $openCodeTarget | ConvertFrom-Json
    Assert-True (-not $openCodeAfterConflict.mcp.'context-thread'.enabled) 'OpenCode ownership conflict changed the user configuration'

    $legacyHeaderHome = Join-Path $tempRoot 'legacy-header-home'
    New-Item -ItemType Directory -Force -Path $legacyHeaderHome | Out-Null
    Initialize-TestRuntimeEntries $legacyHeaderHome
    $legacyHeaderTarget = Join-Path $legacyHeaderHome '.codex\config.toml'
    Write-Utf8NoBom $legacyHeaderTarget @'
model = "preserve-legacy-header-test"

  [mcp_servers.chrome-devtools]   # legacy
command = "legacy-command"
args = ["legacy-argument"]

[mcp_servers.custom]
command = "custom-command"
args = []
'@

    & (Join-Path $testRepository 'scripts\sync-mcp.ps1') -Apply -Codex -UserHome $legacyHeaderHome | Out-Null
    $legacyHeaderConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $legacyHeaderTarget
    $chromeHeaderPattern = '(?m)^[ \t]*\[[ \t]*mcp_servers[ \t]*\.[ \t]*chrome-devtools[ \t]*\][ \t]*(?:#[^\r\n]*)?\r?$'
    Assert-Equal 1 ([regex]::Matches($legacyHeaderConfig, $chromeHeaderPattern).Count) 'Core profile did not preserve the custom same-name chrome-devtools table'
    Assert-Contains $legacyHeaderConfig '# legacy' 'Codex sync removed a custom commented chrome-devtools header'
    Assert-True ($legacyHeaderConfig -match 'legacy-command|legacy-argument') 'Codex sync removed a custom same-name chrome-devtools section body'
    Assert-Contains $legacyHeaderConfig '[mcp_servers.custom]' 'Codex sync did not preserve an unrelated table beside the legacy header'

    $claudeInactiveCustomHome = Join-Path $tempRoot 'claude-inactive-custom-home'
    New-Item -ItemType Directory -Force -Path $claudeInactiveCustomHome | Out-Null
    Initialize-TestRuntimeEntries $claudeInactiveCustomHome
    $claudeInactiveCustomTarget = Join-Path $claudeInactiveCustomHome '.claude.json'
    Write-Utf8NoBom $claudeInactiveCustomTarget @'
{
  "theme": "preserve-inactive-custom",
  "mcpServers": {
    "playwright": { "command": "custom-playwright", "args": ["--user-owned"] }
  }
}
'@
    & (Join-Path $testRepository 'scripts\sync-mcp.ps1') -Apply -ClaudeCode -Profile core -UserHome $claudeInactiveCustomHome | Out-Null
    $claudeInactiveCustom = Get-Content -Raw -Encoding UTF8 -LiteralPath $claudeInactiveCustomTarget | ConvertFrom-Json
    Assert-Equal 'preserve-inactive-custom' $claudeInactiveCustom.theme 'Claude core switch changed unrelated configuration'
    Assert-Equal 'custom-playwright' $claudeInactiveCustom.mcpServers.playwright.command 'Claude core switch removed an inactive custom same-name server'
    Assert-Equal '--user-owned' $claudeInactiveCustom.mcpServers.playwright.args[0] 'Claude core switch changed an inactive custom same-name server'
    Assert-True ($null -ne $claudeInactiveCustom.mcpServers.'local-webfetch') 'Claude core switch did not install its active managed server'

    $ownedSwitchHome = Join-Path $tempRoot 'owned-switch-home'
    New-Item -ItemType Directory -Force -Path $ownedSwitchHome | Out-Null
    Initialize-TestRuntimeEntries $ownedSwitchHome
    $ownedClaudeTarget = Join-Path $ownedSwitchHome '.claude.json'
    $ownedCodexTarget = Join-Path $ownedSwitchHome '.codex\config.toml'
    Write-Utf8NoBom $ownedClaudeTarget @'
{
  "theme": "preserve-owned-switch",
  "mcpServers": {
    "playwright": { "command": "npx", "args": ["-y", "@playwright/mcp@0.0.78"] }
  }
}
'@
    Write-Utf8NoBom $ownedCodexTarget @'
model = "preserve-owned-switch"

[mcp_servers.playwright]
command = "cmd"
args = ["/c", "npx", "-y", "@playwright/mcp@0.0.78"]
startup_timeout_ms = 20000

[mcp_servers.playwright.env]
SystemRoot = "C:\\Windows"
PROGRAMFILES = "C:\\Program Files"
'@
    & (Join-Path $testRepository 'scripts\sync-mcp.ps1') -Apply -Profile core -UserHome $ownedSwitchHome | Out-Null
    $ownedClaude = Get-Content -Raw -Encoding UTF8 -LiteralPath $ownedClaudeTarget | ConvertFrom-Json
    Assert-Equal 'preserve-owned-switch' $ownedClaude.theme 'Claude profile switch changed unrelated configuration'
    Assert-True ($null -eq $ownedClaude.mcpServers.playwright) 'Claude profile switch did not remove an owned inactive legacy server'
    Assert-True ($null -ne $ownedClaude.mcpServers.'local-webfetch') 'Claude core profile did not install local-webfetch after owned migration'
    $ownedCodex = Get-Content -Raw -Encoding UTF8 -LiteralPath $ownedCodexTarget
    Assert-Contains $ownedCodex 'model = "preserve-owned-switch"' 'Codex profile switch changed unrelated configuration'
    Assert-True ($ownedCodex -notmatch '(?m)^\[mcp_servers\.playwright\]$') 'Codex profile switch did not remove an owned inactive legacy server'

    $historicalOwnedHome = Join-Path $tempRoot 'historical-owned-switch-home'
    New-Item -ItemType Directory -Force -Path $historicalOwnedHome | Out-Null
    Initialize-TestRuntimeEntries $historicalOwnedHome
    $historicalClaudeTarget = Join-Path $historicalOwnedHome '.claude.json'
    $historicalCodexTarget = Join-Path $historicalOwnedHome '.codex\config.toml'
    $historicalLocalEntry = Join-Path $historicalOwnedHome '.ai-config-hub\mcp\local-webfetch\index.js'
    $historicalContextEntry = Join-Path $historicalOwnedHome '.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js'
    $historicalClaude = [ordered]@{
        theme = 'preserve-historical-switch'
        mcpServers = [ordered]@{
            'local-webfetch' = [ordered]@{ type = 'stdio'; command = 'cmd'; args = @('/c', 'node', $historicalLocalEntry) }
            'context-thread' = [ordered]@{ type = 'stdio'; command = 'cmd'; args = @('/c', 'node', $historicalContextEntry, 'serve', '--mcp') }
            playwright = [ordered]@{ command = 'cmd'; args = @('/c', 'npx', '-y', '@playwright/mcp@latest') }
            'chrome-devtools' = [ordered]@{ command = 'cmd'; args = @('/c', 'npx', '-y', 'chrome-devtools-mcp@latest') }
        }
    }
    Write-Utf8NoBom $historicalClaudeTarget ($historicalClaude | ConvertTo-Json -Depth 8)
    $historicalContextToml = $historicalContextEntry.Replace('\', '\\')
    Write-Utf8NoBom $historicalCodexTarget @"
model = "preserve-historical-switch"

[mcp_servers.chrome-devtools]
type = "stdio"
command = "npx"
args = [ "-y", "chrome-devtools-mcp@latest" ]

[mcp_servers.context-thread]
type = "stdio"
command = "node"
args = [ "$historicalContextToml", "serve", "--mcp" ]

[mcp_servers.playwright]
type = "stdio"
command = "npx"
args = [ "-y", "@playwright/mcp@latest" ]
"@
    & (Join-Path $testRepository 'scripts\sync-mcp.ps1') -Apply -Profile core -UserHome $historicalOwnedHome | Out-Null
    $migratedHistoricalClaude = Get-Content -Raw -Encoding UTF8 -LiteralPath $historicalClaudeTarget | ConvertFrom-Json
    Assert-Equal 'preserve-historical-switch' $migratedHistoricalClaude.theme 'Historical Claude migration changed unrelated configuration'
    Assert-Equal 'node' $migratedHistoricalClaude.mcpServers.'local-webfetch'.command 'Historical Claude local-webfetch was not migrated to the managed runtime command'
    Assert-Equal $historicalLocalEntry $migratedHistoricalClaude.mcpServers.'local-webfetch'.args[0] 'Historical Claude local-webfetch runtime path changed'
    foreach ($inactiveServer in @('context-thread', 'playwright', 'chrome-devtools')) {
        Assert-True ($null -eq $migratedHistoricalClaude.mcpServers.$inactiveServer) "Historical Claude core switch did not remove owned $inactiveServer"
    }
    $migratedHistoricalCodex = Get-Content -Raw -Encoding UTF8 -LiteralPath $historicalCodexTarget
    Assert-Contains $migratedHistoricalCodex 'model = "preserve-historical-switch"' 'Historical Codex migration changed unrelated configuration'
    foreach ($inactiveServer in @('context-thread', 'playwright', 'chrome-devtools')) {
        Assert-True ($migratedHistoricalCodex -notmatch "(?m)^\[mcp_servers\.$([regex]::Escape($inactiveServer))\]$") "Historical Codex core switch did not remove owned $inactiveServer"
    }

    $claudeConflictHome = Join-Path $tempRoot 'claude-conflict-home'
    New-Item -ItemType Directory -Force -Path $claudeConflictHome | Out-Null
    Initialize-TestRuntimeEntries $claudeConflictHome
    $claudeConflictTarget = Join-Path $claudeConflictHome '.claude.json'
    $claudeConflictContent = '{"mcpServers":{"local-webfetch":{"command":"custom-fetch","args":[]}}}'
    Write-Utf8NoBom $claudeConflictTarget $claudeConflictContent
    $claudeConflictRejected = $false
    try { & (Join-Path $testRepository 'scripts\sync-mcp.ps1') -Apply -ClaudeCode -Profile core -UserHome $claudeConflictHome | Out-Null }
    catch { $claudeConflictRejected = $true; Assert-Contains $_.Exception.Message 'ownership conflicts' 'Claude same-name conflict failed for the wrong reason' }
    Assert-True $claudeConflictRejected 'Claude active custom same-name server must block Apply'
    Assert-Equal $claudeConflictContent (Get-Content -Raw -Encoding UTF8 -LiteralPath $claudeConflictTarget) 'Claude active custom same-name server changed despite conflict'

    $requiredDriftHome = Join-Path $tempRoot 'required-drift-home'
    New-Item -ItemType Directory -Force -Path $requiredDriftHome | Out-Null
    Initialize-TestRuntimeEntries $requiredDriftHome
    Add-Content -Encoding UTF8 -LiteralPath (Join-Path $requiredDriftHome '.ai-config-hub\mcp\local-webfetch\index.js') -Value "`n// test-only required runtime drift"
    $requiredDriftTarget = Join-Path $requiredDriftHome '.claude.json'
    $requiredDriftRejected = $false
    try { & (Join-Path $testRepository 'scripts\sync-mcp.ps1') -Apply -ClaudeCode -Profile core -AllowDegraded -UserHome $requiredDriftHome | Out-Null }
    catch { $requiredDriftRejected = $true; Assert-Contains $_.Exception.Message 'unavailable required servers' 'Required runtime drift failed for the wrong reason' }
    Assert-True $requiredDriftRejected 'Required runtime hash drift must block Apply even with AllowDegraded'
    Assert-True (-not (Test-Path -LiteralPath $requiredDriftTarget)) 'Required runtime drift wrote Claude configuration before blocking Apply'

    $codexConflictHome = Join-Path $tempRoot 'codex-conflict-home'
    New-Item -ItemType Directory -Force -Path $codexConflictHome | Out-Null
    Initialize-TestRuntimeEntries $codexConflictHome
    Initialize-TestContextRuntime $codexConflictHome $testRepository
    $codexConflictTarget = Join-Path $codexConflictHome '.codex\config.toml'
    $codexConflictContent = @'
[mcp_servers.context-thread]
command = "custom-context"
args = []
'@
    Write-Utf8NoBom $codexConflictTarget $codexConflictContent
    $codexConflictRejected = $false
    try { & (Join-Path $testRepository 'scripts\sync-mcp.ps1') -Apply -Codex -Profile code-intel -UserHome $codexConflictHome | Out-Null }
    catch { $codexConflictRejected = $true; Assert-Contains $_.Exception.Message 'ownership conflicts' 'Codex same-name conflict failed for the wrong reason' }
    Assert-True $codexConflictRejected 'Codex active custom same-name server must block Apply'
    Assert-Equal $codexConflictContent (Get-Content -Raw -Encoding UTF8 -LiteralPath $codexConflictTarget) 'Codex active custom same-name server changed despite conflict'

    $preflightMergeHome = Join-Path $tempRoot 'preflight-merge-home'
    New-Item -ItemType Directory -Force -Path $preflightMergeHome | Out-Null
    Initialize-TestRuntimeEntries $preflightMergeHome
    $preflightMergeTarget = Join-Path $preflightMergeHome '.claude.json'
    $beforePreflightJson = @'
{
  "theme": "before-preflight",
  "mcpServers": {
    "custom": {
      "command": "custom-command",
      "args": []
    }
  }
}
'@
    $duringPreflightJson = $beforePreflightJson.Replace('before-preflight', 'changed-during-preflight')
    $preflightMutationSource = Join-Path $tempRoot 'preflight-mutation.json'
    Write-Utf8NoBom $preflightMergeTarget $beforePreflightJson
    Write-Utf8NoBom $preflightMutationSource $duringPreflightJson
    $env:AI_CONFIG_HUB_TEST_PREFLIGHT_MUTATION_TARGET = $preflightMergeTarget
    $env:AI_CONFIG_HUB_TEST_PREFLIGHT_MUTATION_SOURCE = $preflightMutationSource

    & (Join-Path $testRepository 'scripts\sync-mcp.ps1') -Apply -ClaudeCode -UserHome $preflightMergeHome | Out-Null
    $preflightMergedConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $preflightMergeTarget | ConvertFrom-Json
    Assert-equal 'changed-during-preflight' $preflightMergedConfig.theme 'MCP planning did not re-read a target changed during preflight'
    Assert-True ($null -ne $preflightMergedConfig.mcpServers.'local-webfetch') 'Preflight merge missing local-webfetch'
    Assert-True ($null -eq $preflightMergedConfig.mcpServers.pencil) 'Preflight merge should not introduce pencil'

    $raceRepository = New-TestRepository (Join-Path $tempRoot 'race-repository')
    $raceDeploy = Join-Path $raceRepository 'scripts\lib\deploy.ps1'
    Add-Content -Encoding UTF8 -LiteralPath $raceDeploy -Value @'

function Copy-AiConfigHubStagedFile {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Source
    )

    $path = Join-Path $Context.StagingRoot $Name
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $path -Force
    if (-not [string]::IsNullOrWhiteSpace($env:AI_CONFIG_HUB_TEST_CONCURRENT_TARGET)) {
        Set-Content -Encoding UTF8 -LiteralPath $env:AI_CONFIG_HUB_TEST_CONCURRENT_TARGET -Value 'concurrent update' -NoNewline
        Remove-Item Env:AI_CONFIG_HUB_TEST_CONCURRENT_TARGET
    }
    return $path
}
'@

    $raceHome = Join-Path $tempRoot 'race-home'
    New-Item -ItemType Directory -Force -Path $raceHome | Out-Null
    $raceClaudeTarget = Join-Path $raceHome '.claude\CLAUDE.md'
    $raceCodexTarget = Join-Path $raceHome '.codex\AGENTS.md'
    Write-Utf8NoBom $raceClaudeTarget 'planned version'
    Write-Utf8NoBom $raceCodexTarget 'planned version'
    $env:AI_CONFIG_HUB_TEST_CONCURRENT_TARGET = $raceClaudeTarget

    $raceRejected = $false
    try {
        & (Join-Path $raceRepository 'scripts\sync.ps1') -Apply -UserHome $raceHome | Out-Null
    }
    catch {
        $raceRejected = $true
        Assert-Contains $_.Exception.Message 'changed after planning' 'Concurrent target update failed for the wrong reason'
    }
    Assert-True $raceRejected 'A target changed after preflight must not be overwritten'
    Assert-Equal 'concurrent update' (Get-Content -Raw -Encoding UTF8 -LiteralPath $raceClaudeTarget) 'Concurrent target update was overwritten'
    Assert-Equal 'planned version' (Get-Content -Raw -Encoding UTF8 -LiteralPath $raceCodexTarget) 'A later rule target changed despite transaction rejection'

    $preflightHomes = @(Get-Content -LiteralPath $env:AI_CONFIG_HUB_TEST_PREFLIGHT_LOG | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Assert-True ($preflightHomes.Count -ge 6) 'Expected every Apply test to run its preflight'
    foreach ($preflightHome in $preflightHomes) {
        $resolvedPreflightHome = [System.IO.Path]::GetFullPath($preflightHome)
        Assert-True $resolvedPreflightHome.StartsWith(([System.IO.Path]::GetFullPath($tempRoot) + [System.IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase) 'An Apply preflight escaped the temporary test root'
    }

    foreach ($syncScript in @(
        'sync.ps1',
        'sync-skills.ps1',
        'sync-mcp.ps1',
        'sync-context-thread-runtime.ps1',
        'sync-local-webfetch-runtime.ps1',
        'sync-browser-mcp-runtime.ps1'
    )) {
        $content = Get-Content -Raw -LiteralPath (Join-Path $Root "scripts\$syncScript")
        Assert-True ($content -notmatch '(?m)^\s*exit\s+0\s*$') "$syncScript must return instead of terminating the parent preflight host"
    }

    Write-Output 'Sync safety tests passed'
}
finally {
    $env:AI_CONFIG_HUB_TEST_ALLOWED_HOME_ROOT = $savedEnvironment.AllowedHomeRoot
    $env:AI_CONFIG_HUB_TEST_PREFLIGHT_LOG = $savedEnvironment.PreflightLog
    $env:AI_CONFIG_HUB_TEST_CONCURRENT_TARGET = $savedEnvironment.ConcurrentTarget
    $env:AI_CONFIG_HUB_TEST_PREFLIGHT_MUTATION_TARGET = $savedEnvironment.PreflightMutationTarget
    $env:AI_CONFIG_HUB_TEST_PREFLIGHT_MUTATION_SOURCE = $savedEnvironment.PreflightMutationSource
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
