# ai-config-hub

`ai-config-hub` 维护可移植的 AI 协作配置内容。真正需要维护的本体集中在 `.agents/`：共享规则和符合 Agent Skills 格式的完整 Skill 包。客户端发现路径、MCP、hooks、权限、runtime 和用户级同步属于可选适配或部署基础设施，不是配置本体。

Agent Skills 规定 Skill 包的结构和 `SKILL.md` 格式，不规定客户端发现目录。`.agents/skills/` 是多家客户端采用的发现路径，但不是唯一标准路径。`.agents/rules/` 是本项目的规则源码约定，不是 Agent Skills 标准，也不会被客户端自动发现。Claude Code 的 Skill 与共享规则 adapter 暂停维护；Claude MCP 等可选集成仍由独立管线管理。

OpenCode 还会扫描 `.claude/skills/` 兼容目录；当同一个完整包同时存在于 `.agents/skills/` 与 `.claude/skills/` 时，OpenCode 会看到两个同名来源。本仓库直接维护并检查 `.agents/skills/`；Claude Skill 导出暂停。

设计依据见 [AI 配置设计](docs/ai-config-design.md) 和 [架构说明](docs/architecture.md)。

## 配置本体

- `.agents/rules/core.md`：跨工具共享的协作约束。它描述应当如何工作，不承载客户端路径或配置语法。
- `.agents/skills/<name>/`：完整的 Agent Skill 包。每个包有标准 `SKILL.md`，并可携带 workflow、references、templates 等资源。
- `.agents/README.md`：本体目录的边界、标准和维护入口。
- `docs/`：解释配置设计和领域事实；不替代可执行的规则或 skill 包。
- 目标项目的 `.Ai-config/`：工作状态、任务卡、registry 和结构索引，不存放通用 skill 内容。

可移植性来自共享内容和标准包格式，不代表各客户端会自动发现相同路径，也不代表 MCP、hooks、settings、permissions、subagents 或 plugins 存在统一格式。

## 适配与状态

- `config/managed-assets.psd1`：登记规则与可选本机集成的部署目标；它不是规则或 Skill 的内容事实源。
- `rules/rendered/`、`tool-configs/mcp/rendered/`：规则和 MCP 的可审阅导出物。Skill 包直接从 `.agents/skills/` 同步；`skills/rendered/` 只保留历史候选。
- `templates/`：adapter 或示例模板，不是通用协作规则源。
- `tool-configs/`、`tools/`：MCP 片段和本地 runtime 实现，按需启用。
- `scripts/`：渲染、检查和可选部署工具。用户级目录只有明确执行 `-Apply` 才会写入。
- `.Ai-config/CURRENT.md`、`.Ai-config/tasks/`：跨会话工作状态；`context-thread.db` 是项目结构索引数据。

当前适配器和发现行为见 [官方路径参考](.agents/skills/project-ai-config-hub/references/official-paths.md)。本机部署操作见 [同步流程](docs/sync-workflow.md)。

## 开发与验证

修改共享规则或 skill 包后，先运行对应的只读检查：

```powershell
.\scripts\check-content.ps1
```

`check-content.ps1` 是普通规则或 Skill 修改的默认入口，只检查仓库内配置本体、规则导出、Skill 包结构与引用、敏感内容，并运行 `git diff --check`。它不要求 MCP/runtime 依赖、用户级配置、hooks、doctor 或用户目录写入。需要定位单条管线问题时，再运行对应的细分命令：

```powershell
.\scripts\render.ps1 -Check
.\scripts\check.ps1
.\scripts\check-skills.ps1
```

跨管线或部署集成修改再运行显式的完整预检：

```powershell
.\scripts\check-all.ps1
```

CI 的 push / pull request 只运行内容本体门禁；需要运行包含 MCP、runtime、hooks 和同步 dry-run 的完整集成预检时，手动触发 `Validate` workflow。

`render.ps1` 生成规则适配文件；Skill 包不需要中间渲染，`sync-skills.ps1` 默认从 `.agents/skills/` 直接 dry-run 同步。用户级配置或 runtime 同步是单独的本机运维动作，不是修改配置本体的完成条件。

## 文档

- [AI 配置设计](docs/ai-config-design.md)：本体、adapter、状态和可选 runtime 的边界。
- [架构说明](docs/architecture.md)：从源包到客户端发现路径的当前数据流。
- [Skills 路线图](docs/skills-roadmap.md)：完整包和行为评测的维护位置。
- [工作状态设计](docs/work-state-design.md)：`.Ai-config/CURRENT.md` 和任务卡。
- [同步流程](docs/sync-workflow.md)：本机 adapter、MCP 和 runtime 的可选部署细节。
- [Context-thread](docs/context-thread/README.md)：项目级代码关系索引工具。
