# 脉络文档索引

本目录是 `ai-config-hub` 中“脉络”能力的长期文档位置。

脉络属于整套 AI 配置的结构化事实层：代码关系复杂时，它提供可查询、可同步的项目级代码图谱；非代码复杂工作流仍由 `.Ai-config` 任务卡关系索引承接。它不替代真实文件、用户当前说明、文档和验证结果。

## 文档分工

- [design.md](design.md)：设计思路、问题边界、配置层级关系、使用生命周期和迭代原则。
- [implementation.md](implementation.md)：本地引擎、CLI、MCP、数据库、索引、watch/sync、测试和优化入口。
- [scenarios.md](scenarios.md)：真实使用场景、误解纠正、无感使用边界和当前补强点。

## 相关事实源

- `rules/shared/core.md`：结构化事实优先的全局短规则。
- `skills/shared/global-context-thread/`：AI 何时触发脉络、如何选择工具、何时回退。
- `tools/context-thread-engine/`：本仓库维护的本地引擎源码。
- `tool-configs/mcp/shared/context-thread.json`：MCP server 配置源。
- `scripts/context-thread.ps1`：面向人类和脚本的 wrapper。
- `scripts/sync-context-thread-runtime.ps1`：用户级 runtime 分发脚本。
- `.Ai-config/context-thread/`：当前项目的索引目录。
- `.Ai-config/tasks/README.md`：非代码工作流关系索引格式。

## 阅读顺序

- 想知道“为什么要有脉络、它解决什么问题”：读 [design.md](design.md)。
- 想优化引擎、MCP 或索引同步：读 [implementation.md](implementation.md)。
- 想判断某个实际任务该不该用脉络：读 [scenarios.md](scenarios.md) 和 `skills/shared/global-context-thread/workflow.md`。
- 想看当前项目索引状态和命令：读 `.Ai-config/context-thread/README.md`。

## 文档维护规则

- 设计原则和边界写在 `design.md`，不要散落在任务卡里。
- 技术实现和模块职责写在 `implementation.md`，不要塞进 `tools/context-thread-engine/README.md`。
- 真实场景、误区和已验证行为写在 `scenarios.md`。
- 当前任务进展、验证记录和未确认风险写在 `.Ai-config/tasks/*.md`，不要把任务卡当长期设计文档。
- `tools/context-thread-engine/README.md` 只保留引擎目录的快速说明和常用命令。
