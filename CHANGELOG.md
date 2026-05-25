# Changelog

## 2026-05-25

- 将项目文档重心从分发系统调整为 AI 配置本体，新增 `docs/ai-config-design.md`，并把脉络设计、实现和场景文档整理到 `docs/context-thread/`。
- 清理迁移后的旧 `docs/ai/` 副本，以及一次性视觉验证和 Pencil 测试产物；`.Ai-config/` 保留为当前项目 AI 接手事实源。
- 补强 context-thread 引擎的 MCP 工具关闭、watcher 说明、依赖方重解析和新增源码目录 pending 检测，并增加对应测试。
- 修复 context-thread runtime 依赖审计问题：升级 `picomatch` 锁定版本，并将 `vitest` 升级到安全版本以清理 dev audit 噪音。
- 在共享规则中加入项目文档和产物整理原则，要求旧入口、重复副本、一次性夹具和运行时临时文件不作为长期项目资产保留。

## 2026-05-24

- 将本仓库项目级 AI 配置中枢从旧版 `docs/ai/` 迁移到根目录 `.Ai-config/`，旧路径仅保留兼容提示；`.Ai-config/context-thread/` 作为脉络项目索引目录并加入忽略。
- 引入轻量结构化事实层：新增 `global-context-thread` skill，用 context-thread 承接复杂代码关系，用 `.Ai-config` 任务卡关系索引承接非代码复杂工作流，同时保持 L0/L1 小任务不升级。
- 新增 `context-thread` MCP 配置组，并把脉络引擎运行时分发到 `C:\Users\sx200\.ai-config-hub\mcp\context-thread\`；MCP 配置通过 `node` 启动用户级 runtime，不再指向当前仓库路径，runtime 缺失时仅 warning，不阻塞浏览器 MCP。
- 在共享规则中加入短版“结构化事实优先”原则，并给任务卡模板增加可选 `关系索引` 区块。

## 2026-05-19

- 轻量化全局 AI 规则：把默认工作方式改为按风险升级，减少小任务中的文档、任务卡、计划和验证仪式感。
- 调整 `project-ai-config-hub`：目标项目按需启用 `.Ai-config/CURRENT.md`、任务卡、registry 和项目级 skill 入口，不再把完整中枢作为所有项目的默认负担。
- 更新工作状态设计与项目文档，明确任务卡只用于跨会话、多任务、等待确认、阻塞或有残留风险的任务。
- 收紧 `pencil-design-workflow` 与 `global-frontend-design` 交接：设计请求默认必须使用当前会话可用的可见 Pencil MCP 宿主，VS Code/Cursor 插件端和 Pencil Desktop 客户端都可作为有效宿主；Pencil MCP 不可用时必须停下说明，不能静默降级到 CLI/headless 或直接进入前端实现。
- 轻量化 `pencil-design-workflow`：入口和主流程改为短闸门，CLI/headless、MCP 细节、保存位置和审查验证拆到按需 references，减少与前端设计 skill 叠加时的上下文负担。
- 补准 Pencil 宿主选择边界：宿主由当前 AI 工具环境注入，模型不能自由切换 Desktop 和插件端；只有当前宿主为 `desktop` 或用户明确要求 Desktop 主窗口时，才按 Desktop transport 细节处理。
- 补准 Pencil 直连 MCP 验证：要求确认当前会话暴露 Pencil MCP 工具或 `tools/list` 返回关键工具，使用 `open_document({ path })` 打开目标 `.pen`，并用 `get_editor_state` 确认 active editor，避免误用 `filePath` 新建 `pencil-new.pen`。

## 2026-05-08

- 初始化 `ai-config-hub` 项目脚手架。
- 添加共享规则源、Claude Code / Codex 专属补充、模板和渲染脚本。
- 添加检查脚本、同步脚本、安全示例配置和 skills 规划目录。
- 优化全局规则：补充验证策略、减少低价值文档更新、限定最终回复要求适用范围，并增强 Claude Code 配置机制说明。
- 精简共享规则中重复的文档要求，压缩项目文档覆盖说明和修改检查清单，降低全局提示词冗余。
- 新增通用规则：新功能或外部能力相关任务需优先联网核验最新权威资料，缺陷修复需遵循复现、根因定位、最小修复和回归验证流程。
- 新增版本控制与提交规则：默认优先使用中文提交信息，并要求提交前检查 diff、避免无关改动和敏感信息。
- 收窄外部资料核验规则：仅在外部能力、版本、安全、官方资料或用户明确要求时强制核验，纯项目内部新功能可不联网。
- 精简缺陷修复规则，保留复现、根因、最小修复、回归验证和残留风险反馈要求，降低全局提示词篇幅。
