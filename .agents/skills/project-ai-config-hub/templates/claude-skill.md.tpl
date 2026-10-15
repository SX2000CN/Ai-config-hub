---
name: {{skill_name}}
description: {{description}}
---

# {{skill_name}}

此文件是历史薄入口模板，默认不应单独生成可发现的 Skill。Claude Code 需要该能力时，应把 `.agents/skills/{{skill_name}}/` 的完整包导出到 `.claude/skills/{{skill_name}}/`，确保入口包含 package resources。

## 事实源

完整包源：`.agents/skills/{{skill_name}}/`

不要把此模板当作独立 Skill 包。若客户端需要无法放入标准包的扩展，单独维护 adapter 配置，不复制触发语义和 workflow。

## 读取顺序

1. 仅当任务有接手价值、可能跨会话、已有活动任务、影响多个模块或涉及高风险写入时，读取 `.Ai-config/CURRENT.md`。
2. 如果存在相关活动任务卡，再读取 `.Ai-config/tasks/*.md` 中对应文件。
3. 读取当前 `.claude/skills/{{skill_name}}/` 包内的 `SKILL.md` 和相关资源。

如果导出包与 `.agents/skills/{{skill_name}}/` 不一致，先重新导出并验证。
