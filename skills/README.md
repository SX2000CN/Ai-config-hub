# Skills

这里用于整理 AI 编程工具的可复用 skills、工作流和提示词片段。

当前目录结构：

- `shared/`：跨工具通用能力和事实源。
- `claude-code/`：Claude Code 专属入口源。
- `codex/`：Codex 专属入口源。
- `rendered/`：由 `scripts/render-skills.ps1` 生成的安装包。

当前已实现：

- `project-ai-config-hub`：`ai-config-hub` 的项目级分身，用于在目标项目中按风险和接手价值创建 `.Ai-config/` AI 配置中枢，并创建、迁移、审计和修复多端项目 skills。
- `global-frontend-design`：全局前端设计 skill，用于创建、重设计或 review 前端界面，先建立鲜明视觉方向，再落地生产级 UI 工程约束。
- `global-thinking-partner`：可组合 reasoning mode，用于多轮脑暴、假设挑战、情景和二阶影响推演，以及按需决策收敛。
- `global-context-thread`：“脉络”工具路由 skill，仅在结构化关系查询比普通文件读取更有效时使用 context-thread 或 `.Ai-config` 关系索引。

维护流程：

```powershell
.\scripts\render-skills.ps1
.\scripts\check-skills.ps1
.\scripts\sync-skills.ps1
```

确认 dry-run 后才执行：

```powershell
.\scripts\sync-skills.ps1 -Apply
```

新增 skill 时，应同时记录适用工具、安装位置、调用方式和验证方式。

内容风格：

- 面向用户和维护者的正文默认使用中文。
- `name`、路径、命令、工具名和必要英文关键词保留原文。
- `description` 可以中文为主，但应保留 Claude Code、Codex、`.claude/skills`、`.agents/skills` 等关键触发词。
