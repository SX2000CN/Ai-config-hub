# ai-config-hub 项目级说明

本文件只对当前仓库生效，不会分发到其他项目，也是本仓库项目特例的 canonical 事实源。根目录 `AGENTS.md` 只作为 Codex 薄入口指向本文，不重复维护同一套长期约束。

它补充 `project-ai-config-hub` 全局 skill 在本仓库中的特殊语义——这套 skill 面向任意目标项目设计，不认识"当前项目是不是 ai-config-hub 自己"，这件事只在这里说明。

## 触发场景

当用户说"更新项目 AI 配置""更新项目配置""让项目 AI 配置和全局配置匹配""全局已同步，现在更新项目配置"等，默认按 `audit` + `repair` 处理，不要先让用户在通用更新类型中选择。

## 处理流程

先做低风险只读判断：

1. 优先读取 `.Ai-config/CURRENT.md`、`.Ai-config/skills-registry.md`、相关任务卡。
2. 对比 `rules/rendered/*` 与用户级全局规则文件（`~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`）。
3. 对比 `skills/rendered/*` 与用户级全局 skill 目录（`~/.claude/skills/`、`~/.agents/skills/`）。

若 rendered/global 已一致，只刷新项目内 AI 状态文档；若不一致，先报告差异，再询问以项目源为准同步全局，还是以本机全局为准反向整理项目源。

只读审计和低风险项目状态追平（包括对比 `rules/rendered/*`、`skills/rendered/*` 与本机全局目标的一致性）可以直接执行；把本机全局内容反向覆盖项目源文件，或执行 `sync.ps1 -Apply`、`sync-skills.ps1 -Apply`、`sync-mcp.ps1 -Apply` 写入用户级目录，必须先确认。

## 本仓库验证边界

本仓库的规则、skills、MCP 和 runtime 属于配置分发管线，验证要求只在这里维护，不进入分发给所有项目的全局核心规则：

- 单一管线改动：运行对应 render `-Check`、check 和 sync/runtime dry-run。
- 跨管线改动、审计或准备任何用户级 Apply：运行 `scripts/check-all.ps1`。
- 用户级 Apply：先审阅完整 dry-run，确认后由同步脚本执行 preflight、staging、备份和回滚。
- 本仓库任务涉及多个配置管线、跨会话接手或未完成验证时，使用 `.Ai-config/CURRENT.md` 和任务卡记录状态；普通局部修复不强制建卡。

任何真实用户级 Apply、提交或推送都必须由用户当前请求明确授权。只要求仓库修复或 dry-run 时，不得顺带执行。
