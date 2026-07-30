@{
    SchemaVersion = 2

    Rules = @{
        SharedCore = 'rules\shared\core.md'
        Targets = @(
            @{
                Name = 'ClaudeCode'
                Template = 'templates\CLAUDE.md.tpl'
                Supplement = 'rules\tools\claude-code.md'
                Placeholder = '{{claude_code_supplement}}'
                Rendered = 'rules\rendered\CLAUDE.md'
                UserRelativePath = '.claude\CLAUDE.md'
            }
            @{
                Name = 'Codex'
                Template = 'templates\AGENTS.md.tpl'
                Supplement = 'rules\tools\codex.md'
                Placeholder = '{{codex_supplement}}'
                Rendered = 'rules\rendered\AGENTS.md'
                UserRelativePath = '.codex\AGENTS.md'
            }
            @{
                Name = 'Grok'
                Template = 'templates\grok-AGENTS.md.tpl'
                Supplement = 'rules\tools\grok.md'
                Placeholder = '{{grok_supplement}}'
                Rendered = 'rules\rendered\grok-AGENTS.md'
                UserRelativePath = '.grok\AGENTS.md'
            }
            @{
                Name = 'OpenCode'
                Template = 'templates\opencode-AGENTS.md.tpl'
                Supplement = 'rules\tools\opencode.md'
                Placeholder = '{{opencode_supplement}}'
                Rendered = 'rules\rendered\opencode-AGENTS.md'
                UserRelativePath = '.config\opencode\AGENTS.md'
            }
        )
    }

    Skills = @{
        Names = @(
            'project-ai-config-hub'
            'global-frontend-design'
            'global-thinking-partner'
            'global-context-thread'
        )
        # Managed skill directories that must be removed from user targets on sync-skills -Apply.
        Retired = @(
            'pencil-design-workflow'
        )
        Definitions = @(
            @{
                Name = 'project-ai-config-hub'
                Role = 'domain'
                Activation = 'deliverable'
                ExclusiveWith = @()
                HandoffTo = @('global-thinking-partner', 'global-context-thread')
                Exclusions = @('ordinary-business-task', 'read-only-status', 'local-fix')
            }
            @{
                Name = 'global-frontend-design'
                Role = 'domain'
                Activation = 'deliverable'
                ExclusiveWith = @()
                HandoffTo = @()
                Exclusions = @('local-style-fix', 'backend-only')
            }
            @{
                Name = 'global-thinking-partner'
                Role = 'reasoning-mode'
                Activation = 'explicit-visible-or-implicit-silent'
                ExclusiveWith = @()
                HandoffTo = @('project-ai-config-hub', 'global-frontend-design')
                Exclusions = @('explicit-execution', 'local-fix', 'known-root-cause')
            }
            @{
                Name = 'global-context-thread'
                Role = 'tool-router'
                Activation = 'conditional'
                ExclusiveWith = @()
                HandoffTo = @('project-ai-config-hub')
                Exclusions = @('single-file-task', 'plain-status-analysis', 'stale-index')
            }
        )
        Targets = @(
            @{
                Name = 'ClaudeCode'
                SourceRoot = 'skills\claude-code'
                RenderedRoot = 'skills\rendered\claude-code'
                UserRelativeRoot = '.claude\skills'
                RequireWhenToUse = $true
            }
            @{
                Name = 'Codex'
                SourceRoot = 'skills\codex'
                RenderedRoot = 'skills\rendered\codex'
                UserRelativeRoot = '.agents\skills'
                RequireWhenToUse = $false
            }
            @{
                Name = 'CodexLegacy'
                SourceRoot = 'skills\codex'
                RenderedRoot = 'skills\rendered\codex-legacy'
                UserRelativeRoot = '.codex\skills'
                RequireWhenToUse = $false
            }
            @{
                Name = 'Grok'
                SourceRoot = 'skills\grok'
                RenderedRoot = 'skills\rendered\grok'
                UserRelativeRoot = '.grok\skills'
                RequireWhenToUse = $false
            }
            @{
                Name = 'OpenCode'
                SourceRoot = 'skills\opencode'
                RenderedRoot = 'skills\rendered\opencode'
                UserRelativeRoot = '.config\opencode\skills'
                RequireWhenToUse = $false
            }
        )
    }

    Mcp = @{
        DefaultProfile = 'core'
        Servers = @(
            @{
                Name = 'local-webfetch'
                Source = 'tool-configs\mcp\shared\local-webfetch.json'
                Targets = @('ClaudeCode', 'Grok', 'OpenCode')
                LegacyServers = @()
                LegacySignatures = @(
                    @{ Type = 'stdio'; Command = 'node'; Args = @('~\.ai-config-hub\mcp\local-webfetch\index.js'); CodexStyle = 'direct' }
                    @{ Type = 'stdio'; Command = 'cmd'; Args = @('/c', 'node', '~\.ai-config-hub\mcp\local-webfetch\index.js') }
                )
                RequiresRuntime = 'local-webfetch'
                Optional = $false
                PreferredFor = @('web-fetch', 'documentation-fallback')
                Doctor = @{ Mode = 'node-check'; ExpectedToolCount = 1 }
            }
            @{
                Name = 'context-thread'
                Source = 'tool-configs\mcp\shared\context-thread.json'
                Targets = @('ClaudeCode', 'Codex', 'Grok', 'OpenCode')
                LegacyServers = @()
                LegacySignatures = @(
                    @{ Type = 'stdio'; Command = 'node'; Args = @('~\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js', 'serve', '--mcp'); CodexStyle = 'direct' }
                    @{ Type = 'stdio'; Command = 'cmd'; Args = @('/c', 'node', '~\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js', 'serve', '--mcp') }
                    @{ Command = 'node'; Args = @('~\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js', 'serve', '--mcp'); StartupTimeoutMs = 20000 }
                )
                RequiresRuntime = 'context-thread'
                Optional = $true
                PreferredFor = @('code-intelligence', 'impact-analysis')
                Doctor = @{ Mode = 'node-command'; Args = @('--help'); ExpectedToolCount = 9 }
            }
            @{
                Name = 'playwright'
                Source = 'tool-configs\mcp\shared\playwright.json'
                Targets = @('ClaudeCode', 'Codex', 'Grok')
                LegacyServers = @()
                LegacySignatures = @(
                    @{ Command = 'npx'; Args = @('-y', '@playwright/mcp@0.0.78'); StartupTimeoutMs = 20000 }
                    @{ Command = 'npx'; Args = @('-y', '@playwright/mcp@latest'); StartupTimeoutMs = 20000 }
                    @{ Type = 'stdio'; Command = 'npx'; Args = @('-y', '@playwright/mcp@latest'); CodexStyle = 'direct' }
                    @{ Command = 'cmd'; Args = @('/c', 'npx', '-y', '@playwright/mcp@latest') }
                )
                RequiresRuntime = 'browser-mcp'
                Optional = $true
                PreferredFor = @('browser-automation', 'browser-testing', 'ui-verification')
                Doctor = @{ Mode = 'browser-runtime'; Args = @('--doctor', 'playwright'); ExpectedToolCount = 24 }
            }
            @{
                Name = 'chrome-devtools'
                Source = 'tool-configs\mcp\shared\chrome-devtools.json'
                Targets = @('ClaudeCode', 'Codex', 'Grok')
                LegacyServers = @()
                LegacySignatures = @(
                    @{ Command = 'npx'; Args = @('-y', 'chrome-devtools-mcp@1.6.0'); StartupTimeoutMs = 20000 }
                    @{ Command = 'npx'; Args = @('-y', 'chrome-devtools-mcp@latest'); StartupTimeoutMs = 20000 }
                    @{ Type = 'stdio'; Command = 'npx'; Args = @('-y', 'chrome-devtools-mcp@latest'); CodexStyle = 'direct' }
                    @{ Command = 'cmd'; Args = @('/c', 'npx', '-y', 'chrome-devtools-mcp@latest') }
                )
                RequiresRuntime = 'browser-mcp'
                Optional = $true
                PreferredFor = @('browser-debugging', 'performance-analysis')
                Doctor = @{ Mode = 'browser-runtime'; Args = @('--doctor', 'chrome-devtools'); ExpectedToolCount = 29 }
            }
        )
        Profiles = @(
            @{ Name = 'core'; Servers = @('local-webfetch'); LocalServers = @() }
            @{ Name = 'code-intel'; Servers = @('local-webfetch', 'context-thread'); LocalServers = @() }
            @{ Name = 'browser'; Servers = @('local-webfetch', 'playwright'); LocalServers = @() }
            @{ Name = 'browser-debug'; Servers = @('local-webfetch', 'chrome-devtools'); LocalServers = @() }
            @{ Name = 'full'; Servers = @('local-webfetch', 'context-thread', 'playwright', 'chrome-devtools'); LocalServers = @() }
        )
        Targets = @(
            @{
                Name = 'ClaudeCode'
                RenderedByProfile = @{
                    core = 'tool-configs\mcp\rendered\claude-code.mcp.json'
                    'code-intel' = 'tool-configs\mcp\rendered\code-intel\claude-code.mcp.json'
                    browser = 'tool-configs\mcp\rendered\browser\claude-code.mcp.json'
                    'browser-debug' = 'tool-configs\mcp\rendered\browser-debug\claude-code.mcp.json'
                    full = 'tool-configs\mcp\rendered\full\claude-code.mcp.json'
                }
                UserRelativePath = '.claude.json'
            }
            @{
                Name = 'Codex'
                RenderedByProfile = @{
                    core = 'tool-configs\mcp\rendered\codex.mcp.toml'
                    'code-intel' = 'tool-configs\mcp\rendered\code-intel\codex.mcp.toml'
                    browser = 'tool-configs\mcp\rendered\browser\codex.mcp.toml'
                    'browser-debug' = 'tool-configs\mcp\rendered\browser-debug\codex.mcp.toml'
                    full = 'tool-configs\mcp\rendered\full\codex.mcp.toml'
                }
                UserRelativePath = '.codex\config.toml'
            }
            @{
                Name = 'Grok'
                RenderedByProfile = @{
                    core = 'tool-configs\mcp\rendered\grok.mcp.toml'
                    'code-intel' = 'tool-configs\mcp\rendered\code-intel\grok.mcp.toml'
                    browser = 'tool-configs\mcp\rendered\browser\grok.mcp.toml'
                    'browser-debug' = 'tool-configs\mcp\rendered\browser-debug\grok.mcp.toml'
                    full = 'tool-configs\mcp\rendered\full\grok.mcp.toml'
                }
                UserRelativePath = '.grok\config.toml'
            }
            @{
                Name = 'OpenCode'
                RenderedByProfile = @{
                    core = 'tool-configs\mcp\rendered\opencode.mcp.json'
                    'code-intel' = 'tool-configs\mcp\rendered\code-intel\opencode.mcp.json'
                    browser = 'tool-configs\mcp\rendered\browser\opencode.mcp.json'
                    'browser-debug' = 'tool-configs\mcp\rendered\browser-debug\opencode.mcp.json'
                    full = 'tool-configs\mcp\rendered\full\opencode.mcp.json'
                }
                # This is a managed fragment merged into opencode.json.mcp by sync-opencode-mcp.ps1.
                UserRelativePath = '.config\opencode\opencode.json'
            }
        )
        LocalServers = @()
        # Recognizable legacy local MCP names removed on sync-mcp -Apply when ownership matches.
        RetiredLocalServers = @('pencil')
    }

    Runtimes = @(
        @{
            Name = 'context-thread'
            SourceRoot = 'tools\context-thread-engine'
            UserRelativeRoot = '.ai-config-hub\mcp\context-thread'
            EntryRelativePath = 'dist\bin\context-thread.js'
            SyncScript = 'scripts\sync-context-thread-runtime.ps1'
        }
        @{
            Name = 'local-webfetch'
            SourceRoot = 'tools\local-webfetch'
            UserRelativeRoot = '.ai-config-hub\mcp\local-webfetch'
            EntryRelativePath = 'index.js'
            SyncScript = 'scripts\sync-local-webfetch-runtime.ps1'
        }
        @{
            Name = 'browser-mcp'
            SourceRoot = 'tools\browser-mcp-runtime'
            UserRelativeRoot = '.ai-config-hub\mcp\browser'
            EntryRelativePath = 'bin\browser-mcp-runtime.js'
            SyncScript = 'scripts\sync-browser-mcp-runtime.ps1'
        }
    )

    UserPaths = @{
        StagingRoot = '.ai-config-hub\staging'
        BackupRoot = '.ai-config-hub\backups'
    }
}
