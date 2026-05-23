# 工作任务：引入轻量脉络 / context-thread 思路

任务 ID：2026-05-24-context-thread
创建时间：2026-05-24 00:32
更新时间：2026-05-24 03:53
状态：待用户确认
当前活动：否

## 目标

在 `ai-config-hub` 中引入轻量结构化事实层：代码关系复杂时优先使用 context-thread 这类可查询图谱，非代码工作流复杂时使用 `docs/ai` 任务卡关系索引，同时保持 L0/L1 小任务不升级、不增加 AI 负担。

## 背景和当前上下文

用户要求把刚研究的 `外部结构化图谱项目` 项目概念和具体方案引入本仓库配置。计划已明确：全局默认可用，但实际使用按风险和关系复杂度触发；context-thread 负责代码结构关系，`docs/ai` 承接非代码工作流关系；二者都不替代真实文件、用户需求和验证。

## 最近结论

- 已新增 `global-context-thread` 全局 skill，覆盖 Claude Code、Codex 和 legacy rendered 产物。
- 已在共享规则中加入一段“结构化事实优先”规则，但保持短规则，不改变默认轻量原则。
- 已新增 `context-thread` MCP 配置组，渲染为 `scripts/context-thread.ps1 serve --mcp`，由本仓库 wrapper 从 `tools/context-thread-engine` 本地源码构建产物启动 MCP server。
- 已把 MCP 脚本从单一 `browser-visual` server 清单改为多组托管配置。
- 已给任务卡模板加入可选 `关系索引`，用于非代码复杂工作流接手。
- 已新增 `scripts/context-thread.ps1`，支持 `bootstrap`、`serve --mcp`、`init`、`sync` 等命令，避免要求全局安装 `context-thread`。
- 已把本地脉络引擎迁移到仓库内自有路径 `tools/context-thread-engine`，并把 CLI / MCP / 索引目录统一改成 `context-thread` / `.context-thread` / `context_thread_*`。

## 已确认事实

- 本机不需要全局 `context-thread` 命令；`context-thread` 通过本仓库 wrapper 调用 `tools/context-thread-engine/dist/bin/context-thread.js`。
- 已运行 `scripts/context-thread.ps1 bootstrap`，在被忽略的 `tools/context-thread-engine` 下完成 `npm ci` 和 `npm run build`。
- 本项目不自动全局安装 context-thread，也不自动初始化项目 `.context-thread/` 索引。
- `sync.ps1 -Apply`、`sync-skills.ps1 -Apply`、`sync-mcp.ps1 -Apply` 已执行；真实用户级规则、skill 和 MCP 配置已同步到本机。

## 已尝试 / 已排除

- 已排除把 context-thread 研究笔记整段写入正式规则；正式规则只保留结构化事实层原则。
- 已排除给非代码工作流引入新数据库或自研图谱；v1 只用任务卡关系索引。
- 已排除在 L0/L1 小任务中强制初始化 context-thread 或创建任务卡。

## 当前卡点

等待用户基于本机已同步结果的日常试用反馈，以及是否在目标项目按任务需要初始化 `.context-thread/` 索引。

## 关系索引

| 对象 | 当前状态 | 依赖 / 影响 | 证据 | 下一步 |
|---|---|---|---|---|
| `global-context-thread` skill | 仓库源、rendered 与本机用户级目录已同步 | 影响 Claude Code / Codex 用户级 skill 同步 | `sync-skills.ps1 -Apply` 已执行；dry-run 现为 unchanged | 后续按需试用并再决定是否微调 |
| `context-thread` MCP | 仓库源、rendered 与本机用户级目录已同步 | 依赖 `tools/context-thread-engine` 本地源码构建产物 | `sync-mcp.ps1 -Apply` 已执行；`context-thread` 已写入本机配置 | 后续日常试用后再决定是否微调 |
| 共享规则 | 仓库 rendered 与本机用户级目录已同步 | 影响全局 Claude / Codex 规则同步 | `sync.ps1 -Apply` 已执行；dry-run 现为 unchanged | 后续按需试用并再决定是否微调 |
| 任务卡关系索引 | 模板和 README 已更新 | 影响后续复杂工作流任务卡写法 | `check-skills.ps1` 通过 | 后续只在复杂接手任务使用 |

## 下一步最小动作

1. 用户基于本机已同步结果进行日常试用。
2. 若需要微调，再回到仓库源文件或用户级配置继续修正。

## 验证状态

- 已运行 `scripts/check-all.ps1`，结果 `All render, check, and dry-run steps passed`。
- `check-all` 中 `check.ps1` 输出 `Check passed`。
- `check-all` 中 `check-skills.ps1` 输出 `Skill check passed`。
- `check-all` 中 `check-mcp.ps1` 输出 `MCP check passed`。
- 已运行 `scripts/context-thread.ps1 bootstrap`，本地源码构建成功。
- 已运行 `scripts/context-thread.ps1 status .`，确认 wrapper 能启动本地构建产物，当前项目尚未初始化索引。
- 已用 JSON-RPC 最小握手验证 `scripts/context-thread.ps1 serve --mcp`，`tools/list` 返回 `context_thread_search`、`context_thread_context`、`context_thread_callers`、`context_thread_callees`、`context_thread_impact`、`context_thread_node`、`context_thread_explore`、`context_thread_status`、`context_thread_files`。
- `sync-skills.ps1 -Apply` 已执行，用户级 `global-context-thread` 目录已存在，后续 dry-run 为 `unchanged`。
- `sync-mcp.ps1 -Apply` 已执行，用户级 `context-thread` MCP 已写入；后续 dry-run 为 `unchanged`。
- `scripts/check-all.ps1` 已执行，渲染、检查和 dry-run 全部通过。

## 残留风险

- 如果 `tools/context-thread-engine/dist/bin/context-thread.js` 被清理，真实同步后的 `context-thread` MCP server 需要先重新运行 `scripts/context-thread.ps1 bootstrap`。
- 目标项目没有 `.context-thread/` 索引时，MCP 可启动但结构化查询会提示未初始化；是否初始化仍按 L2/L3 或真实复杂代码任务触发。
- 目前主要残留风险转为使用体验和 `.context-thread/` 索引是否需要按实际复杂项目再初始化。
- 工作区存在本轮前已有的 Pencil 相关未提交改动；本任务没有回滚或覆盖这些改动。
- 用户级 `global-context-thread` 与 `context-thread` MCP 已同步，重启 Codex / Claude 后才能看到新文案和新工具名。

## 相关文件

- `rules/shared/core.md`：结构化事实优先短规则。
- `skills/shared/global-context-thread/`：新 skill 事实源。
- `tool-configs/mcp/shared/context-thread.json`：`context-thread` MCP 事实源，底层调用 `scripts/context-thread.ps1 serve --mcp`。
- `scripts/context-thread.ps1`：本地源码 wrapper，负责 bootstrap 和启动 `tools/context-thread-engine` 构建产物。
- `scripts/render-mcp.ps1`、`scripts/check-mcp.ps1`、`scripts/sync-mcp.ps1`：多 MCP 组渲染、检查和同步。
- `docs/ai/tasks/README.md`：任务卡关系索引说明。

## 不要重复

- 不要把 context-thread 不可用当成 L0/L1 任务阻塞点。
- 不要把 `.context-thread/` 初始化写成默认动作。
- 不要把关系索引当成所有任务必填项。

## 关闭依据 / 最终结果

仓库源文件、rendered 产物、用户级规则、技能和 MCP 已完成同步；任务仍保留为待用户试用确认，以便后续根据实际使用感受决定是否微调。
