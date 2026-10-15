# Skills

本目录不再保存 Skill 本体。完整 Agent Skill 包位于 `.agents/skills/<name>/`；这里仅保留行为评测样例和客户端导出物。

## 当前目录

- `.agents/skills/`：完整标准包源码，唯一内容事实源。
- `evals/`：路由和行为审查样例，不是运行时注册表。
+ `rendered/`：历史客户端导出候选；当前 Skill 包不生成中间副本。
- `claude-code/`、`codex/`：已移除的旧入口，不应重新创建。

## 发现 adapter

Agent Skills 定义包格式，不规定自动发现路径。本仓库直接将 package source 放在客户端发现路径中：

+ `.agents/skills/<name>/`，供支持该发现路径的客户端使用；这不是 Agent Skills 规范强制的唯一目录。

Claude Code adapter 暂停维护。需要 Claude 支持时，再依据当时的官方发现行为恢复 adapter。

`when_to_use` 不属于可移植 frontmatter；skill 触发和反触发语义写入标准 `description` 与正文。客户端专属字段只能由明确的 adapter 处理，不能成为共享包的第二份语义源。

## 维护与验证

编辑 `.agents/skills/<name>/` 后运行：

```powershell
.\scripts\check-skills.ps1
```

`check-skills.ps1` 只检查本体包结构、引用和路由样例。用户级部署由 `sync-skills.ps1` 独立处理，默认 dry-run，直接从本体复制完整 package；它不是更新 Skill 内容源的必需步骤。

当前包：`project-ai-config-hub`、`global-frontend-design`、`global-thinking-partner`、`global-context-thread`。
