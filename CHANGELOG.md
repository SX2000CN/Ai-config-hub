# Changelog

## 2026-05-19

- 轻量化全局 AI 规则：把默认工作方式改为按风险升级，减少小任务中的文档、任务卡、计划和验证仪式感。
- 调整 `project-ai-config-hub`：目标项目按需启用 `docs/ai/CURRENT.md`、任务卡、registry 和项目级 skill 入口，不再把完整中枢作为所有项目的默认负担。
- 更新工作状态设计与项目文档，明确任务卡只用于跨会话、多任务、等待确认、阻塞或有残留风险的任务。
- 收紧 `pencil-design-workflow` 与 `global-frontend-design` 交接：设计请求默认必须使用 Pencil Desktop/MCP 可视化流程，IDE 插件只作为用户明确指定当前画布时的例外；Desktop/MCP 不可用时必须停下说明，不能静默降级到 CLI/headless 或直接进入前端实现。
- 轻量化 `pencil-design-workflow`：入口和主流程改为短闸门，CLI/headless、MCP 细节、保存位置和审查验证拆到按需 references，减少与前端设计 skill 叠加时的上下文负担。
- 补准 Pencil Desktop 打开链路：区分启动 Desktop、连接 Desktop transport 和打开 `.pen`，明确 `pencil interactive -a desktop -i <file.pen>` 是连接检查，MCP server 握手不等于 Desktop 已连接；Windows 下普通 `Start-Process` 秒退时改用 `Invoke-Item` / `explorer.exe` 拉起真实窗口。

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
