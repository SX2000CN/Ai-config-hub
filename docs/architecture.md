# 架构说明

本项目维护配置内容本体，再按需适配客户端的发现路径。用户级部署、MCP servers 和本地 runtime 是可选基础设施；它们不能反过来决定共享规则与 Skill 包应写什么。

## 主结构

```text
可移植内容源
  .agents/rules/core.md
  .agents/skills/<name>/SKILL.md + package resources
            |
            +------> 项目状态与索引
            |          .Ai-config/CURRENT.md / tasks / registry
            |          .Ai-config/context-thread/ (project index data)
            |
            v
客户端发现 adapter
  AGENTS.md / CLAUDE.md / client skill paths
  client-specific settings, permissions, hooks, subagents, plugins, MCP
            |
            v
可选导出、验证与本机部署
  scripts/ + config/managed-assets.psd1 + rendered/ + tools/
```

`AGENTS.md` 是规则文件名；`.agents/skills/` 是某些客户端采用的发现目录。两者不是同一种配置，也不是同一开放标准。Agent Skills 定义 skill 包格式，不规定上述目录由哪个客户端扫描。

## 内容本体

### 规则

`.agents/rules/core.md` 是跨工具共享的协作约束源。规则保持与客户端配置语法无关。仓库根 `AGENTS.md` 和 `CLAUDE.md` 是本仓库自己的薄项目入口，不是全局分发源。

本仓库生成的 `rules/rendered/*` 是客户端可读取的导出文件。具体工具的规则发现能力、优先级和回退行为由 adapter 文档记录；不能因为文件名相同就假设客户端行为相同。

### Agent Skills

每个包位于 `.agents/skills/<name>/`，由 `SKILL.md` 和可选的相对资源文件组成。包是唯一的内容事实源。当前只维护 `.agents/skills/` 发现路径；Claude Code adapter 暂停维护，旧 rendered 包不参与检查和同步。

可移植包只使用 Agent Skills 规范定义的 frontmatter 字段；触发与反触发语义写在 `description` 和正文中，不使用自定义的 `when_to_use` 字段。包引用的文件必须随包分发。

`skills/claude-code/` 与 `skills/codex/` 是已移除的旧入口，不应重新创建。`skills/rendered/` 只保留历史导出候选，当前不生成或校验中间 Skill 副本。

`.agents/skills/` 是 Codex/OpenCode 的客户端发现路径约定，不是 Agent Skills 开放规范规定的路径。发现路径映射由 `config/managed-assets.psd1` 管理；内容不按工具复制维护。Claude Code 的 `.claude/skills/` adapter 当前暂停。

路由样例位于 `skills/evals/`，用于审查触发边界，不是第二份运行时路由注册表。包名称从 `.agents/skills/` 的目录自动发现；manifest 只登记源根、适配目标和退役资产，不维护包清单、`Role`、`Activation`、`Exclusions` 或 handoff 规则副本。

## 项目状态与索引

目标项目的 `.Ai-config/` 记录项目状态和索引：

- `CURRENT.md` 是跨会话工作状态入口。
- `tasks/*.md` 保存需要接手的任务事实。
- `skills-registry.md` 只登记完整 Skill 包的位置、适配入口和状态。
- `context-thread/` 保存当前项目结构索引和说明；数据库属于索引数据，不是配置源。

可复用规则和完整 Skill 包放在其配置源，不放进 `.Ai-config/`。本仓库的 `.agents/skills/` 同时承担内容源和受支持客户端的项目发现路径；需要 Claude Code 时可另行恢复 `.claude/skills/<name>/` 的同包 adapter，当前不生成该导出。`.agents/skills/` 是客户端路径约定，不是 Agent Skills 规范本身。

## 客户端 adapter 与 runtime

客户端发现路径、MCP 配置格式、settings/permissions、hooks、subagents 和 plugins 都有各自的所有者与语法。它们不能被误称为可移植 Skill 或规则格式。OpenCode 会同时扫描 `.agents/skills/` 和 `.claude/skills/`；当前 Hub 暂停 Claude 包导出，但用户级旧副本仍可能造成同名重复发现。目标环境需核验并隔离重复发现根；本次仓库迁移不自动清理用户目录。需要执行集成时，再单独恢复相应客户端 adapter。

`config/managed-assets.psd1` 当前登记规则/Skill 导出目标和可选 MCP/runtime 托管资产。`scripts/render*.ps1` 与 `scripts/check*.ps1` 负责仓库内生成和校验；`scripts/sync*.ps1`、`tool-configs/`、`tools/` 承担本机部署与运行。它们是可替换的交付层，不是本体。

普通规则或 Skill 修改先运行 `scripts/check-content.ps1`，它只验证内容本体及仓库内生成物；需要核对单条管线时再运行对应的 render/check。`scripts/check-all.ps1` 保留为显式的跨管线集成预检，可能包含 runtime、MCP 和用户级 dry-run，不是内容修改的默认入口。

完整 MCP 和 runtime 操作见 [同步流程](sync-workflow.md)。OpenCode 与 Grok 的兼容边界分别见 [OpenCode surface](opencode-surface.md) 和 [Grok Build surface](grok-build-surface.md)。

## 维护决策

- 新增长期协作规则：先判断是否能写成通用规则；不能共享的部分进入明确的客户端 adapter。
- 新增可复用能力：在 `.agents/skills/<name>/` 创建一个自包含 Agent Skill 包；不要拆成 shared 正文和多份客户端 SKILL.md。
- 新增客户端：先核实其发现行为，只添加需要的路径或语法 adapter；不要默认增加用户级部署目标、MCP profile 或 runtime。
- 使用 `.Ai-config/`：只记录状态、路径索引和项目结构数据，不复制规则或 Skill 内容。
- 用户级部署：只有明确需要时才运行同步脚本；本体修改完成不要求 Apply。
