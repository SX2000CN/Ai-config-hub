# Skills 路线图

`skills/` 目录用于管理 AI 编程工具的可复用能力。当前已实现 `project-ai-config-hub` 的 v1 源码化、渲染、检查和 dry-run 同步流程。

`project-ai-config-hub` 的历史计划和设计已归档到：[archive/project-ai-config-hub/](archive/project-ai-config-hub/)。当前实现继续维护在本页下方。

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

## 已实现

- `project-ai-config-hub`
  - 定位：`ai-config-hub` 的项目级分身，用于在目标项目中创建 `docs/ai/` 中枢和多端项目 skills。
  - 共享源：`skills/shared/project-ai-config-hub/`
  - Claude Code 入口源：`skills/claude-code/project-ai-config-hub/SKILL.md`
  - Codex 入口源：`skills/codex/project-ai-config-hub/SKILL.md`
  - rendered 包：`skills/rendered/`
  - 脚本：`scripts/render-skills.ps1`、`scripts/check-skills.ps1`、`scripts/sync-skills.ps1`

## 迭代原则

- 先沉淀文档和手动流程，再自动化。
- 不把工具专属机制强行抽象成通用机制。
- 每新增一个 skill，都应说明适用工具、入口、限制和验证方式。
- skill 正文默认中文为主；路径、命令、工具名和必要触发关键词保留原文，避免影响工具识别。
