# 工具面事实

配置分发、迁移或排查工具行为时才需要；普通任务不要读取本文件。这里是**环境事实**，不是协作契约——协作契约在全局规则文件里，只有一份。

## Claude Code

- 全局个人规则：`~/.claude/CLAUDE.md`。项目级优先项目根 `CLAUDE.md`。
- 个人 skill 目录：`~/.claude/skills/`。**不读 `~/.agents/skills/`**：官方 memory 文档明示 `.agents/` 目录下的内容不进入规则读取范围，skill 发现也不含该目录。
- 2.1.277 起支持直接读 `AGENTS.md`，但默认语义是：工作目录或上层只要存在 `CLAUDE.md` / `CLAUDE.local.md`，就不再读 `AGENTS.md`。本机 2.1.220 低于该版本，因此 Claude Code 必须保留专属 `CLAUDE.md` 格式。
- settings、hooks、permissions、statusline、MCP、环境变量：`~/.claude/settings.json`、`~/.claude.json`、项目 `.claude/`。
- PowerShell 工具底层为 `powershell.exe` 5.1，Bash 与 Monitor 用 POSIX shell。
- 内置 WebFetch 在云端发起请求，不走本机代理/VPN；只有任务允许联网、目标是公共 HTTP(S) URL、内置 WebFetch 属连通性故障且无安全/权限/认证拒绝时，才用 `mcp__local-webfetch__fetch` 兜底。

## Codex

- 全局个人规则：`~/.codex/AGENTS.md`；`~/.codex/AGENTS.override.md` 优先级更高。项目级用项目 `AGENTS.md`。
- 个人 skill 目录：`~/.agents/skills/`。`~/.codex/skills/` 已退役，不再创建副本。
- 模型、approval、sandbox、MCP、环境变量：`~/.codex/config.toml` 或项目 `.codex/config.toml`。完整 `config.toml` 不由 Hub 托管，只托管明确命名的 MCP 片段。

## Grok Build

- 全局个人规则：`~/.grok/AGENTS.md`。项目级 `AGENTS.md` 按目录链加载，越深路径优先。
- 主配置：`~/.grok/config.toml`。项目级只有 `.grok/config.toml` 可贡献 `[mcp_servers]`、`[plugins]`、`[permission]`。
- skill 发现：`~/.grok/skills/` 与每一层的 `.agents/skills/` 都会被扫描，另默认扫描 `~/.claude/skills/`、`~/.cursor/skills/`（由 `[compat.*]` 开关控制）。Hub 只维护 `~/.agents/skills/` 这一份共享副本，`~/.grok/skills` 已退役。
- Hub 托管的 MCP 写入 `~/.grok/config.toml` 的 managed marker 块；Apply 时关闭 `compat.claude` 的 mcps / skills / agents / rules 扫描，避免与 `~/.claude.json` 双源。
- hooks 与 plugins 不由 Hub 托管，用户自管 `~/.grok/hooks/`、`~/.grok/plugins/`。

## OpenCode

- 全局个人规则：`~/.config/opencode/AGENTS.md`；缺失时回退 `~/.claude/CLAUDE.md`。
- 个人 skill 目录：`~/.agents/skills/`，与 Codex、Grok 共用一份。不创建 `~/.config/opencode/skills/` 副本；同名 skill 多处重复时行为未定义。
- providers、model、tools、permission、MCP、plugin、instructions：`~/.config/opencode/opencode.json`；项目级 `opencode.json` 优先级更高。
- MCP 定义在 `opencode.json` 的 `mcp` 字段，不读 `.claude.json` 或 `config.toml`。local server 用 `type: "local"` 加 `command` 数组，可选 `environment`、`cwd`、`enabled`、`timeout`。**`timeout` 默认 5000ms，慢启动 server 必须显式放宽**，否则 tools 拉取失败。
- MCP tools 会常驻占用上下文，日常只启用当前任务需要的 server。

## 本机专属配置

- 代理等机器本地 env 放在未跟踪的 `tool-configs/mcp/private/<server>.env.json`，由 `sync-mcp.ps1` 在同步时合并；共享片段不携带机器本地事实。
- **隐性依赖**：该文件缺失时，下次 Apply 会写入不带 `env` 的条目。执行 Apply 前应在 dry-run 中确认 `update` 差异是否符合预期。
