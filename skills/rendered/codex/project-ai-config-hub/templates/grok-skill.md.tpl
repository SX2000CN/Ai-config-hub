---
name: {{skill_name}}
description: {{description}}
---

# {{skill_name}}

此文件是可选的 Grok discovery adapter 模板。默认优先使用 Grok 实际支持的共享 discovery path；只有需要独立 `.grok/skills/` 导出时，才将完整标准包复制到该目录。

## 事实源

完整包源：`.agents/skills/{{skill_name}}/`

该 adapter 必须包含完整包内容或由包目录生成；不要维护第二份触发语义或 workflow。

## 读取顺序

1. 仅当任务有接手价值、可能跨会话、已有活动任务、影响多个模块或涉及高风险写入时，读取 `.Ai-config/CURRENT.md`。
2. 如果存在相关活动任务卡，再读取 `.Ai-config/tasks/*.md` 中对应文件。
3. 读取当前 `.grok/skills/{{skill_name}}/` 包内的 `SKILL.md` 和相关资源。

如果 adapter 导出与 `.agents/skills/{{skill_name}}/` 不一致，先重新导出并验证。
