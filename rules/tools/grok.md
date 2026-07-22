## Grok Build 专用补充

- 全局个人规则维护在 `~/.grok/AGENTS.md`。项目级规则优先维护在项目根 `AGENTS.md`；若同时存在 `CLAUDE.md` / `Claude.md`，应明确 canonical 文件或保持核心约束一致。Grok 会按目录链加载匹配的指令文件，更深路径优先。
- 主配置在 `~/.grok/config.toml`；项目级仅 `.grok/config.toml` 可贡献 `[mcp_servers]`、`[plugins]`、`[permission]` 与 `[mcp] max_output_bytes`。任何会改变执行权限、审批、沙箱、hook、MCP 或凭证暴露面的写入，无论用户级、项目级还是 local，都按高风险配置处理，且不能覆盖宿主策略。
- 全局 skills 以 `~/.grok/skills/<name>/` 为 Hub 原生目标；项目级 skill 薄入口为 `.grok/skills/<name>/SKILL.md`，canonical 事实源仍在目标项目 `.Ai-config/skills/<name>/`。不要把 Claude/Codex 目录当作 Grok 的主 skill 源。
- Hub 托管的 MCP 写入 `~/.grok/config.toml` 的 managed marker 块；Apply 后应关闭 `compat.claude.mcps`（以及 managed 的 claude skills/agents/rules 扫描），避免与 `~/.claude.json` / home Claude 规则双源。自定义用户 MCP、模型与 auth 不由 Hub 覆盖。
- hooks 与 plugins 不由 ai-config-hub 托管：用户可自管 `~/.grok/hooks/`、`~/.grok/plugins/` 或 `[plugins].paths`；不要在本仓库为 Grok 新增 hooks/plugins 分发管线。
- VS Code / 编辑器插件提供的当前文件、选区、诊断和 plan review 可作为快速输入，修改前仍以实际文件、项目规则和用户当前要求为准。
- Windows 下 shell 与工具差异：优先使用 Grok 内置工具；需要本机命令时注意 PowerShell 5.1 与 POSIX shell 语法不可混用。
- context-thread CLI 不是全局命令，不在 PATH、不是 npm 全局包。真实入口固定为 `~/.ai-config-hub/mcp/context-thread/dist/bin/context-thread.js`，必须用 `node <该路径> <子命令>` 调用；目标项目若有 `scripts/context-thread.ps1` wrapper 则优先使用，否则直接用 node 加完整路径，不要假设 `context-thread` 可作为裸命令执行。
