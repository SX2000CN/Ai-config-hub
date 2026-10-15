# 项目级 AI 配置中枢

`project-ai-config-hub` 帮助任意目标项目维护项目规则、可移植 Agent Skill 包和按需状态索引。其核心工作是确定内容边界、收敛事实源并验证包；客户端发现路径和本机部署是可选 adapter。

本仓库 `ai-config-hub` 维护可复用的规则与 Skill 包。本 skill 不要求目标项目采用相同的同步系统，也不把 MCP、runtime 或用户级目录作为配置本体。

## 使用场景

- 初始化当前项目的 `.Ai-config/` 项目级 AI 配置中枢。
- 创建、维护或升级 `.Ai-config/CURRENT.md` AI 接手入口和多任务状态总览。
- 创建或维护 `.Ai-config/tasks/` 任务无损接手卡机制。
- 将旧版 `docs/ai/` 或早期单槽位 `.Ai-config/CURRENT.md` 状态迁移为 `.Ai-config/` 总览加任务卡。
- 为当前项目新增项目级 skill。
- 修改当前项目已有的项目级 skill。
- 把已有 Skill 内容收敛为一个完整 Agent Skill 包，并按实际需要适配客户端发现目录。
- 审计同一 Skill 是否存在互相冲突的内容副本。
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
.agents/skills/<skill-name>/
```

轻量项目可以只使用：

```text
AGENTS.md / CLAUDE.md
.Ai-config/CURRENT.md
```

`tasks/`、`archive/`、`skills-registry.md` 和 `skills/<skill-name>/` 都是按需层：只有存在跨会话任务、长期接手状态、项目级 skill 或用户明确要求时才创建。

默认由 `.agents/skills/<skill-name>/` 保存完整项目 Skill 包。该目录是部分客户端支持的发现路径，不是格式标准要求；Claude Code 需要独立发现路径时，导出同一完整包：

```text
.claude/skills/<skill-name>/SKILL.md
.agents/skills/<skill-name>/SKILL.md
```

只有在项目已有历史路径或用户明确要求兼容时，才处理：

```text
.codex/skills/<skill-name>/SKILL.md
```

## 工作原则

- 先识别项目已有文档、AI 规则和 skill 入口，再设计目录结构。
- 按风险和接手价值分层启用配置，不把完整 `.Ai-config/` 结构当作所有项目的默认负担。
- `.Ai-config/` 是项目状态和索引层；`.agents/skills/<skill-name>/` 是本项目约定的完整项目 Skill 包目录。
- 旧版 `docs/ai/`、工具目录和项目文档可作为迁移来源或支持性引用；durable Skill 内容放在完整包中，项目级通用规则仍放在规则入口。
- `.Ai-config/CURRENT.md` 是 AI 接手入口和多任务状态总览；只有有接手价值的任务才保存在 `.Ai-config/tasks/*.md`。
- 目标项目的主 README 只作为项目概览，不应被模板强行写成固定 agent 接手入口。
- 共享事实源描述真实项目状态，不把计划写成已完成。
- `.Ai-config/skills-registry.md` 只索引完整包和发现 adapter；多个客户端目录应导出同一完整包，不维护多份规则。
- 覆盖、迁移、删除、写入全局目录和高风险操作前，必须先列计划并等待确认。
- 不把真实密钥、Token、服务器密码或生产凭证写入 skill、模板或普通文档。

## 文件地图

- `workflow.md`：执行流程。
- `references/official-paths.md`：Claude Code / Codex / Grok / OpenCode 路径和兼容边界。
- `references/design-checklist.md`：设计、迁移和审计检查清单。
- `templates/`：项目共享文档、当前状态总览、任务卡、检查清单、归档摘要和工具入口模板。
