# ai-config-hub 项目级说明

本文件只对当前仓库生效，不会分发到其他项目。它补充 `project-ai-config-hub` 全局 skill 在本仓库中的特殊语义——这套 skill 面向任意目标项目设计，不认识"当前项目是不是 ai-config-hub 自己"，这件事只在这里说明。

## 触发场景

当用户说"更新项目 AI 配置""更新项目配置""让项目 AI 配置和全局配置匹配""全局已同步，现在更新项目配置"等，默认按 `audit` + `repair` 处理，不要先让用户在通用更新类型中选择。

## 处理流程

先做低风险只读判断：

1. 优先读取 `.Ai-config/CURRENT.md`、`.Ai-config/skills-registry.md`、相关任务卡。
2. 对比 `rules/rendered/*` 与用户级全局规则文件（`~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`）。
3. 对比 `skills/rendered/*` 与用户级全局 skill 目录（`~/.claude/skills/`、`~/.agents/skills/`）。

若 rendered/global 已一致，只刷新项目内 AI 状态文档；若不一致，先报告差异，再询问以项目源为准同步全局，还是以本机全局为准反向整理项目源。

只读审计和低风险项目状态追平（包括对比 `rules/rendered/*`、`skills/rendered/*` 与本机全局目标的一致性）可以直接执行；把本机全局内容反向覆盖项目源文件，或执行 `sync.ps1 -Apply`、`sync-skills.ps1 -Apply`、`sync-mcp.ps1 -Apply` 写入用户级目录，必须先确认。
