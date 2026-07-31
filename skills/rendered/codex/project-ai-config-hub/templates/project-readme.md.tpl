# {{skill_name}} Skill

状态：{{status}}

本目录是 `{{skill_name}}` 的项目级 canonical 事实源，路径应为：

```text
.Ai-config/skills/{{skill_name}}/
```

工具专属入口只作为发现和路由入口，不承载长期规则：

```text
.claude/skills/{{skill_name}}/SKILL.md
.agents/skills/{{skill_name}}/SKILL.md
.grok/skills/{{skill_name}}/SKILL.md
```

其中 `.agents/skills` 同时供 Codex 和 OpenCode 发现。

如需历史 Codex 兼容，可额外维护：

```text
.codex/skills/{{skill_name}}/SKILL.md
```

## 用途

{{purpose}}

## 触发场景

- {{trigger_1}}
- {{trigger_2}}

## 必读文件

- `README.md`：本文件，说明用途、触发和事实源边界。
- `workflow.md`：稳定执行流程；没有复杂流程时可省略。
- `checklists.md`：检查清单；没有长期检查项时可省略。
- `references/`：支持性参考资料；必须位于本 canonical 目录下，或在本文件中登记外部支持文档。
- `templates/`：可复用模板；必须位于本 canonical 目录下。

## 支持性项目文档

外部 README、docs、脚本说明、issue 或旧版 `docs/ai/` 可以作为证据、背景或迁移来源，但不能替代本目录作为 skill 事实源。若外部文档中存在 durable 规则，应摘要或索引到本目录，再从这里引用外部原文。

## 工作状态

任务有接手价值、可能跨会话、涉及多任务切换、影响多个模块或包含高风险写入时，先读取 `.Ai-config/CURRENT.md`。如果存在相关活动任务卡，应继续读取 `.Ai-config/tasks/*.md` 中对应文件，避免覆盖旧任务现场。简单问答、一次性命令和一轮内完成且无残留风险的小修复，不需要启动完整状态流程。

## 限制

- {{limitation_1}}
- {{limitation_2}}
