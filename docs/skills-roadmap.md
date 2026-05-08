# Skills 路线图

`skills/` 目录用于后续管理 AI 编程工具的可复用能力。当前只是规划占位，不代表已经实现自动同步。

## 可能方向

- `skills/shared/`
  - 跨 Claude Code / Codex 通用的工作流说明。
  - 例如发版检查、文档同步检查、安全审查清单。

- `skills/claude-code/`
  - Claude Code skill 或 slash command 相关素材。
  - 可结合 Claude Code settings、hooks、MCP 使用。

- `skills/codex/`
  - Codex 侧的 skill、prompt、插件或 AGENTS 片段。
  - 保持和 Codex 官方支持能力对齐。

## 迭代原则

- 先沉淀文档和手动流程，再自动化。
- 不把工具专属机制强行抽象成通用机制。
- 每新增一个 skill，都应说明适用工具、入口、限制和验证方式。
