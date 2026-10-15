# OpenCode 适配边界

本文记录 Hub 对 OpenCode 的可选 adapter。OpenCode 不读取 Claude Code 的 `.claude.json` 作为 MCP 配置，也不读取 Codex 的 `config.toml`；MCP 必须合并到 OpenCode 自己的 `opencode.json`。这些集成不属于共享规则或 Agent Skill 包本体。

## 用户路径

```text
~/.config/opencode/AGENTS.md
~/.config/opencode/opencode.json
~/.agents/skills/<skill-name>/SKILL.md
~/.claude/skills/<skill-name>/SKILL.md  # OpenCode 也会扫描 Claude 兼容目录
```

OpenCode 官方同时扫描 `.agents/skills` 和 `.claude/skills`，并要求不同来源的 Skill 名称唯一。Hub 只同步自身管理的 `.agents/skills`；若 Claude 也安装了同名完整包，OpenCode 会看到两个来源。当前公开文档没有给出可依赖的同名覆盖优先级或跨版本环境变量契约；目标版本若提供关闭 Claude 兼容扫描的开关，应由 adapter 按版本核验后配置。本机文档快照为 OpenCode `1.18.11`。否则应确保 OpenCode 会话只暴露一个包含这些 Skill 的发现根。

规则由 `scripts/sync.ps1` 同步，skill 由 `scripts/sync-skills.ps1` 从共享完整包导出到 Codex/OpenCode 共用的 `.agents/skills` 发现目录，MCP 由 `scripts/sync-opencode-mcp.ps1` 合并。`.agents/skills` 只是 OpenCode 的一个发现路径，不是内容事实源；Hub 不再同步 `~/.config/opencode/skills` 原生副本。已存在的 Hub 托管副本会按 marker 安全退役。OpenCode 的 `opencode.json` 同时包含 provider、model、权限和 MCP，因此 MCP 脚本只拥有 `mcp` 节，不覆盖其他配置。

## MCP 能力

| Profile | OpenCode 托管 server | 说明 |
|---|---|---|
| `core` | 无 | 默认不注册 managed MCP |
| `code-intel` | `context-thread` | 需要代码关系或影响面分析时使用 |
| `browser-debug` | `chrome-devtools` | 性能、Lighthouse、内存和深度调试 |
| `full` | `context-thread`、`chrome-devtools` | 聚合代码脉络与浏览器专项调试 |

OpenCode 的日常浏览器自动化使用用户级官方 Playwright CLI `agents` skill，不注册 Playwright MCP。Chrome DevTools MCP 作为完整开发能力进入 OpenCode 的 `browser-debug` 和 `full` profile，并继续使用 Hub 锁定的本地 runtime；`core` 和 `code-intel` 不常驻浏览器工具。

## 合并与安全

- rendered 片段位于 `tool-configs/mcp/rendered/<profile>/opencode.mcp.json`，只包含 `mcp` 节。
- OpenCode local MCP 使用 `type: "local"`、合并后的 `command` 数组、`enabled` 和显式 `timeout`。
- Apply 前运行完整预检；执行时使用 staging、备份和目标指纹检查。
- 自定义 MCP server 保留；同名自定义配置与 active managed server 冲突时，Apply 阻断而不是静默覆盖。
- 可识别的 retired `pencil`、Playwright MCP 和 owned inactive local-webfetch 会安全移除；同名自定义配置保留。
- 真实用户级写入前先运行对应 profile 的 dry-run，并确认 OpenCode 当前版本可正常启动。

## 维护命令

```powershell
.\scripts\render-mcp.ps1 -Profile core
.\scripts\check-mcp.ps1 -Profile core
.\scripts\sync-opencode-mcp.ps1 -Profile code-intel
.\scripts\sync-opencode-mcp.ps1 -Profile code-intel -Apply
```

规则和 skills 的同步仍使用通用入口：

```powershell
.\scripts\sync.ps1
.\scripts\sync-skills.ps1
```

当前发现路径参考：[官方路径核验与版本快照](../.agents/skills/project-ai-config-hub/references/official-paths.md)。
