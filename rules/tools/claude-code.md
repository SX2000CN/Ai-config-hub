## Claude Code 专用补充

- 全局个人规则维护在 `~/.claude/CLAUDE.md`。
- 项目级规则优先维护在项目根目录 `CLAUDE.md`；如果项目同时维护 `AGENTS.md`，应保持核心约束一致，或明确其中一个作为源文件。
- 涉及 settings、hooks、permissions、statusline、MCP、skills、slash command 或其他自动化行为时，应优先使用 Claude Code 的对应配置机制，而不是只写自然语言规则；但工具具备 plan、skills、MCP 或 subagent 能力，不代表 F0/F1 小任务要自动启用。
- VS Code 插件模式下，当前文件、选区、诊断信息、inline diff 和 plan review 可能作为上下文提供；这些上下文可作为快速输入，修改前仍应以实际文件内容和当前任务路由为准。
- 如需配置 Claude Code settings、hooks、权限、MCP 或环境变量，应优先使用相关配置工具或直接维护 settings.json，并保持用户级、项目级、本地级配置边界清晰；写入用户级或共享配置按 F4 处理，先 dry-run / 说明影响并确认。
