---
name: project-ai-config-hub
description: ai-config-hub 的项目级分身；当用户要初始化、创建、修改、迁移、审计、修复或同步项目级 skill，或提到 docs/ai、CURRENT.md、tasks、skills-registry、.claude/skills、.agents/skills、.codex/skills、项目级 skill 中枢时自动使用。
when_to_use: 用户在当前项目里要搭建或维护项目级 AI 配置中枢，尤其是新增、修改、迁移、审计、修复、同步项目级 skill，处理 docs/ai/CURRENT.md、docs/ai/tasks、多任务工作状态、v1 到 v2 状态迁移、双端入口和历史 .codex/skills 兼容时。
---

# 项目级 AI 配置中枢

<!-- ai-config-hub-managed: project-ai-config-hub -->

当用户要求初始化项目级 AI 配置中枢，或新增、修改、迁移、审计、修复、同步项目级 skill 时自动使用本 skill。用户不需要显式说出 `project-ai-config-hub`；只要需求涉及项目级 skill、`docs/ai/`、`docs/ai/CURRENT.md`、`docs/ai/tasks/`、v1 到 v2 工作状态迁移、`.claude/skills`、`.agents/skills` 或 `.codex/skills`，就按本 skill 工作。

修改目标项目前，按顺序读取本 skill 自带文件：

1. `workflow.md`
2. `references/official-paths.md`
3. `references/design-checklist.md`
4. `templates/` 中和当前任务相关的模板

关键规则：

- 优先用 `docs/ai/` 作为目标项目的 AI 配置中枢，用 `docs/ai/skills/<skill-name>/` 作为具体 skill 事实源。
- 用 `docs/ai/skills-registry.md` 记录项目级 skills 清单、事实源、入口和状态。
- 生成 `.claude/skills/<skill-name>/SKILL.md` 和 `.agents/skills/<skill-name>/SKILL.md` 作为薄入口。
- 只有历史兼容或用户明确要求时，才使用 `.codex/skills/<skill-name>/SKILL.md`。
- 不要把完整项目流程复制到多个工具入口。
- 不要把真实凭证写入 skills、模板或普通文档。
- 修改已有项目级 skill 时，先找事实源，再改事实源，最后检查双端入口和 registry 是否仍一致。
- 覆盖、迁移、删除、写入全局目录，或触及发布、部署、生产数据等高风险流程前，先给计划并等待确认。
