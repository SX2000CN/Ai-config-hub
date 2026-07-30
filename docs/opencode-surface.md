# OpenCode 适配边界

本文记录 Hub 对 OpenCode 的原生托管面。OpenCode 不读取 Claude Code 的 `.claude.json` 作为 MCP 配置，也不读取 Codex 的 `config.toml`；MCP 必须合并到 OpenCode 自己的 `opencode.json`。

## 用户路径

```text
~/.config/opencode/AGENTS.md
~/.config/opencode/opencode.json
~/.config/opencode/skills/<skill-name>/SKILL.md
```

规则由 `scripts/sync.ps1` 同步，skill 由 `scripts/sync-skills.ps1` 同步，MCP 由 `scripts/sync-opencode-mcp.ps1` 合并。OpenCode 的 `opencode.json` 同时包含 provider、model、权限和 MCP，因此 MCP 脚本只拥有 `mcp` 节，不覆盖其他配置。

## MCP 能力

| Profile | OpenCode 托管 server | 说明 |
|---|---|---|
| `core` | `local-webfetch` | 默认最小能力面 |
| `code-intel` | `local-webfetch`、`context-thread` | 需要代码关系或影响面分析时使用 |
| `browser` | `local-webfetch` | Playwright 暂不注册到 OpenCode |
| `browser-debug` | `local-webfetch` | Chrome DevTools 暂不注册到 OpenCode |
| `full` | `local-webfetch`、`context-thread` | 保守聚合，不包含浏览器 server |

浏览器 MCP 先保持在 Claude Code、Codex 和 Grok 的原有 surface 内。OpenCode 曾经出现过配置 MCP 后宿主崩溃的历史问题，当前适配先使用已验证的 Node runtime 和较小的 server 集合，待单独验证后再扩大范围。

## 合并与安全

- rendered 片段位于 `tool-configs/mcp/rendered/<profile>/opencode.mcp.json`，只包含 `mcp` 节。
- OpenCode local MCP 使用 `type: "local"`、合并后的 `command` 数组、`enabled` 和显式 `timeout`。
- Apply 前运行完整预检；执行时使用 staging、备份和目标指纹检查。
- 自定义 MCP server 保留；同名自定义配置与 active managed server 冲突时，Apply 阻断而不是静默覆盖。
- 可识别的 retired `pencil` 配置只在其命令或参数包含 Pencil 特征时移除。
- 真实用户级写入前先运行对应 profile 的 dry-run，并确认 OpenCode 当前版本可正常启动。

## 维护命令

```powershell
.\scripts\render-mcp.ps1 -Profile core
.\scripts\check-mcp.ps1 -Profile core
.\scripts\sync-opencode-mcp.ps1 -Profile core
.\scripts\sync-opencode-mcp.ps1 -Profile core -Apply
```

规则和 skills 的同步仍使用通用入口：

```powershell
.\scripts\sync.ps1
.\scripts\sync-skills.ps1
```
