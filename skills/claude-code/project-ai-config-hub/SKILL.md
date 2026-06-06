---
name: project-ai-config-hub
description: ai-config-hub 的项目级分身；当用户明确要初始化、创建、修改、迁移、审计、修复或同步项目级 AI 配置中枢或项目级 skill 时使用。
when_to_use: 用户在当前项目里要搭建或维护项目级 AI 配置中枢，尤其是新增、修改、迁移、审计、修复、同步项目级 skill，处理 .Ai-config/CURRENT.md、旧版 docs/ai 到 .Ai-config 的迁移、.Ai-config/tasks、多任务工作状态、v1 到 v2 状态迁移、双端入口和历史 .codex/skills 兼容时使用；只是读取状态、普通业务任务、F0/F1 问答或局部修复时不使用完整流程。
---

# 项目级 AI 配置中枢

<!-- ai-config-hub-managed: project-ai-config-hub -->

当用户明确要求初始化、创建、迁移、审计、修复或同步项目级 AI 配置中枢，或新增、修改、迁移项目级 skill 时使用本 skill。只读了解 `.Ai-config` 状态、普通业务任务、F0/F1 问答或局部修复，不自动进入完整中枢流程。

默认按风险和接手价值轻量启用配置：小项目可只保留项目规则或 `.Ai-config/CURRENT.md`；只有跨会话、多任务、等待确认、有残留风险或确有项目级 workflow 时，才创建任务卡、registry 或多端 skill 入口。

修改目标项目前，按顺序读取本 skill 自带文件：

1. `workflow.md`
2. `references/official-paths.md`
3. `references/design-checklist.md`
4. `templates/` 中和当前任务相关的模板

关键规则：

- 按需用 `.Ai-config/` 作为目标项目的 AI 配置中枢；不要把完整中枢当作所有项目的默认负担。
- 反触发：只是读取状态、普通代码/文档任务恰好提到 `.Ai-config` 路径、F0/F1 小任务或一次性问答时，不使用完整 audit/repair 流程。
- 级联边界：本 skill 不自动拉起 context-thread、思维伙伴或同步流程；确需跨域时回到主任务路由判断主次。
- 旧版 `docs/ai/` 只作为迁移来源和兼容事实源；新配置统一写入 `.Ai-config/`。
- 只有存在项目级 skill 时，才用 `.Ai-config/skills-registry.md` 记录清单、事实源、入口和状态。
- 只有确有项目级可复用 workflow 时，才生成 `.claude/skills/<skill-name>/SKILL.md` 和 `.agents/skills/<skill-name>/SKILL.md` 作为薄入口。
- 只有历史兼容或用户明确要求时，才使用 `.codex/skills/<skill-name>/SKILL.md`。
- 不要把完整项目流程复制到多个工具入口。
- 不要把真实凭证写入 skills、模板或普通文档。
- 修改已有项目级 skill 时，先找事实源，再改事实源，最后检查双端入口和 registry 是否仍一致。
- 在 `ai-config-hub` 本仓库中，用户说“更新项目 AI 配置”或“让项目配置和全局配置匹配”时，先按只读审计和项目状态追平处理，不要直接抛通用选项题。
- 覆盖、迁移、删除、写入全局目录，或触及发布、部署、生产数据等高风险流程前，先给计划并等待确认。
