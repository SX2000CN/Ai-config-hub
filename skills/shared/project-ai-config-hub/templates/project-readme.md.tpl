# {{skill_name}} Skill

状态：{{status}}

本目录是 `{{skill_name}}` 的项目级 canonical 事实源，路径应为：

```text
.agents/skills/{{skill_name}}/
```

`SKILL.md` 是该完整包的标准入口，承载用途、触发条件和核心指令；workflow 与支持资源可放在同一包内：

```text
.claude/skills/{{skill_name}}/SKILL.md
.agents/skills/{{skill_name}}/SKILL.md
```

`.agents/skills/` 同时是部分客户端支持的发现路径。Agent Skills 格式本身不规定该路径；Claude Code 需要时，从同一个完整包导出到 `.claude/skills/`。其他 adapter 只在目标客户端确实需要且经版本核实时添加。

OpenCode 也会扫描 `.claude/skills/` 兼容目录。若同时保留 `.agents/skills/` 与 `.claude/skills/` 导出，应确保运行环境只暴露一个发现根；目标版本若提供关闭兼容扫描的开关，先按该版本文档核验后再由 adapter 配置。

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
