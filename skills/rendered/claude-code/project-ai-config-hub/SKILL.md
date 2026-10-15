---
name: project-ai-config-hub
description: ai-config-hub 的项目级分身；用于初始化、创建、修改、迁移、审计或修复项目级 AI 配置中枢与 skills。用户说“更新/修复项目 AI 配置”时默认 audit + repair（含 CURRENT hygiene 与退役残留清理）；只读状态、普通业务任务、一次性问答和局部修复不触发完整流程。
---

# 项目级 AI 配置中枢

<!-- ai-config-hub-managed: project-ai-config-hub -->

当用户明确要求初始化、创建、迁移、审计、修复或同步项目级 AI 配置中枢，或新增、修改、迁移项目级 skill 时使用本 skill。用户说「更新项目 AI 配置」「修复项目 AI 配置」时默认 `audit` + `repair`，包含 CURRENT hygiene 与已退役能力残留清理。只读了解 `.Ai-config` 状态、普通业务任务、一次性问答或局部修复，不自动进入完整中枢流程。

默认按风险和接手价值轻量启用配置：小项目可只保留项目规则或 `.Ai-config/CURRENT.md`；只有跨会话、多任务、等待确认、有残留风险或确有项目级 workflow 时，才创建任务卡、registry 或多端 skill 入口。

修改目标项目前的**最小读取集**（禁止无差别通读 templates）：

1. `workflow.md` 中与当前 mode 相关的小节
2. 若涉及 CURRENT / 更新项目配置：`references/current-hygiene.md`
3. 需要路径边界时：`references/official-paths.md`
4. 仅当创建/修复具体文件时，再读 `templates/` 中对应一个模板

关键规则：

- 按需用 `.Ai-config/` 保存项目状态与索引；不要把完整中枢当作所有项目的默认负担。
- `CURRENT.md` 必须保持薄仪表盘；超限或塞满 runbook/changelog 时先 hygiene 再继续。
- 项目级 Agent Skill 的完整标准包默认放在 `.agents/skills/<skill-name>/`；这是本 skill 采用的项目约定，不是 Agent Skills 规范规定的发现路径。Codex 和 OpenCode 可从该位置发现；Claude Code 使用 `.claude/skills/<skill-name>/` adapter。OpenCode 也会扫描 `.claude/skills/`，所以同包双路径导出时，OpenCode 环境应设置 `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` 并按版本复核。不要把 durable skill 内容放进 `.Ai-config/`。
- `.Ai-config/skills-registry.md` 只登记包路径、发现 adapter 和状态，不复制 Skill 内容。
- 若发现 skill 事实散落在 README、docs、脚本说明、工具入口或旧版 `docs/ai` 中，应先做事实源收敛计划，再继续修改 skill。
- 反触发：只是读取状态、普通代码/文档任务恰好提到 `.Ai-config` 路径、局部任务或一次性问答时，不使用完整 audit/repair 流程。
- 级联边界：本 skill 不自动拉起 context-thread、思维伙伴或同步流程；确需跨域时回到主任务路由判断主次。
- 旧版 `docs/ai/` 只作为迁移来源；新项目规则落在 `AGENTS.md` 或相应客户端规则入口，skill 包落在 `.agents/skills/`。
- 已退役的 `pencil-design-workflow` 等全局能力：清理项目入口与 registry 引用，不把 Pencil 当作设计先行依赖。
- 只有存在项目级 skill 时，才用 `.Ai-config/skills-registry.md` 记录清单、事实源、入口和状态。
- 只有确有项目级可复用 workflow 时，才生成各工具发现路径所需的 adapter；若客户端接受同一标准包，adapter 应复制完整包而不是另写一份规则。
- 不要把完整项目流程复制到多个工具入口。
- 不要把真实凭证写入 skills、模板或普通文档。
- 修改已有项目级 skill 时，先找事实源，再改事实源，最后检查发现 adapter 和 registry 是否仍一致。
- 本 skill 面向任意目标项目，不识别“当前项目是不是 ai-config-hub 自己”；如果目标项目根目录的 `CLAUDE.md` / `AGENTS.md` 有更具体的项目专属指引，优先遵循那份文件。
- 覆盖、迁移、删除、写入全局目录，或触及发布、部署、生产数据等高风险流程前，先给计划并等待确认。
