# ai-config-hub 项目级说明

本文件只对当前仓库生效，不会分发到其他项目，也是本仓库项目特例的 canonical 事实源。根目录 `AGENTS.md` 只作为 Codex 薄入口指向本文，不重复维护同一套长期约束。

它补充 `project-ai-config-hub` 全局 skill 在本仓库中的特殊语义——这套 skill 面向任意目标项目设计，不认识"当前项目是不是 ai-config-hub 自己"，这件事只在这里说明。

## 触发场景

当用户说"更新项目 AI 配置""更新项目配置""让项目 AI 配置和全局配置匹配""全局已同步，现在更新项目配置"等，默认按 `audit` + `repair` 处理，不要先让用户在通用更新类型中选择。

## 处理流程

先确定本次是在改配置内容本体、客户端 adapter，还是项目状态/索引：

1. 优先读取 `.Ai-config/CURRENT.md`、`.Ai-config/skills-registry.md`、相关任务卡。
2. 配置本体：规则读 `.agents/rules/core.md`；Skill 读 `.agents/skills/<name>/` 完整包；设计说明读对应 `docs/`。
3. Adapter 或本机部署任务：只读相关 `config/`、`scripts/`、`tool-configs/`、`tools/` 和 adapter 文档。不要把用户级配置与仓库源默认视为双向事实源。

普通配置维护以仓库内 canonical source 为准，不要求读取或追平用户级全局目录。规则适配文件从源生成；Skill 包直接从源同步到对应发现目录。从用户级目录反向覆盖源文件属于单独迁移决策。

## 本仓库验证边界

本仓库把规则与完整 Agent Skill 包作为内容本体，把路径导出和本机集成作为可选 adapter。验证要求只在这里维护，不进入分发给所有项目的共享规则：

- 规则改动：运行 `render.ps1 -Check` 和 `check.ps1`。
- Skill 包改动：运行 `check-skills.ps1`；没有仓库内 Skill 渲染步骤。
- 跨管线改动：运行 `scripts/check-all.ps1`。
- 仅当任务明确涉及本机部署时，才运行对应 sync dry-run；Apply 不属于配置源修改的默认步骤。
- 用户级 Apply：先审阅完整 dry-run，确认后由同步脚本执行 preflight、staging、备份和回滚。
- 本仓库任务涉及多个配置管线、跨会话接手或未完成验证时，使用 `.Ai-config/CURRENT.md` 和任务卡记录状态；普通局部修复不强制建卡。

任何真实用户级 Apply、提交或推送都必须由用户当前请求明确授权。只要求仓库修复或 dry-run 时，不得顺带执行。
