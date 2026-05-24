# {{skill_name}} Skill

状态：{{status}}

## 用途

{{purpose}}

## 触发场景

- {{trigger_1}}
- {{trigger_2}}

## 事实源

本目录是 `{{skill_name}}` 的项目级事实源。工具专属入口只作为薄入口：

```text
.claude/skills/{{skill_name}}/SKILL.md
.agents/skills/{{skill_name}}/SKILL.md
```

如需历史 Codex 兼容，可额外维护：

```text
.codex/skills/{{skill_name}}/SKILL.md
```

## 必读文件

- `workflow.md`
- `checklists.md`
- `references/`
- `templates/`

## 工作状态

任务有接手价值、可能跨会话、涉及多任务切换或属于高风险修改时，先读取 `.Ai-config/CURRENT.md`。如果存在相关活动任务卡，应继续读取 `.Ai-config/tasks/*.md` 中对应文件，避免覆盖旧任务现场。简单问答、一次性命令和一轮内完成且无残留风险的小修复，不需要启动完整状态流程。

## 限制

- {{limitation_1}}
- {{limitation_2}}
