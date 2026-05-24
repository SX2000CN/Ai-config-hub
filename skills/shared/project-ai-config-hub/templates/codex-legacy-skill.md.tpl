---
name: {{skill_name}}
description: {{description}}
---

# {{skill_name}}

这是历史 Codex 兼容入口。

行动前先读取当前工作状态和共享事实源：

- `.Ai-config/CURRENT.md`
- `.Ai-config/tasks/` 中和当前任务相关的任务卡
- `.Ai-config/skills/{{skill_name}}/README.md`
- `.Ai-config/skills/{{skill_name}}/workflow.md`
- `.Ai-config/skills/{{skill_name}}/checklists.md`

新 Codex 项目优先使用 `.agents/skills/{{skill_name}}/SKILL.md`。
