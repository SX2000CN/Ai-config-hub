# 项目级 AI 配置中枢

`project-ai-config-hub` 是 `ai-config-hub` 的项目级分身。它作为全局 skill 安装到 Claude Code、Codex 和 OpenCode 后，在任意目标项目里按需创建、升级、审计和修复该项目自己的 AI 配置中枢。

主项目 `ai-config-hub` 管全局规则、全局 skills 和本机同步流程；本 skill 把同一套“事实源、入口、检查、同步”的管理思想带到项目级。

## 使用场景

- 初始化当前项目的 `.Ai-config/` 项目级 AI 配置中枢。
- 创建、维护或升级 `.Ai-config/CURRENT.md` AI 接手入口和多任务状态总览。
- 创建或维护 `.Ai-config/tasks/` 任务无损接手卡机制。
- 将旧版 `docs/ai/` 或早期单槽位 `.Ai-config/CURRENT.md` 状态迁移为 `.Ai-config/` 总览加任务卡。
- 为当前项目新增项目级 skill。
- 修改当前项目已有的项目级 skill。
- 把已有 `.codex/skills`、`.agents/skills`、`.claude/skills` 或 `.opencode/skills` 迁移为共享事实源加工具入口。
- 审计项目内多个 AI 工具入口是否漂移。
- 为同一个项目能力生成 Claude Code、Codex 和 OpenCode 入口。
- 检查 skill 中是否包含敏感信息、过期路径或重复事实源。
- 读取目标项目自己的根目录 `CLAUDE.md` / `AGENTS.md`，如果里面有比本 skill 更具体的项目专属指引，优先遵循那份文件。

## 默认事实源

完整项目级中枢使用：

```text
.Ai-config/
.Ai-config/CURRENT.md
.Ai-config/tasks/
.Ai-config/tasks/README.md
.Ai-config/archive/
.Ai-config/skills-registry.md
.Ai-config/skills/<skill-name>/
```

轻量项目可以只使用：

```text
AGENTS.md / CLAUDE.md
.Ai-config/CURRENT.md
```

`tasks/`、`archive/`、`skills-registry.md` 和 `skills/<skill-name>/` 都是按需层：只有存在跨会话任务、长期接手状态、项目级 skill 或用户明确要求时才创建。

工具目录只放薄入口：

```text
.claude/skills/<skill-name>/SKILL.md
.agents/skills/<skill-name>/SKILL.md
.opencode/skills/<skill-name>/SKILL.md
```

只有在项目已有历史路径或用户明确要求兼容时，才生成：

```text
.codex/skills/<skill-name>/SKILL.md
```

## 工作原则

- 先识别项目已有文档、AI 规则和 skill 入口，再设计目录结构。
- 按风险和接手价值分层启用配置，不把完整 `.Ai-config/` 结构当作所有项目的默认负担。
- `.Ai-config/` 是项目级 AI 配置中枢，`.Ai-config/skills/<skill-name>/` 是普通目标项目中项目级 skill 的 canonical 事实源。
- 旧版 `docs/ai/`、项目 README / docs、脚本说明和工具入口只作为迁移来源、支持性引用或兼容入口；durable skill 规则统一写入 `.Ai-config/skills/<skill-name>/`。
- `.Ai-config/CURRENT.md` 是 AI 接手入口和多任务状态总览；只有有接手价值的任务才保存在 `.Ai-config/tasks/*.md`。
- 目标项目的主 README 只作为项目概览，不应被模板强行写成固定 agent 接手入口。
- 共享事实源描述真实项目状态，不把计划写成已完成。
- 工具入口必须明确指向 `.Ai-config/skills/<skill-name>/` canonical 事实源，不能复制完整规则，也不能直接串联散落在项目各处的事实文件。
- 覆盖、迁移、删除、写入全局目录和高风险操作前，必须先列计划并等待确认。
- 不把真实密钥、Token、服务器密码或生产凭证写入 skill、模板或普通文档。

## 文件地图

- `workflow.md`：执行流程。
- `references/official-paths.md`：Claude Code / Codex / Grok / OpenCode 路径和兼容边界。
- `references/design-checklist.md`：设计、迁移和审计检查清单。
- `templates/`：项目共享文档、当前状态总览、任务卡、检查清单、归档摘要和工具入口模板。
