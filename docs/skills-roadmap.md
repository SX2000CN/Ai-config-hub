# Skills 路线图

`skills/` 目录是这套 AI 配置的可复用能力层，不只是可分发文件包。它把项目中枢、前端设计、思维扩展和脉络关系等专门工作流沉淀为 AI 可按需触发的能力。

当前已实现 `project-ai-config-hub`、`global-frontend-design`、`global-thinking-partner`、`global-context-thread` 的源码化、渲染、检查和 dry-run 同步流程。`pencil-design-workflow` 已退役：由 frontend 的 UI brief 路径承接设计先行，sync-skills 会删除托管副本。

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
  - 当前实现：已接入 `rules/shared/core.md`、`project-ai-config-hub` 流程和模板；核心形态是项目内极简 Markdown 状态文件和按需任务卡，不以 hook 或 skill 作为核心机制。轻量项目可以只保留项目规则或 `.Ai-config/CURRENT.md`，只有跨会话、多任务、等待确认或有残留风险时才创建任务卡。

- `project-ai-config-hub`
  - 定位：`ai-config-hub` 的项目级分身，用于在目标项目中按风险和接手价值创建或升级 `.Ai-config/` 中枢、多任务工作状态机制和多端项目 skills。
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
  - 来源归档：`.Ai-config/archive/global-frontend-design-sources/`

- `global-thinking-partner`
  - 定位：可组合 reasoning mode；显式触发进入多轮协作探索、假设挑战、情景和二阶影响推演，隐式触发只做静默健全性检查。
  - 共享源：`skills/shared/global-thinking-partner/`
  - Claude Code 入口源：`skills/claude-code/global-thinking-partner/SKILL.md`
  - Codex 入口源：`skills/codex/global-thinking-partner/SKILL.md`
  - rendered 包：`skills/rendered/`
  - 约束：低副作用表示不擅自扩大授权或写入状态，不限制推理深度；用户转入实现后不阻断领域 workflow。
  - 评测：`skills/evals/global-thinking-partner/` 保存真实 prompt 夹具和定性 rubric，CI 不调用付费模型。

- `global-context-thread`
  - 定位：“脉络”轻量结构化事实层 skill，用于代码关系、配置关系、影响面或复杂工作流关系分析，优先查询 context-thread 或 `.Ai-config` 关系索引来缩小上下文。
  - 设计文档：`docs/context-thread/design.md`
  - 技术实现文档：`docs/context-thread/implementation.md`
  - 共享源：`skills/shared/global-context-thread/`
  - Claude Code 入口源：`skills/claude-code/global-context-thread/SKILL.md`
  - Codex 入口源：`skills/codex/global-context-thread/SKILL.md`
  - rendered 包：`skills/rendered/`
  - 约束：简单问答和普通局部任务不自动初始化索引、不创建任务卡；context-thread 只负责代码结构关系，非代码复杂工作流由任务卡关系索引承接。

- ~~`pencil-design-workflow`~~（已退役）
  - 原定位：Pencil 设计先行工具路由。
  - 替代：`global-frontend-design` 的设计先行 / UI brief 路径。
  - 清理：`Skills.Retired` + `sync-skills.ps1 -Apply` 删除用户级托管目录；项目内入口由 `project-ai-config-hub` audit+repair 清理。

## 路由契约

`config/managed-assets.psd1` 为每个 managed skill 登记 `Role`、`Activation`、`ExclusiveWith`、`HandoffTo` 和排除条件，`skills/evals/routes.json` 保存正例、反例和组合场景。Codex 的 `description` 必须同时包含触发能力和关键排除条件，因为正文只会在触发后加载。

## 迭代原则

- 先沉淀文档和手动流程，再自动化。
- 不把工具专属机制强行抽象成通用机制。
- 每新增一个 skill，都应说明适用工具、入口、限制和验证方式。
- skill 正文默认中文为主；路径、命令、工具名和必要触发关键词保留原文，避免影响工具识别。
