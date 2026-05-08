# 项目级 AI 配置中枢

`project-ai-config-hub` 是 `ai-config-hub` 的项目级分身。它作为全局 skill 安装到 Claude Code 和 Codex 后，在任意目标项目里创建和维护该项目自己的 AI 配置中枢。

主项目 `ai-config-hub` 管全局规则、全局 skills 和本机同步流程；本 skill 把同一套“源文件、入口、检查、同步”的管理思想带到项目级。

## 使用场景

- 初始化当前项目的 `docs/ai/` 项目级 AI 配置中枢。
- 为当前项目新增项目级 skill。
- 修改当前项目已有的项目级 skill。
- 把已有 `.codex/skills`、`.agents/skills` 或 `.claude/skills` 迁移为共享事实源加工具入口。
- 审计项目内多个 AI 工具入口是否漂移。
- 为同一个项目能力生成 Claude Code 和 Codex 双端入口。
- 检查 skill 中是否包含敏感信息、过期路径或重复事实源。

## 默认事实源

目标项目默认使用：

```text
docs/ai/
docs/ai/skills-registry.md
docs/ai/skills/<skill-name>/
```

工具目录只放薄入口：

```text
.claude/skills/<skill-name>/SKILL.md
.agents/skills/<skill-name>/SKILL.md
```

只有在项目已有历史路径或用户明确要求兼容时，才生成：

```text
.codex/skills/<skill-name>/SKILL.md
```

## 工作原则

- 先识别项目已有文档、AI 规则和 skill 入口，再设计目录结构。
- `docs/ai/` 是项目级 AI 配置中枢，`docs/ai/skills/<skill-name>/` 是具体 skill 事实源。
- 共享事实源描述真实项目状态，不把计划写成已完成。
- 工具入口必须明确指向共享事实源，不能复制完整规则。
- 覆盖、迁移、删除、写入全局目录和高风险操作前，必须先列计划并等待确认。
- 不把真实密钥、Token、服务器密码或生产凭证写入 skill、模板或普通文档。

## 文件地图

- `workflow.md`：执行流程。
- `references/official-paths.md`：Claude Code / Codex 路径和兼容边界。
- `references/design-checklist.md`：设计、迁移和审计检查清单。
- `templates/`：项目共享文档和工具入口模板。

