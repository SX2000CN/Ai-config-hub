# 工具面事实

仅在配置 adapter、迁移或排查工具行为时读取。这里记录客户端自己的配置机制，不是共享协作规则。具体发现路径见 [official-paths.md](official-paths.md)。

## Claude Code

- 项目规则由 `CLAUDE.md` 以及满足版本条件的 `AGENTS.md` 提供；目录链里已有 `CLAUDE.md` 时，不假设 `AGENTS.md` 会同时读取。
- Skills 使用 `.claude/skills/` 项目目录或 `~/.claude/skills/` 用户目录。不会自动发现 `.agents/skills/`。
- settings、permissions、hooks 和用户级 MCP 配置属于 Claude 专属 settings / MCP 文件，不放入共享 Skill 包。

## Codex

- 项目规则使用 `AGENTS.md` 目录链。
- Skills 使用 `.agents/skills/` 或 `~/.agents/skills/`；不为新配置创建 `.codex/skills/`。
- 模型、approval、sandbox 和 MCP 在 `config.toml` 等 Codex 配置中；完整用户配置不作为本仓库事实源。

## Grok Build

- 项目规则使用其支持的 `AGENTS.md` 目录链。
- 本机验证可从 `.agents/skills/` 发现 Skill；Hub 共用该路径，不再复制同一包到 `.grok/skills/`。
- hooks / plugins 和账户级配置不由 Hub 默认托管。

## OpenCode

- 指令使用 `AGENTS.md`、`.opencode/AGENTS.md` 或用户级 `~/.config/opencode/AGENTS.md`。
- 它可扫描 `.agents/skills/`、`.claude/skills/` 及 OpenCode 原生目录；同一名称从多个根出现时存在重复发现风险，公开文档不承诺覆盖优先级。为了避免同名多源，Hub 仅导出到 `.agents/skills/`，不额外创建 OpenCode skill 副本。
- 不要把 `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS` 等人工环境变量当作跨版本标准；目标版本若支持关闭兼容扫描，应由 adapter 显式配置并重新核验。
- providers、model、tools、permission、MCP、plugins 和 instructions 属于 `opencode.json`，不可混写到标准 Skill 包中。

## 本机专属配置

代理等机器本地环境变量放在未跟踪的 `tool-configs/mcp/private/<server>.env.json`，由 MCP adapter 按需合并。共享 package 和可追踪配置不得携带机器本地凭证或私有 URL。
