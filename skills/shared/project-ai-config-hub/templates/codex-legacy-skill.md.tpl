---
name: {{skill_name}}
description: {{description}}
---

# {{skill_name}}

这是历史 Codex `.codex/skills` 兼容入口。新 Codex 项目优先使用 `.agents/skills/{{skill_name}}/SKILL.md`。

## 事实源

canonical 事实源：`.Ai-config/skills/{{skill_name}}/`

不要把 workflow、checklists、references、templates、长期规则或业务事实写在本兼容入口里；这些内容应维护在 canonical 事实源下。

## 读取顺序

1. 仅当任务有接手价值、可能跨会话、已有活动任务、影响多个模块或涉及高风险写入时，读取 `.Ai-config/CURRENT.md`。
2. 如果存在相关活动任务卡，再读取 `.Ai-config/tasks/*.md` 中对应文件。
3. 读取 `.Ai-config/skills/{{skill_name}}/README.md`。
4. 按 README 指引读取同目录下的 `workflow.md`、`checklists.md`、`references/` 或 `templates/`。

如果 `.Ai-config/skills/{{skill_name}}/` 缺失、过期，或只是跳转到散落在项目各处的文档，先停止并修复 / 收敛事实源，不要继续把规则写进工具入口。
