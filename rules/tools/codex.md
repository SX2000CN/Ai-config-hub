## Codex 专用补充

- 全局个人规则维护在 `~/.codex/AGENTS.md`；如存在 `~/.codex/AGENTS.override.md`，其优先级更高。项目级规则优先维护在项目 `AGENTS.md`；若同时存在 `CLAUDE.md`，应明确 canonical 文件或保持核心约束一致。
- Codex CLI / VS Code 插件的模型、approval、sandbox、项目文档 fallback、MCP 和环境变量维护在 `~/.codex/config.toml` 或项目 `.codex/config.toml`。任何会改变执行权限、审批、沙箱、hook、MCP 或凭证暴露面的写入，无论用户级、项目级还是 local，都按高风险配置处理，且不能覆盖宿主策略。
- 全局规则保持紧凑，项目细节放项目文档。Codex 具备 MCP、云端委派和多工具能力，不代表普通任务要自动启用它们。
- VS Code 插件提供的当前文件、选区、diff 和云端委派状态可作为快速输入，修改前仍以实际文件、项目规则和用户当前要求为准。
- context-thread CLI 不是全局命令，不在 PATH、不是 npm 全局包。真实入口固定为 `~/.ai-config-hub/mcp/context-thread/dist/bin/context-thread.js`，必须用 `node <该路径> <子命令>` 调用；目标项目若有 `scripts/context-thread.ps1` wrapper 则优先使用，否则直接用 node 加完整路径，不要假设 `context-thread` 可作为裸命令执行。
