## Codex 专用补充

- 全局个人规则维护在 `~/.codex/AGENTS.md`；如存在 `~/.codex/AGENTS.override.md`，其优先级更高。
- 项目级规则优先维护在项目内 `AGENTS.md`；如存在 `AGENTS.override.md`，其优先级更高。
- 如果项目同时维护 `CLAUDE.md`，应保持 `AGENTS.md` 和 `CLAUDE.md` 的核心约束一致，或明确其中一个作为源文件。
- Codex CLI / VS Code 插件的模型、approval、sandbox、项目文档 fallback、MCP 等配置应维护在 `~/.codex/config.toml` 或项目 `.codex/config.toml`。
- 避免让全局规则过长；项目细节应放项目文档，防止超过项目文档读取限制。
- VS Code 插件模式下，当前文件、选区、diff 和云端委派能力可能影响工作流；修改前仍应以实际文件内容和项目规则为准。
