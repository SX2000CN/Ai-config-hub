---
name: {{skill_name}}
description: {{description}}
---

# {{skill_name}}

此文件是 `.agents/skills/{{skill_name}}/` 完整 Agent Skill 包的标准入口，包含本 Skill 的用途、触发条件和核心指令。Workflow、references 和其他资源如有需要，均与此文件同包保存。

## 事实源

本项目约定的完整包位置：`.agents/skills/{{skill_name}}/`。这是客户端发现路径约定，不是 Agent Skills 格式规定的路径。

不要把该包拆成薄入口加仓库外的规则副本。若 Claude Code 等客户端需要另一发现路径，将同一个完整包复制到对应目录并检查文件一致。

## 读取顺序

1. 仅当任务有接手价值、可能跨会话、已有活动任务、影响多个模块或涉及高风险写入时，读取 `.Ai-config/CURRENT.md`。
2. 如果存在相关活动任务卡，再读取 `.Ai-config/tasks/*.md` 中对应文件。
3. 读取当前 skill package 中的 `README.md`（若存在）。
4. 按包内主文件指引读取同目录下的 workflow、checklists、references 或 templates。

项目通用规则仍属于项目规则文件；不要把与该 Skill 无关的项目规则塞进本包。
