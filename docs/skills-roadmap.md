# Skills 路线图

`skills/` 目录用于管理 AI 编程工具的可复用能力。当前已实现 `project-ai-config-hub`、`global-frontend-design` 和 `global-thinking-partner` 的源码化、渲染、检查和 dry-run 同步流程。

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

- 当前工作状态文档
  - 设计文档：[work-state-design.md](work-state-design.md)
  - 定位：项目级 AI 接手入口、多任务状态总览和任务无损接手卡，用于中断、隔天继续、切换任务或切换 AI 编程工具时恢复当前工作现场。
  - 当前实现：已接入 `rules/shared/core.md`、`project-ai-config-hub` 流程和模板；核心形态是项目内极简 Markdown 状态文件和任务卡，不以 hook 或 skill 作为核心机制。

- `project-ai-config-hub`
  - 定位：`ai-config-hub` 的项目级分身，用于在目标项目中创建和升级 `docs/ai/` 中枢、多任务工作状态机制和多端项目 skills。
  - 共享源：`skills/shared/project-ai-config-hub/`
  - Claude Code 入口源：`skills/claude-code/project-ai-config-hub/SKILL.md`
  - Codex 入口源：`skills/codex/project-ai-config-hub/SKILL.md`
  - rendered 包：`skills/rendered/`
  - 脚本：`scripts/render-skills.ps1`、`scripts/check-skills.ps1`、`scripts/sync-skills.ps1`

- `global-frontend-design`
  - 定位：全局前端设计 skill，用于创建、重设计或 review 前端界面，强调鲜明视觉方向、产品 UI 工程、可访问性、响应式、状态覆盖和验证。
  - 共享源：`skills/shared/global-frontend-design/`
  - Claude Code 入口源：`skills/claude-code/global-frontend-design/SKILL.md`
  - Codex 入口源：`skills/codex/global-frontend-design/SKILL.md`
  - rendered 包：`skills/rendered/`
  - 来源归档：`docs/ai/archive/global-frontend-design-sources/`

- `global-thinking-partner`
  - 定位：低副作用思维扩展 skill，用于复杂 coding 决策前的方案发散、失败模式、简化路径和维护者视角检查。
  - 共享源：`skills/shared/global-thinking-partner/`
  - Claude Code 入口源：`skills/claude-code/global-thinking-partner/SKILL.md`
  - Codex 入口源：`skills/codex/global-thinking-partner/SKILL.md`
  - rendered 包：`skills/rendered/`
  - 约束：默认只读、手动触发优先，不负责写代码、同步、提交或推送。

## 迭代原则

- 先沉淀文档和手动流程，再自动化。
- 不把工具专属机制强行抽象成通用机制。
- 每新增一个 skill，都应说明适用工具、入口、限制和验证方式。
- skill 正文默认中文为主；路径、命令、工具名和必要触发关键词保留原文，避免影响工具识别。
