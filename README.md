# ai-config-hub

`ai-config-hub` 维护可移植的 AI 协作配置内容：项目规则、符合 Agent Skills 格式的完整 skill 包，以及跨会话工作状态约定。客户端发现路径、MCP、hooks、权限、runtime 和用户级同步属于可选适配或部署基础设施，不是配置本体。

Agent Skills 规定 skill 包的结构和 `SKILL.md` 格式，不规定客户端发现目录。`.agents/skills/` 是 Codex 与 OpenCode 等客户端支持的发现路径，不是万能配置标准；Claude Code 使用自己的 skill 目录。路径差异由 adapter 处理，包内的规则与资源保持同一份。

OpenCode 还会扫描 `.claude/skills/` 兼容目录；当同一个完整包同时导出到 `.agents/skills/` 与 `.claude/skills/` 时，OpenCode 会看到两个同名来源。启用 OpenCode 的环境需按版本设置 `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1`，或保证它只扫描一个发现根。

设计依据见 [AI 配置设计](docs/ai-config-design.md) 和 [架构说明](docs/architecture.md)。

## 配置本体

- `rules/shared/core.md`：跨工具共享的协作约束。它描述应当如何工作，不承载客户端路径或配置语法。
- `skills/shared/<name>/`：完整的 Agent Skill 包。每个包有标准 `SKILL.md`，并可携带 workflow、references、templates 等资源。
- `docs/`：解释配置设计和领域事实；不替代可执行的规则或 skill 包。
- 目标项目的 `.Ai-config/`：工作状态、任务卡、registry 和结构索引，不存放通用 skill 内容。

可移植性来自共享内容和标准包格式，不代表各客户端会自动发现相同路径，也不代表 MCP、hooks、settings、permissions、subagents 或 plugins 存在统一格式。

## 适配与状态

- `config/managed-assets.psd1`：登记当前启用的发现路径、导出目标和可选本机托管资产；它不是规则或 skill 的内容事实源。
- `rules/rendered/`、`skills/rendered/`、`tool-configs/mcp/rendered/`：可审阅的导出产物，由对应源文件生成。
- `templates/`：adapter 或示例模板，不是通用协作规则源。
- `tool-configs/`、`tools/`：MCP 片段和本地 runtime 实现，按需启用。
- `scripts/`：渲染、检查和可选部署工具。用户级目录只有明确执行 `-Apply` 才会写入。
- `.Ai-config/CURRENT.md`、`.Ai-config/tasks/`：跨会话工作状态；`context-thread.db` 是项目结构索引数据。

当前适配器和发现行为见 [官方路径参考](skills/shared/project-ai-config-hub/references/official-paths.md)。本机部署操作见 [同步流程](docs/sync-workflow.md)。

## 开发与验证

修改共享规则或 skill 包后，先运行对应的只读检查：

```powershell
.\scripts\render.ps1 -Check
.\scripts\check.ps1
.\scripts\render-skills.ps1 -Check
.\scripts\check-skills.ps1
```

跨管线修改再运行完整预检：

```powershell
.\scripts\check-all.ps1
```

`render*.ps1` 可更新仓库内导出物；`sync*.ps1` 默认 dry-run。同步用户级配置或 runtime 是单独的本机运维动作，不是修改配置本体的完成条件。

## 文档

- [AI 配置设计](docs/ai-config-design.md)：本体、adapter、状态和可选 runtime 的边界。
- [架构说明](docs/architecture.md)：从源包到客户端发现路径的当前数据流。
- [Skills 路线图](docs/skills-roadmap.md)：完整包和行为评测的维护位置。
- [工作状态设计](docs/work-state-design.md)：`.Ai-config/CURRENT.md` 和任务卡。
- [同步流程](docs/sync-workflow.md)：本机 adapter、MCP 和 runtime 的可选部署细节。
- [Context-thread](docs/context-thread/README.md)：项目级代码关系索引工具。
