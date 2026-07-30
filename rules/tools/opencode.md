## OpenCode 专用补充

- 全局个人规则维护在 `~/.config/opencode/AGENTS.md`。OpenCode 具备 Claude Code 兼容读取：`AGENTS.md` 缺失时回退 `~/.claude/CLAUDE.md`，skills 除本机 `~/.config/opencode/skills/` 外还会发现 `~/.claude/skills/` 和 `~/.agents/skills/`。同名 skill 在多处重复时行为未定义，应保证全局唯一。
- providers、model、small_model、tools、permission、MCP、plugin 和 instructions 都维护在 `~/.config/opencode/opencode.json`；TUI 专属项在 `~/.config/opencode/tui.json`。项目级配置放项目根 `opencode.json`，优先级高于全局。任何会改变执行权限、审批、MCP 或凭证暴露面的写入，无论用户级还是项目级，都按高风险配置处理，且不能覆盖宿主策略。
- MCP 定义在 `opencode.json` 的 `mcp` 字段下，不读取 Claude Code 的 `.claude.json` 或 Codex 的 `config.toml`。local server 使用 `type: "local"` 加 `command` 数组（可执行文件与参数合并在同一数组），可选 `environment`、`cwd`、`enabled` 和 `timeout`；`timeout` 默认 5000ms，慢启动 server 必须显式放宽，否则 tools 拉取失败。
- MCP tools 会常驻占用上下文，日常只启用当前任务需要的 server；不需要时用 `tools` 字段或 `enabled: false` 关闭，不要因为配置里存在就全开。
- Windows 11 双 Shell：OpenCode 的 shell 由 `opencode.json` 的 `shell` 字段决定，未配置时按平台推断（Windows 下为 `pwsh` 或 `cmd.exe`）。传给 shell 工具的命令必须匹配实际 shell 语法；PowerShell 5.1 不接受 `&&`、`grep`、`/dev/null` 等 POSIX 写法。
- context-thread CLI 不是全局命令，不在 PATH、不是 npm 全局包。真实入口固定为 `~\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js`，必须用 `node <该路径> <子命令>` 调用；目标项目若有 `scripts\context-thread.ps1` wrapper 则优先使用，否则直接用 node 加完整路径，不要假设 `context-thread` 可作为裸命令执行。
