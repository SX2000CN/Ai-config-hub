---
name: {{skill_name}}
description: {{description}}
---

# {{skill_name}}

仅在当前仓库内使用这个项目级 skill。

行动前先读取当前工作状态和共享事实源：

- `.Ai-config/CURRENT.md`
- `.Ai-config/tasks/` 中和当前任务相关的任务卡
- `.Ai-config/skills/{{skill_name}}/README.md`
- `.Ai-config/skills/{{skill_name}}/workflow.md`
- `.Ai-config/skills/{{skill_name}}/checklists.md`

以共享事实源为准。这个文件只是 Claude Code 工具入口。
