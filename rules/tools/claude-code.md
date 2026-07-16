## Claude Code 专用补充

- 全局个人规则维护在 `~/.claude/CLAUDE.md`。项目级规则优先维护在项目根 `CLAUDE.md`；若同时存在 `AGENTS.md`，应明确 canonical 文件或保持核心约束一致。
- settings、hooks、permissions、statusline、MCP、skills、slash command 和环境变量应通过 Claude Code 对应配置机制维护。任何会改变执行权限、审批、沙箱、hook、MCP 或凭证暴露面的写入，无论用户级、项目级还是 local，都按高风险配置处理，且不能覆盖宿主策略。
- VS Code 插件提供的当前文件、选区、诊断、inline diff 和 plan review 可作为快速输入，修改前仍以实际文件、项目规则和用户当前要求为准。
- 联网核实时优先使用当前任务指定或内置的官方数据源。只有任务允许联网、目标是公共 HTTP(S) URL、内置 WebFetch 明确属于连通性故障且没有安全/权限/认证拒绝时，才可用 `mcp__local-webfetch__fetch` 兜底；不得转发 cookie、认证头、含凭证 URL 或私网地址，也不得绕过上层数据源限制。
- Windows 11 双 Shell：PowerShell 工具底层为 `powershell.exe` 5.1，只接受 PowerShell 语法；Bash 和 Monitor 使用 POSIX shell。不要把 `&&`、`grep`、`/dev/null` 等 Bash 写法传给 PowerShell，也不要把 PowerShell 语法传给 Bash/Monitor。
- 预期 30 秒内完成的命令优先同步执行并直接读取结果。后台任务不继承会话中新刷新的 PATH；刚安装的 CLI 使用完整路径或在任务开头显式刷新 PATH。
- context-thread CLI 不是全局命令，不在 PATH、不是 npm 全局包。真实入口固定为 `~\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js`，必须用 `node <该路径> <子命令>` 调用；目标项目若有 `scripts\context-thread.ps1` wrapper 则优先使用，否则直接用 node 加完整路径，不要假设 `context-thread` 可作为裸命令执行。
