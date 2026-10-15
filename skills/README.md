# Skills

`skills/shared/<name>/` 保存本仓库维护的完整 Agent Skill 包：标准 `SKILL.md` 与该 skill 所需的相对资源。它是每个包唯一的内容事实源。

## 当前目录

- `shared/`：完整标准包源码。
- `evals/`：路由和行为审查样例，不是运行时注册表。
- `rendered/`：同一包导出到不同客户端发现目录的生成物。
- `claude-code/`、`codex/`：旧入口源目录，当前渲染流程不再读取；保留作迁移和清理候选，不要继续编辑。

## 发现 adapter

Agent Skills 定义包格式，不规定自动发现路径。当前 renderer 将相同 package 导出到：

- `rendered/claude-code/<name>/`，用于 Claude Code 的 `.claude/skills/<name>/`。
- `rendered/codex/<name>/`，用于 `.agents/skills/<name>/`，供支持该路径的 Codex、OpenCode 和 Grok 使用。

`when_to_use` 不属于可移植 frontmatter；skill 触发和反触发语义写入标准 `description` 与正文。客户端专属字段只能由明确的 adapter 处理，不能成为共享包的第二份语义源。

## 维护与验证

编辑 `skills/shared/<name>/` 后运行：

```powershell
.\scripts\render-skills.ps1
.\scripts\check-skills.ps1
```

`render-skills.ps1 -Check` 和 `check-skills.ps1` 不写文件。用户级部署由 `sync-skills.ps1` 独立处理，默认 dry-run；它不是更新 Skill 内容源的必需步骤。

当前包：`project-ai-config-hub`、`global-frontend-design`、`global-thinking-partner`、`global-context-thread`。
