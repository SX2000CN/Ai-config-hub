# 工作任务：研究 Claude Code / Codex 浏览器视觉验证 MCP 全局配置

任务 ID：2026-05-18-browser-visual-mcp
创建时间：2026-05-18 00:00
更新时间：2026-05-18 00:00
状态：已完成
当前活动：否

后续状态：本任务的 Playwright MCP 推荐已于 2026-07-31 被 `2026-07-31-browser-automation-convergence` 和 ADR 0002 取代；历史研究与当时实施记录保留。

## 目标

研究 Claude Code 是否应全局配置 Playwright / 浏览器 MCP，用于真实网页截图、反复视觉审查和修复；同时确认 Codex 是否也需要类似配置、能否复用同一方案，以及当前最优配置路线。

## 背景和当前上下文

用户已确认：Pencil 画布验证不能替代真实浏览器验证。Claude Code 需要补真实网页截图、视觉审查和多轮修复能力；需要全局配置，并研究 Codex 是否也应一起配置。

## 待研究问题

1. Claude Code 当前推荐的全局 MCP 配置方式是什么。
2. Playwright MCP、Chrome DevTools MCP、Browser MCP 或项目内 Playwright 测试各自适用边界是什么。
3. Codex 是否需要独立配置浏览器 MCP，是否可与 Claude Code 共享同一 MCP server 命令。
4. 全局配置与项目级配置的取舍。
5. 这套方案是否应写入本仓库规则、skill 或 settings，而不是只靠记忆。

## 研究结论

- Claude Code 官方支持 MCP `stdio` / `sse` / `http`，可用 `claude mcp add --scope user ...` 做用户级全局配置；用户级适合个人跨项目通用浏览器工具。
- Claude Code 当前用户配置中实际只有 `pencil` MCP；未发现 Playwright / Chrome DevTools / BrowserMCP。
- Codex 官方/权威资料显示也支持 `~/.codex/config.toml` 下的 `[mcp_servers.<name>]` 配置；本机 `C:\Users\sx200\.codex\config.toml` 当前已有 `pencil` MCP，并启用了 `chrome`、`browser-use`、`browser` 等 Codex 插件，但没有 Playwright / Chrome DevTools MCP server。
- Node / npm / npx 可用：Node `v24.15.0`，npm/npx `11.12.1`。
- 当前 PowerShell PATH 中没有 `claude` / `codex` CLI 命令，因此如果要用官方 CLI 命令添加 MCP，需在 Claude Code / Codex 可用的终端环境执行，或直接编辑对应配置文件。

## 推荐方案

优先全局配置两类 MCP：

1. `chrome-devtools`：默认推荐，负责真实 Chrome 页面检查、截图、console、network、DOM、性能等调试能力。
2. `playwright`：补充推荐，负责可重复的自动化交互、截图、多轮 UI flow 验证。

暂不默认配置 `browsermcp`：它适合控制用户已登录的真实浏览器 tab，但需要浏览器扩展和手动连接，作为需要复用现有登录态时的后续补充。

## 分发方式修正

本项目当前已正式分发的是：

- 全局规则：`rules/*` → `rules/rendered/*` → `sync.ps1`。
- 全局 skills：`skills/*` → `skills/rendered/*` → `sync-skills.ps1`。

实现前，MCP、Claude Code settings、`C:\Users\sx200\.claude.json`、Codex `C:\Users\sx200\.codex\config.toml` 还没有纳入本项目的正式分发链路。`docs/architecture.md` 当时明确写着 Codex 真实 `config.toml` 暂不自动管理，只提供安全示例模板；`docs/sync-workflow.md` 也写着 v1 不自动修改 `C:\Users\sx200\.codex\config.toml`。

因此不应把浏览器 MCP 当成一次性直接改全局配置来处理。更符合本项目模式的做法是新增一条“工具配置 / MCP 配置分发链路”，再由脚本 dry-run、check、apply 到真实用户级配置。

## 建议配置内容

Claude Code 用户级 MCP 目标内容：

```powershell
claude mcp add --scope user chrome-devtools -- npx -y chrome-devtools-mcp@latest
claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest
```

如果最终采用文件分发，需要先确认 Claude Code 当前稳定、受支持的 MCP 持久化文件，而不是直接把 `C:\Users\sx200\.claude.json` 当作长期源头。

Codex 用户级 MCP 目标内容：

```toml
[mcp_servers.chrome-devtools]
command = "cmd"
args = ["/c", "npx", "-y", "chrome-devtools-mcp@latest"]
env = { SystemRoot = "C:\\Windows", PROGRAMFILES = "C:\\Program Files" }
startup_timeout_ms = 20000

[mcp_servers.playwright]
command = "cmd"
args = ["/c", "npx", "-y", "@playwright/mcp@latest"]
env = { SystemRoot = "C:\\Windows", PROGRAMFILES = "C:\\Program Files" }
startup_timeout_ms = 20000
```

Windows 下 Codex 使用 `cmd /c npx ...` 更稳，避免 PowerShell shim / 环境变量问题。

## 已实现分发链路

- 新增 `tool-configs/mcp/shared/browser-visual.json` 作为浏览器视觉验证 MCP 事实源。
- 新增 `tool-configs/mcp/rendered/claude-code.mcp.json` 和 `tool-configs/mcp/rendered/codex.mcp.toml` 作为可审阅片段产物。
- 新增 `scripts/render-mcp.ps1`，从事实源生成 Claude Code JSON 片段和 Codex TOML marker block。
- 新增 `scripts/check-mcp.ps1`，检查 source/rendered 结构、托管 server 边界和敏感信息风险。
- 新增 `scripts/sync-mcp.ps1`，默认 dry-run，只合并 `chrome-devtools` / `playwright`，保留现有 `pencil` 和未知配置，`-Apply` 前备份。
- 已更新 `README.md`、`docs/architecture.md`、`docs/sync-workflow.md`、`docs/secrets-policy.md`、`docs/skills-roadmap.md`、`skills/README.md` 和 `templates/codex-config.example.toml`。
- 已新增 `scripts/check-all.ps1`，用于同步前一次执行规则、skills、MCP 的 render、check 和 dry-run。

## 下一步最小动作

1. 已执行 `./scripts/sync-mcp.ps1 -Apply`，无需继续同步。
2. 后续如需运行时确认 MCP 可用，可在 Claude Code / Codex 会话中用 `/mcp` 查看，或在 CLI 可用环境中运行对应 mcp list 命令。
3. 如需要更稳定版本，再把 `@latest` 改成固定版本并重新 render/check/sync。

## 验证状态

已完成研究阶段核查：

- 已读取 `C:\Users\sx200\.claude\settings.json`：无 `mcpServers`，存在敏感 env，未修改。
- 已读取 `C:\Users\sx200\.claude.json`：`mcpServers` 只有 `pencil`。
- 已读取 `C:\Users\sx200\.codex\config.toml`：`mcp_servers.pencil` 已配置；浏览器相关 Codex 插件已启用；无 Playwright / Chrome DevTools MCP。
- 已检查 `C:\Users\sx200\.agents\config.toml`：文件不存在。
- 已检查本项目 `.mcp.json` / `.codex/config.toml`：不存在。
- 已检查 Node/npm/npx：可用。
- 已尝试 `claude mcp list` / `codex mcp list`：当前 PowerShell PATH 中命令不可用。

已完成实现阶段验证：

- 已运行 `./scripts/render-mcp.ps1`，成功生成 Claude Code / Codex MCP rendered 片段。
- 已运行 `./scripts/check-mcp.ps1`，输出 `MCP check passed`。
- 已运行 `./scripts/sync-mcp.ps1` dry-run：
  - Claude Code：would update，preserve `mcpServers.pencil`，add `mcpServers.chrome-devtools` / `mcpServers.playwright`。
  - Codex：would update，preserve `mcp_servers.pencil`，append managed browser-visual MCP block。
- 已运行 `./scripts/sync-mcp.ps1 -ClaudeCode` dry-run，结果同 Claude Code 目标预期。
- 已运行 `./scripts/sync-mcp.ps1 -Codex` dry-run，结果同 Codex 目标预期。
- 已运行 `./scripts/check.ps1`，输出 `Check passed`。
- 已运行 `./scripts/check-skills.ps1`，输出 `Skill check passed`。
- 已运行 `./scripts/check-all.ps1`，输出 `All render, check, and dry-run steps passed`。
- 已运行 `./scripts/sync-skills.ps1 -IncludeCodexLegacy` dry-run，确认 legacy Codex 目标也会覆盖 `pencil-design-workflow`，但历史目录均为 `missing target`。
- 已运行 `git diff --check`，无 whitespace error；仅有 Windows LF/CRLF 提示。

## 残留风险

- 已执行 `sync-mcp.ps1 -Apply`，真实 Claude Code / Codex 用户级配置已新增浏览器 MCP，并保留既有 Pencil MCP。
- `pencil-design-workflow` 已同步到用户级 Claude Code / Codex skill 目录；未同步历史 `.codex\skills`，符合用户确认的范围。
- 直接编辑 `C:\Users\sx200\.claude.json` 可能不是 Claude Code 推荐的长期稳定配置方式；当前通过同步脚本封装为可替换 backend。
- Codex 已启用浏览器插件，可能已有部分浏览器能力；但为了与 Claude Code 统一工作流，仍建议加 MCP server 做可明确调用的工具能力。
- `@latest` 会随上游变化；稳定性要求更高时可改为固定版本。
- MCP 浏览器工具能辅助视觉检查，但仍不等同完整 E2E 测试或像素级视觉回归基线。

## 关闭依据 / 最终结果

已完成 MCP / 工具配置分发链路实现，并执行 `./scripts/sync-mcp.ps1 -Apply` 写入真实用户级 Claude Code / Codex 配置；同步后 `./scripts/sync-mcp.ps1` dry-run 显示 Claude Code / Codex 均为 `unchanged`，`./scripts/check-all.ps1` 通过。
